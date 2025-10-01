import Foundation
import Combine
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = true
    
    // MARK: - Dependencies
    private var authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(authService: AuthService) {
        self.authService = authService
        setupBindings()
        checkAuthenticationState()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe authentication state changes
        authService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
        
        authService.$currentUser
            .sink { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
        
        authService.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func checkAuthenticationState() {
        Task {
            do {
                // Check for existing session and restore if valid
                try await authService.checkSession()
                
                // If session is valid, load user profile
                if isAuthenticated {
                    await loadUserProfile()
                }
            } catch {
                // Session check failed, user needs to sign in
                Logger.shared.error("Session check failed: \(error)")
            }
            isLoading = false
        }
    }
    
    private func loadUserProfile() async {
        // Load user profile from the authenticated session
        currentUser = authService.currentUser
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            print("Sign out failed: \(error)")
        }
    }
    
    func updateAuthService(_ newAuthService: AuthService) {
        // Cancel existing subscriptions
        cancellables.removeAll()
        
        // Update the auth service
        self.authService = newAuthService
        
        // Re-setup bindings with the new service
        setupBindings()
        
        // Check authentication state and restore session if available
        checkAuthenticationState()
    }
    
    // MARK: - Auto-Login Methods
    
    /// Restore user session automatically on app launch
    func restoreSession() async {
        isLoading = true
        
        do {
            // Check for existing session in keychain
            try await authService.checkSession()
            
            if isAuthenticated {
                // Session is valid, load user profile
                await loadUserProfile()
                Logger.shared.info("Session restored successfully for user: \(currentUser?.email ?? "unknown")")
            } else {
                Logger.shared.info("No valid session found, user needs to sign in")
            }
        } catch {
            Logger.shared.error("Session restoration failed: \(error)")
        }
        
        isLoading = false
    }
    
    /// Check if user should be automatically logged in
    var shouldAutoLogin: Bool {
        // Check if we have a valid session in keychain
        return KeychainService.shared.hasValidSession()
    }
    
    // MARK: - Computed Properties
    
    var shouldShowAuthentication: Bool {
        return !isLoading && !isAuthenticated
    }
    
    var shouldShowMainApp: Bool {
        return !isLoading && isAuthenticated
    }
}
