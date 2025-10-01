import Foundation
import Combine
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var fullName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingAlert: Bool = false
    
    // MARK: - Dependencies
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Accessors
    
    func getAuthService() -> AuthService {
        return authService
    }
    
    // MARK: - Initialization
    
    init(authService: AuthService) {
        self.authService = authService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe auth service state
        authService.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
        
        authService.$errorMessage
            .sink { [weak self] errorMessage in
                self?.errorMessage = errorMessage
                self?.showingAlert = errorMessage != nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func signIn() async {
        guard validateSignInInput() else { return }
        
        do {
            _ = try await authService.signIn(email: email, password: password)
            clearForm()
        } catch {
            handleError(error)
        }
    }
    
    func signUp() async {
        guard validateSignUpInput() else { return }
        
        do {
            _ = try await authService.signUp(email: email, password: password, fullName: fullName)
            clearForm()
        } catch {
            handleError(error)
        }
    }
    
    func resetPassword() async {
        guard validateEmail() else { return }
        
        do {
            try await authService.resetPassword(email: email)
            showSuccessMessage("Password reset email sent to \(email)")
        } catch {
            handleError(error)
        }
    }
    
    func signInWithApple() async {
        do {
            _ = try await authService.signInWithApple()
            clearForm()
        } catch {
            handleError(error)
        }
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Validation
    
    private func validateSignInInput() -> Bool {
        if email.isEmpty {
            showError("Please enter your email address")
            return false
        }
        
        if !isValidEmail(email) {
            showError("Please enter a valid email address")
            return false
        }
        
        if password.isEmpty {
            showError("Please enter your password")
            return false
        }
        
        return true
    }
    
    private func validateSignUpInput() -> Bool {
        if fullName.isEmpty {
            showError("Please enter your full name")
            return false
        }
        
        if email.isEmpty {
            showError("Please enter your email address")
            return false
        }
        
        if !isValidEmail(email) {
            showError("Please enter a valid email address")
            return false
        }
        
        if password.isEmpty {
            showError("Please enter a password")
            return false
        }
        
        if password.count < 8 {
            showError("Password must be at least 8 characters long")
            return false
        }
        
        if confirmPassword.isEmpty {
            showError("Please confirm your password")
            return false
        }
        
        if password != confirmPassword {
            showError("Passwords do not match")
            return false
        }
        
        return true
    }
    
    private func validateEmail() -> Bool {
        if email.isEmpty {
            showError("Please enter your email address")
            return false
        }
        
        if !isValidEmail(email) {
            showError("Please enter a valid email address")
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            showError(appError.localizedDescription)
        } else {
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingAlert = true
    }
    
    private func showSuccessMessage(_ message: String) {
        errorMessage = message
        showingAlert = true
    }
    
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        fullName = ""
        errorMessage = nil
        showingAlert = false
    }
    
    func clearError() {
        errorMessage = nil
        showingAlert = false
    }
    
    // MARK: - Computed Properties
    
    var isSignInValid: Bool {
        return !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }
    
    var isSignUpValid: Bool {
        return !fullName.isEmpty && 
               !email.isEmpty && 
               !password.isEmpty && 
               !confirmPassword.isEmpty &&
               isValidEmail(email) &&
               password.count >= 8 &&
               password == confirmPassword
    }
    
    var isResetPasswordValid: Bool {
        return !email.isEmpty && isValidEmail(email)
    }
}
