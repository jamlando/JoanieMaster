import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var children: [Child] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingAddChild: Bool = false
    @Published var showingEditProfile: Bool = false
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var currentUser: UserProfile? {
        return appState.currentUser
    }
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    var childrenCount: Int {
        return children.count
    }
    
    var selectedChild: Child? {
        return appState.selectedChild
    }
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService, appState: AppState) {
        self.supabaseService = supabaseService
        self.appState = appState
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe current user changes
        appState.$currentUser
            .sink { [weak self] user in
                self?.userProfile = user
                if user != nil {
                    Task {
                        await self?.loadChildren()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe children changes
        appState.$children
            .sink { [weak self] children in
                self?.children = children
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadProfile() async {
        guard let currentUser = currentUser else {
            clearData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            userProfile = try await supabaseService.getUserProfile()
            await loadChildren()
        } catch {
            errorMessage = error.localizedDescription
            logError("Failed to load profile: \(error)")
        }
        
        isLoading = false
    }
    
    func loadChildren() async {
        guard let currentUser = currentUser else {
            children = []
            return
        }
        
        do {
            children = try await supabaseService.getChildren(for: currentUser.id)
            appState.children = children
        } catch {
            errorMessage = error.localizedDescription
            logError("Failed to load children: \(error)")
        }
    }
    
    func refreshProfile() async {
        await loadProfile()
    }
    
    func clearData() {
        userProfile = nil
        children = []
        errorMessage = nil
    }
    
    // MARK: - Profile Actions
    
    func updateProfile(name: String, avatarURL: String? = nil) async {
        guard let profile = userProfile else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedProfile = profile.withUpdatedName(name)
            let finalProfile = avatarURL != nil ? updatedProfile.withUpdatedAvatar(avatarURL!) : updatedProfile
            
            try await supabaseService.updateUserProfile(finalProfile)
            userProfile = finalProfile
            appState.setCurrentUser(finalProfile)
            
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            logError("Failed to update profile: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Child Management
    
    func addChild(name: String, birthDate: Date?, avatarURL: String? = nil) async {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newChild = Child(
                userId: currentUser.id,
                name: name,
                birthDate: birthDate,
                avatarURL: avatarURL
            )
            
            let createdChild = try await supabaseService.createChild(name: newChild.name, birthDate: newChild.birthDate)
            children.append(createdChild)
            appState.addChild(createdChild)
            
            // Select the new child if it's the first one
            if children.count == 1 {
                appState.setSelectedChild(createdChild)
            }
            
        } catch {
            errorMessage = "Failed to add child: \(error.localizedDescription)"
            logError("Failed to add child: \(error)")
        }
        
        isLoading = false
    }
    
    func updateChild(_ child: Child, name: String, birthDate: Date?, avatarURL: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedChild = child.withUpdatedName(name).withUpdatedBirthDate(birthDate ?? child.birthDate ?? Date())
            let finalChild = avatarURL != nil ? updatedChild.withUpdatedAvatar(avatarURL!) : updatedChild
            
            _ = try await supabaseService.updateChild(finalChild)
            
            if let index = children.firstIndex(where: { $0.id == child.id }) {
                children[index] = finalChild
            }
            appState.updateChild(finalChild)
            
        } catch {
            errorMessage = "Failed to update child: \(error.localizedDescription)"
            logError("Failed to update child: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteChild(_ child: Child) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteChild(child.id)
            
            children.removeAll { $0.id == child.id }
            appState.removeChild(child)
            
        } catch {
            errorMessage = "Failed to delete child: \(error.localizedDescription)"
            logError("Failed to delete child: \(error)")
        }
        
        isLoading = false
    }
    
    func selectChild(_ child: Child) {
        appState.setSelectedChild(child)
    }
    
    // MARK: - UI Actions
    
    func showAddChild() {
        showingAddChild = true
    }
    
    func hideAddChild() {
        showingAddChild = false
    }
    
    func showEditProfile() {
        showingEditProfile = true
    }
    
    func hideEditProfile() {
        showingEditProfile = false
    }
    
    // MARK: - Account Actions
    
    func logout() async {
        do {
            try await supabaseService.signOut()
            appState.logout()
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
            logError("Failed to logout: \(error)")
        }
    }
    
    func deleteAccount() async {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteUser(currentUser.id)
            appState.logout()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            logError("Failed to delete account: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Helper Extensions

extension ProfileViewModel {
    var profileDisplayName: String {
        return userProfile?.displayName ?? "Unknown User"
    }
    
    var profileInitials: String {
        return userProfile?.initials ?? "??"
    }
    
    var memberSince: String {
        guard let userProfile = userProfile else { return "Unknown" }
        return DateFormatter.memberSinceFormatter.string(from: userProfile.createdAt)
    }
    
    var childrenSummary: String {
        switch children.count {
        case 0:
            return "No children added yet"
        case 1:
            return "1 child"
        default:
            return "\(children.count) children"
        }
    }
    
    var selectedChildSummary: String {
        guard let selectedChild = selectedChild else {
            return "No child selected"
        }
        return "Selected: \(selectedChild.name)"
    }
}
