import Foundation
// import Supabase // TODO: Add Supabase dependency
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
    private let emailServiceManager: EmailServiceManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService, emailServiceManager: EmailServiceManager) {
        self.supabaseService = supabaseService
        self.emailServiceManager = emailServiceManager
        setupBindings()
        
        Logger.shared.info("AuthService initialized with email integration", metadata: [
            "emailManagerType": String(describing: type(of: emailServiceManager)),
            "emailServiceActive": true
        ])
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
            
            // Send welcome email after successful sign up
            Task {
                do {
                    _ = try await emailServiceManager.sendWelcomeEmail(
                        to: email, 
                        userName: fullName
                    )
                    
                    Logger.shared.info("Welcome email sent", metadata: [
                        "userId": user.id.uuidString,
                        "email": email,
                        "userName": fullName
                    ])
                } catch {
                    Logger.shared.error("Welcome email failed to send", metadata: [
                        "userId": user.id.uuidString,
                        "email": email,
                        "error": error.localizedDescription
                    ])
                    // Don't fail sign up if welcome email fails
                }
            }
            
            isLoading = false
            return user
            
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    func signIn(email: String, password: String) async throws -> UserProfile {
        isLoading = true
        errorMessage = nil
        
        let user = try await supabaseService.signIn(email: email, password: password)
        
        isLoading = false
        return user
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
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Perform secure logout
            try await supabaseService.signOut()
            
            // Clear any local state
            await clearLocalState()
            
            isLoading = false
            Logger.shared.info("AuthService: User signed out successfully")
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            Logger.shared.error("AuthService: Sign out failed - \(mappedError)")
            throw mappedError
        }
    }
    
    private func clearLocalState() async {
        // Clear any local authentication state
        await MainActor.run {
            // Reset any local flags or cached data
            // TODO: Clear any additional local state as needed
        }
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Generate a reset token (in real implementation, this would come from Supabase)
            let resetToken = generatePasswordResetToken()
            let userId = UUID() // In real implementation, get UUID from user lookup
            
            // Use email service manager for sending password reset email
            _ = try await emailServiceManager.sendPasswordReset(
                to: email, 
                resetToken: resetToken, 
                userId: userId
            )
            
            isLoading = false
            
            Logger.shared.info("Password reset email sent", metadata: [
                "email": email,
                "resetToken": resetToken,
                "userId": userId.uuidString
            ])
            
        } catch {
            isLoading = false
            
            if let emailError = error as? EmailError {
                let mappedError = emailError.toAuthenticationError()
                errorMessage = mappedError.localizedDescription
                
                Logger.shared.error("Password reset email failed", metadata: [
                    "email": email,
                    "emailError": emailError.localizedDescription,
                    "mappedError": mappedError.errorCode
                ])
                
                throw mappedError
            } else {
                let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
                errorMessage = mappedError.localizedDescription
                throw mappedError
            }
        }
    }
    
    private func generatePasswordResetToken() -> String {
        // In a real implementation, this would generate a secure JWT token
        // For now, we'll generate a simple token
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomPart = UUID().uuidString.prefix(8)
        return "reset_\(timestamp)_\(randomPart)"
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            isLoading = false
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    func deleteAccount() async throws {
        guard let currentUser = currentUser else {
            throw AuthenticationError.sessionNotFound
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteUser(currentUser.id)
            isLoading = false
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
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
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    func uploadProfileImage(_ imageData: Data) async throws -> String {
        guard let currentUser = currentUser else {
            throw AuthenticationError.sessionNotFound
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let imageURL = try await supabaseService.uploadProfileImage(imageData, for: currentUser.id)
            isLoading = false
            return imageURL
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    // MARK: - Session Management
    
    func checkSession() async throws {
        isLoading = true
        errorMessage = nil
        
        try await supabaseService.checkSession()
        
        isLoading = false
    }
    
    func refreshSession() async throws {
        isLoading = true
        errorMessage = nil
        
        try await supabaseService.refreshSession()
        
        isLoading = false
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
    
    // MARK: - Email-specific Methods
    
    /// Send account verification email
    func sendAccountVerificationEmail() async throws {
        guard let user = currentUser else {
            throw AuthenticationError.sessionNotFound
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let verificationToken = generateVerificationToken()
            
            _ = try await emailServiceManager.sendAccountVerification(
                to: user.email,
                verificationToken: verificationToken
            )
            
            isLoading = false
            
            Logger.shared.info("Account verification email sent", metadata: [
                "userId": user.id.uuidString,
                "email": user.email,
                "verificationToken": verificationToken
            ])
            
        } catch {
            isLoading = false
            
            if let emailError = error as? EmailError {
                let mappedError = emailError.toAuthenticationError()
                errorMessage = mappedError.localizedDescription
                throw mappedError
            } else {
                let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
                errorMessage = mappedError.localizedDescription
                throw mappedError
            }
        }
    }
    
    /// Resend password reset email
    func resendPasswordReset(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            await resetPassword(email: email)
            isLoading = false
            
            Logger.shared.info("Password reset email resent", metadata: [
                "email": email
            ])
            
        } catch {
            isLoading = false
            throw error // Re-throw the error from resetPassword
        }
    }
    
    private func generateVerificationToken() -> String {
        // In a real implementation, this would generate a secure JWT token
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomPart = UUID().uuidString.prefix(8)
        return "verify_\(timestamp)_\(randomPart)"
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
    
    /// Get email service status for debugging
    func getEmailServiceStatus() -> [String: Any] {
        return [
            "serviceType": emailServiceManager.currentService.rawValue,
            "isHealthy": emailServiceManager.serviceHealthStatus.canSendEmails,
            "metricsSummary": emailServiceManager.getServiceMetrics().summary
        ]
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

enum AuthenticationError: LocalizedError, Equatable {
    // MARK: - Network-related errors
    case networkUnavailable
    case networkTimeout
    case networkConnectionFailed
    case networkSlowConnection
    
    // MARK: - Authentication errors
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case accountLocked
    case accountDisabled
    case emailNotVerified
    case tooManyAttempts
    case passwordExpired
    case invalidEmailFormat
    case passwordTooCommon
    
    // MARK: - Session errors
    case sessionExpired
    case sessionInvalid
    case refreshTokenExpired
    case sessionNotFound
    case sessionCorrupted
    
    // MARK: - Server errors
    case serverError(Int)
    case serviceUnavailable
    case rateLimitExceeded
    case serverMaintenance
    case serverOverloaded
    
    // MARK: - Client errors
    case invalidInput(String)
    case missingRequiredField(String)
    case validationFailed(String)
    case invalidToken
    case tokenExpired
    
    // MARK: - System errors
    case keychainError
    case storageError
    case biometricError
    case deviceNotSupported
    case permissionDenied
    
    // MARK: - Apple Sign-In specific errors
    case appleSignInCancelled
    case appleSignInFailed
    case appleSignInNotAvailable
    case appleSignInInvalidResponse
    
    // MARK: - Password reset errors
    case passwordResetFailed
    case passwordResetExpired
    case passwordResetInvalidToken
    case passwordResetTooFrequent
    
    // MARK: - Account management errors
    case accountDeletionFailed
    case accountUpdateFailed
    case profileUpdateFailed
    case imageUploadFailed
    
    // MARK: - Generic errors
    case unknown(String)
    case unexpectedError
    
    // MARK: - Error Descriptions
    
    var errorDescription: String? {
        switch self {
        // Network-related errors
        case .networkUnavailable:
            return "No internet connection available"
        case .networkTimeout:
            return "Request timed out. Please check your connection"
        case .networkConnectionFailed:
            return "Failed to connect to the server"
        case .networkSlowConnection:
            return "Connection is slow. Please try again"
            
        // Authentication errors
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password is too weak"
        case .accountLocked:
            return "Account has been locked due to multiple failed attempts"
        case .accountDisabled:
            return "Account has been disabled"
        case .emailNotVerified:
            return "Please verify your email address"
        case .tooManyAttempts:
            return "Too many failed attempts. Please try again later"
        case .passwordExpired:
            return "Your password has expired"
        case .invalidEmailFormat:
            return "Please enter a valid email address"
        case .passwordTooCommon:
            return "Password is too common. Please choose a stronger password"
            
        // Session errors
        case .sessionExpired:
            return "Your session has expired"
        case .sessionInvalid:
            return "Invalid session. Please sign in again"
        case .refreshTokenExpired:
            return "Refresh token has expired"
        case .sessionNotFound:
            return "No active session found"
        case .sessionCorrupted:
            return "Session data is corrupted"
            
        // Server errors
        case .serverError(let code):
            return "Server error occurred (Code: \(code))"
        case .serviceUnavailable:
            return "Service is temporarily unavailable"
        case .rateLimitExceeded:
            return "Too many requests. Please wait before trying again"
        case .serverMaintenance:
            return "Server is under maintenance"
        case .serverOverloaded:
            return "Server is overloaded. Please try again later"
            
        // Client errors
        case .invalidInput(let field):
            return "Invalid input for \(field)"
        case .missingRequiredField(let field):
            return "\(field) is required"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .invalidToken:
            return "Invalid authentication token"
        case .tokenExpired:
            return "Authentication token has expired"
            
        // System errors
        case .keychainError:
            return "Failed to access secure storage"
        case .storageError:
            return "Failed to save data"
        case .biometricError:
            return "Biometric authentication failed"
        case .deviceNotSupported:
            return "This device is not supported"
        case .permissionDenied:
            return "Permission denied"
            
        // Apple Sign-In specific errors
        case .appleSignInCancelled:
            return "Apple Sign-In was cancelled"
        case .appleSignInFailed:
            return "Apple Sign-In failed"
        case .appleSignInNotAvailable:
            return "Apple Sign-In is not available"
        case .appleSignInInvalidResponse:
            return "Invalid response from Apple Sign-In"
            
        // Password reset errors
        case .passwordResetFailed:
            return "Password reset failed"
        case .passwordResetExpired:
            return "Password reset link has expired"
        case .passwordResetInvalidToken:
            return "Invalid password reset token"
        case .passwordResetTooFrequent:
            return "Password reset requested too frequently"
            
        // Account management errors
        case .accountDeletionFailed:
            return "Failed to delete account"
        case .accountUpdateFailed:
            return "Failed to update account"
        case .profileUpdateFailed:
            return "Failed to update profile"
        case .imageUploadFailed:
            return "Failed to upload image"
            
        // Generic errors
        case .unknown(let message):
            return message
        case .unexpectedError:
            return "An unexpected error occurred"
        }
    }
    
    // MARK: - Recovery Suggestions
    
    var recoverySuggestion: String? {
        switch self {
        // Network-related errors
        case .networkUnavailable:
            return "Please check your internet connection and try again"
        case .networkTimeout:
            return "Check your connection speed and try again"
        case .networkConnectionFailed:
            return "Verify your internet connection and try again"
        case .networkSlowConnection:
            return "Try again when you have a better connection"
            
        // Authentication errors
        case .invalidCredentials:
            return "Please check your email and password and try again"
        case .userNotFound:
            return "Please sign up for an account or check your email address"
        case .emailAlreadyExists:
            return "Please use a different email address or try signing in"
        case .weakPassword:
            return "Please use a stronger password with at least 8 characters, including numbers and symbols"
        case .accountLocked:
            return "Please wait 15 minutes before trying again, or contact support"
        case .accountDisabled:
            return "Please contact support to reactivate your account"
        case .emailNotVerified:
            return "Please check your email and click the verification link"
        case .tooManyAttempts:
            return "Please wait 30 minutes before trying again"
        case .passwordExpired:
            return "Please reset your password"
        case .invalidEmailFormat:
            return "Please enter a valid email address (e.g., user@example.com)"
        case .passwordTooCommon:
            return "Please choose a unique password that's not commonly used"
            
        // Session errors
        case .sessionExpired:
            return "Please sign in again"
        case .sessionInvalid:
            return "Please sign out and sign in again"
        case .refreshTokenExpired:
            return "Please sign in again"
        case .sessionNotFound:
            return "Please sign in to continue"
        case .sessionCorrupted:
            return "Please sign out and sign in again"
            
        // Server errors
        case .serverError:
            return "Please try again in a few minutes"
        case .serviceUnavailable:
            return "Please try again later"
        case .rateLimitExceeded:
            return "Please wait a few minutes before trying again"
        case .serverMaintenance:
            return "Please try again after maintenance is complete"
        case .serverOverloaded:
            return "Please try again in a few minutes"
            
        // Client errors
        case .invalidInput:
            return "Please check your input and try again"
        case .missingRequiredField:
            return "Please fill in all required fields"
        case .validationFailed:
            return "Please check your input and try again"
        case .invalidToken:
            return "Please sign in again"
        case .tokenExpired:
            return "Please sign in again"
            
        // System errors
        case .keychainError:
            return "Please restart the app and try again"
        case .storageError:
            return "Please try again or contact support"
        case .biometricError:
            return "Please use your password instead"
        case .deviceNotSupported:
            return "Please use a supported device"
        case .permissionDenied:
            return "Please enable the required permissions in Settings"
            
        // Apple Sign-In specific errors
        case .appleSignInCancelled:
            return "Please try signing in again"
        case .appleSignInFailed:
            return "Please try again or use email/password sign in"
        case .appleSignInNotAvailable:
            return "Please use email/password sign in instead"
        case .appleSignInInvalidResponse:
            return "Please try again or contact support"
            
        // Password reset errors
        case .passwordResetFailed:
            return "Please try requesting a new password reset"
        case .passwordResetExpired:
            return "Please request a new password reset"
        case .passwordResetInvalidToken:
            return "Please request a new password reset"
        case .passwordResetTooFrequent:
            return "Please wait before requesting another password reset"
            
        // Account management errors
        case .accountDeletionFailed:
            return "Please try again or contact support"
        case .accountUpdateFailed:
            return "Please try again or contact support"
        case .profileUpdateFailed:
            return "Please try again or contact support"
        case .imageUploadFailed:
            return "Please try uploading the image again"
            
        // Generic errors
        case .unknown:
            return "Please try again or contact support"
        case .unexpectedError:
            return "Please restart the app and try again"
        }
    }
    
    // MARK: - Error Severity
    
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            return .warning
        case .invalidCredentials, .userNotFound, .emailAlreadyExists, .weakPassword, .invalidEmailFormat, .passwordTooCommon:
            return .warning
        case .accountLocked, .accountDisabled, .emailNotVerified, .tooManyAttempts, .passwordExpired:
            return .error
        case .sessionExpired, .sessionInvalid, .refreshTokenExpired, .sessionNotFound, .sessionCorrupted:
            return .error
        case .serverError, .serviceUnavailable, .rateLimitExceeded, .serverMaintenance, .serverOverloaded:
            return .error
        case .invalidInput, .missingRequiredField, .validationFailed, .invalidToken, .tokenExpired:
            return .warning
        case .keychainError, .storageError, .biometricError, .deviceNotSupported, .permissionDenied:
            return .error
        case .appleSignInCancelled, .appleSignInFailed, .appleSignInNotAvailable, .appleSignInInvalidResponse:
            return .warning
        case .passwordResetFailed, .passwordResetExpired, .passwordResetInvalidToken, .passwordResetTooFrequent:
            return .error
        case .accountDeletionFailed, .accountUpdateFailed, .profileUpdateFailed, .imageUploadFailed:
            return .error
        case .unknown, .unexpectedError:
            return .error
        }
    }
    
    // MARK: - Retry Capability
    
    var canRetry: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            return true
        case .serverError, .serviceUnavailable, .serverOverloaded:
            return true
        case .rateLimitExceeded:
            return true
        case .storageError, .imageUploadFailed:
            return true
        case .appleSignInFailed, .appleSignInInvalidResponse:
            return true
        case .passwordResetFailed:
            return true
        case .accountUpdateFailed, .profileUpdateFailed:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Error Code
    
    var errorCode: String {
        switch self {
        case .networkUnavailable: return "NETWORK_UNAVAILABLE"
        case .networkTimeout: return "NETWORK_TIMEOUT"
        case .networkConnectionFailed: return "NETWORK_CONNECTION_FAILED"
        case .networkSlowConnection: return "NETWORK_SLOW_CONNECTION"
        case .invalidCredentials: return "INVALID_CREDENTIALS"
        case .userNotFound: return "USER_NOT_FOUND"
        case .emailAlreadyExists: return "EMAIL_ALREADY_EXISTS"
        case .weakPassword: return "WEAK_PASSWORD"
        case .accountLocked: return "ACCOUNT_LOCKED"
        case .accountDisabled: return "ACCOUNT_DISABLED"
        case .emailNotVerified: return "EMAIL_NOT_VERIFIED"
        case .tooManyAttempts: return "TOO_MANY_ATTEMPTS"
        case .passwordExpired: return "PASSWORD_EXPIRED"
        case .invalidEmailFormat: return "INVALID_EMAIL_FORMAT"
        case .passwordTooCommon: return "PASSWORD_TOO_COMMON"
        case .sessionExpired: return "SESSION_EXPIRED"
        case .sessionInvalid: return "SESSION_INVALID"
        case .refreshTokenExpired: return "REFRESH_TOKEN_EXPIRED"
        case .sessionNotFound: return "SESSION_NOT_FOUND"
        case .sessionCorrupted: return "SESSION_CORRUPTED"
        case .serverError(let code): return "SERVER_ERROR_\(code)"
        case .serviceUnavailable: return "SERVICE_UNAVAILABLE"
        case .rateLimitExceeded: return "RATE_LIMIT_EXCEEDED"
        case .serverMaintenance: return "SERVER_MAINTENANCE"
        case .serverOverloaded: return "SERVER_OVERLOADED"
        case .invalidInput(let field): return "INVALID_INPUT_\(field.uppercased())"
        case .missingRequiredField(let field): return "MISSING_REQUIRED_FIELD_\(field.uppercased())"
        case .validationFailed(let reason): return "VALIDATION_FAILED_\(reason.uppercased())"
        case .invalidToken: return "INVALID_TOKEN"
        case .tokenExpired: return "TOKEN_EXPIRED"
        case .keychainError: return "KEYCHAIN_ERROR"
        case .storageError: return "STORAGE_ERROR"
        case .biometricError: return "BIOMETRIC_ERROR"
        case .deviceNotSupported: return "DEVICE_NOT_SUPPORTED"
        case .permissionDenied: return "PERMISSION_DENIED"
        case .appleSignInCancelled: return "APPLE_SIGN_IN_CANCELLED"
        case .appleSignInFailed: return "APPLE_SIGN_IN_FAILED"
        case .appleSignInNotAvailable: return "APPLE_SIGN_IN_NOT_AVAILABLE"
        case .appleSignInInvalidResponse: return "APPLE_SIGN_IN_INVALID_RESPONSE"
        case .passwordResetFailed: return "PASSWORD_RESET_FAILED"
        case .passwordResetExpired: return "PASSWORD_RESET_EXPIRED"
        case .passwordResetInvalidToken: return "PASSWORD_RESET_INVALID_TOKEN"
        case .passwordResetTooFrequent: return "PASSWORD_RESET_TOO_FREQUENT"
        case .accountDeletionFailed: return "ACCOUNT_DELETION_FAILED"
        case .accountUpdateFailed: return "ACCOUNT_UPDATE_FAILED"
        case .profileUpdateFailed: return "PROFILE_UPDATE_FAILED"
        case .imageUploadFailed: return "IMAGE_UPLOAD_FAILED"
        case .unknown(let message): return "UNKNOWN_\(message.hashValue)"
        case .unexpectedError: return "UNEXPECTED_ERROR"
        }
    }
    
    // MARK: - Context Information
    
    var contextInfo: [String: Any] {
        var context: [String: Any] = [
            "errorCode": errorCode,
            "severity": severity,
            "canRetry": canRetry,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        switch self {
        case .serverError(let code):
            context["serverCode"] = code
        case .invalidInput(let field):
            context["field"] = field
        case .missingRequiredField(let field):
            context["field"] = field
        case .validationFailed(let reason):
            context["reason"] = reason
        case .unknown(let message):
            context["message"] = message
        default:
            break
        }
        
        return context
    }
}
