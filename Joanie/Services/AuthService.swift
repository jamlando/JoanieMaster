import Foundation
import Supabase
import Combine

@MainActor
class AuthService: ObservableObject, ServiceProtocol {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe authentication state changes
        supabaseService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
        
        supabaseService.$currentUser
            .sink { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func signUp(email: String, password: String, fullName: String) async throws -> UserProfile {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseService.signUp(email: email, password: password, fullName: fullName)
            isLoading = false
            return user
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> UserProfile {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseService.signIn(email: email, password: password)
            isLoading = false
            return user
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithApple() async throws -> UserProfile {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseService.signInWithApple()
            isLoading = false
            return user
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.signOut()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.resetPassword(email: email)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteAccount() async throws {
        guard let currentUser = currentUser else {
            throw AppError.authenticationError("No user logged in")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteUser(currentUser.id)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Profile Management
    
    func updateProfile(_ profile: UserProfile) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.updateUserProfile(profile)
            currentUser = profile
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func uploadProfileImage(_ imageData: Data) async throws -> String {
        guard let currentUser = currentUser else {
            throw AppError.authenticationError("No user logged in")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let imageURL = try await supabaseService.uploadProfileImage(imageData, for: currentUser.id)
            isLoading = false
            return imageURL
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Session Management
    
    func checkSession() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.checkSession()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func refreshSession() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.refreshSession()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - ServiceProtocol
    
    func reset() {
        isAuthenticated = false
        currentUser = nil
        isLoading = false
        errorMessage = nil
    }
    
    func configureForTesting() {
        // Configure for testing environment
        reset()
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var isSignedIn: Bool {
        return isAuthenticated && currentUser != nil
    }
    
    var userDisplayName: String {
        return currentUser?.displayName ?? "Unknown User"
    }
    
    var userInitials: String {
        return currentUser?.initials ?? "??"
    }
}

// MARK: - Authentication State

enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated(UserProfile)
    case error(Error)
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    var user: UserProfile? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Authentication Error

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "Email already exists"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error occurred"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your email and password and try again"
        case .userNotFound:
            return "Please sign up for an account"
        case .emailAlreadyExists:
            return "Please use a different email address"
        case .weakPassword:
            return "Please use a stronger password with at least 8 characters"
        case .networkError:
            return "Please check your internet connection and try again"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}
