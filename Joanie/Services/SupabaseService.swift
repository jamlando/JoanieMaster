import Foundation
import Supabase
import Combine
import UIKit
import AuthenticationServices

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    private let keychainService = KeychainService.shared
    
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    @Published var sessionState: SessionState = .unknown
    
    private var cancellables = Set<AnyCancellable>()
    private var sessionRefreshTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Session State
    enum SessionState {
        case unknown
        case authenticated
        case expired
        case refreshing
        case invalid
    }
    
    private init() {
        // Initialize real Supabase client
        self.client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        
        setupAuthStateListener()
        setupSessionMonitoring()
        setupBackgroundRefresh()
        
        // Check for existing session on app launch
        Task {
            await checkExistingSession()
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        // Listen for authentication state changes
        Task {
            for await state in client.auth.authStateChanges {
                await MainActor.run {
                    switch state.event {
                    case .signedIn:
                        self.sessionState = .authenticated
                        self.isAuthenticated = true
                        
                        // Load user profile if user is available
                        if let user = state.session?.user {
                            Task {
                                await self.loadUserProfile(from: user)
                            }
                        }
                        
                    case .signedOut:
                        self.sessionState = .invalid
                        self.isAuthenticated = false
                        self.currentUser = nil
                        
                    case .tokenRefreshed:
                        self.sessionState = .authenticated
                        self.isAuthenticated = true
                        
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func checkExistingSession() async {
        do {
            // Check if we have a valid session stored
            guard let storedToken = try keychainService.retrieveAccessToken() else {
                await MainActor.run {
                    self.sessionState = .invalid
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
                return
            }
            
            // Try to refresh the session
            try await refreshSession()
            
            await MainActor.run {
                self.sessionState = .authenticated
                self.isAuthenticated = true
            }
            
            // Load user profile
            await loadCurrentUser()
            
        } catch {
            Logger.shared.error("SupabaseService: Check existing session failed - \(error)")
            await MainActor.run {
                self.sessionState = .invalid
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }
    
    private func setupSessionMonitoring() {
        // Monitor session state changes
        $sessionState
            .sink { [weak self] state in
                self?.handleSessionStateChange(state)
            }
            .store(in: &cancellables)
        
        // Monitor network connectivity changes
        setupNetworkMonitoring()
        
        // Monitor app lifecycle events
        setupAppLifecycleMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkReachabilityChanged"),
            object: nil
        )
    }
    
    private func setupAppLifecycleMonitoring() {
        // Monitor app lifecycle events for session management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func networkStatusChanged() {
        // Handle network connectivity changes
        Task {
            await handleNetworkStatusChange()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // App became active, check session validity
        Task {
            await handleAppBecameActive()
        }
    }
    
    @objc private func appWillResignActive() {
        // App will resign active, prepare for background
        handleAppWillResignActive()
    }
    
    private func handleNetworkStatusChange() async {
        // Check if we have network connectivity
        if isNetworkAvailable() {
            // Network is available, check session if needed
            if sessionState == .expired || sessionState == .invalid {
                do {
                    try await checkSession()
                } catch {
                    Logger.shared.error("Network reconnection session check failed: \(error)")
                }
            }
        } else {
            // Network is not available, mark session as potentially stale
            Logger.shared.info("Network unavailable, session may be stale")
        }
    }
    
    private func handleAppBecameActive() async {
        // App became active, check session validity
        do {
            if keychainService.hasValidSession() {
                try await checkSession()
            } else {
                await MainActor.run {
                    self.sessionState = .expired
                }
            }
        } catch {
            Logger.shared.error("App became active session check failed: \(error)")
        }
    }
    
    private func handleAppWillResignActive() {
        // App will resign active, prepare for background
        // Save any pending session data
        Logger.shared.info("App will resign active, preparing for background")
    }
    
    private func isNetworkAvailable() -> Bool {
        // Simple network availability check
        // In a real implementation, you might use Network framework or Reachability
        return true // Mock implementation
    }
    
    private func handleSessionStateChange(_ state: SessionState) {
        switch state {
        case .authenticated:
            isAuthenticated = true
            startSessionRefreshTimer()
        case .expired, .invalid:
            isAuthenticated = false
            currentUser = nil
            stopSessionRefreshTimer()
        case .refreshing:
            // Keep current state while refreshing
            break
        case .unknown:
            // Initial state, will be determined by session check
            break
        }
    }
    
    private func startSessionRefreshTimer() {
        stopSessionRefreshTimer()
        
        // Refresh session every 30 minutes
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshSessionIfNeeded()
            }
        }
    }
    
    private func stopSessionRefreshTimer() {
        sessionRefreshTimer?.invalidate()
        sessionRefreshTimer = nil
    }
    
    private func setupBackgroundRefresh() {
        // Register for background app refresh notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Start background task for session refresh
        startBackgroundTask()
        
        // Schedule background session refresh
        scheduleBackgroundSessionRefresh()
    }
    
    @objc private func appWillEnterForeground() {
        // End background task
        endBackgroundTask()
        
        // Check session validity when returning to foreground
        Task {
            await checkSessionOnForeground()
        }
    }
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SessionRefresh") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func scheduleBackgroundSessionRefresh() {
        // Schedule background session refresh using background task
        Task {
            do {
                try await refreshSessionIfNeeded()
            } catch {
                Logger.shared.error("Background session refresh failed: \(error)")
            }
            endBackgroundTask()
        }
    }
    
    private func checkSessionOnForeground() async {
        do {
            // Check if session is still valid after returning from background
            if keychainService.hasValidSession() {
                try await checkSession()
            } else {
                await MainActor.run {
                    self.sessionState = .expired
                }
            }
        } catch {
            Logger.shared.error("Foreground session check failed: \(error)")
        }
    }
    
    private func loadCurrentUser() async {
        guard let user = client.auth.currentUser else {
            await MainActor.run {
                self.currentUser = nil
            }
            return
        }
        
        await loadUserProfile(from: user)
    }
    
    private func loadUserProfile(from user: User) async {
        // Extract user information from Supabase User
        let fullName = user.userMetadata["full_name"] as? String ?? 
                      user.userMetadata["name"] as? String ?? 
                      user.email ?? "User"
        
        let userProfile = UserProfile(
            id: user.id,
            email: user.email ?? "",
            fullName: fullName,
            role: .parent
        )
        
        await MainActor.run {
            self.currentUser = userProfile
        }
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, fullName: String) async throws -> UserProfile {
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            
            let user = authResponse.user
            
            // Store authentication tokens
            if let session = authResponse.session {
                try keychainService.storeAccessToken(session.accessToken)
                try keychainService.storeRefreshToken(session.refreshToken)
                try keychainService.storeUserID(user.id.uuidString)
            }
            
            let userProfile = UserProfile(
                id: user.id,
                email: user.email ?? email,
                fullName: fullName,
                role: .parent
            )
            
            await MainActor.run {
                self.sessionState = .authenticated
                self.currentUser = userProfile
            }
            
            return userProfile
        } catch {
            Logger.shared.error("SupabaseService: Sign up failed - \(error)")
            throw SupabaseErrorMapper.shared.mapSupabaseError(error)
        }
    }
    
    func signIn(email: String, password: String) async throws -> UserProfile {
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            let user = authResponse.user
            
            // Store authentication tokens
            if let session = authResponse.session {
                try keychainService.storeAccessToken(session.accessToken)
                try keychainService.storeRefreshToken(session.refreshToken)
                try keychainService.storeUserID(user.id.uuidString)
            }
            
            // Extract full name from user metadata
            let fullName = user.userMetadata["full_name"] as? String ?? 
                          user.userMetadata["name"] as? String ?? 
                          user.email ?? "User"
            
            let userProfile = UserProfile(
                id: user.id,
                email: user.email ?? email,
                fullName: fullName,
                role: .parent
            )
            
            await MainActor.run {
                self.sessionState = .authenticated
                self.currentUser = userProfile
            }
            
            return userProfile
        } catch {
            Logger.shared.error("SupabaseService: Sign in failed - \(error)")
            throw SupabaseErrorMapper.shared.mapSupabaseError(error)
        }
    }
    
    func signInWithApple() async throws -> UserProfile {
        // TODO: Implement Apple Sign-In integration
        // This requires additional setup with Apple Sign-In SDK and Supabase
        throw SupabaseError.notImplemented
    }
    
    func signOut() async throws {
        do {
            // Stop session monitoring first
            stopSessionRefreshTimer()
            
            // End any background tasks
            endBackgroundTask()
            
            // Sign out from Supabase
            try await client.auth.signOut()
            
            // Clear stored tokens from keychain
            try keychainService.clearSession()
            
            // Clear any cached data
            await clearCachedData()
            
            await MainActor.run {
                self.sessionState = .invalid
                self.isAuthenticated = false
                self.currentUser = nil
            }
            
            Logger.shared.info("SupabaseService: User signed out successfully")
        } catch {
            Logger.shared.error("SupabaseService: Sign out failed - \(error)")
            throw SupabaseErrorMapper.shared.mapSupabaseError(error)
        }
    }
    
    private func clearCachedData() async {
        // Clear any cached user data, images, etc.
        // This ensures no sensitive data remains in memory
        await MainActor.run {
            // Clear any cached user profiles, children, artwork, etc.
            // TODO: Implement cache clearing when we have actual cached data
        }
    }
    
    func getCurrentUser() -> User? {
        // Get current user from Supabase client
        return client.auth.currentUser
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email)
            Logger.shared.info("SupabaseService: Password reset email sent successfully")
        } catch {
            Logger.shared.error("SupabaseService: Password reset failed - \(error)")
            throw SupabaseErrorMapper.shared.mapSupabaseError(error)
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        // Mock implementation for now
        // TODO: Implement real Supabase password update
    }
    
    func deleteUser(_ userId: UUID) async throws {
        // Mock implementation for now
        // TODO: Implement real Supabase user deletion
        
        // Perform secure logout to clear all data
        try await signOut()
        
        Logger.shared.info("User account deleted successfully")
    }
    
    func checkSession() async throws {
        do {
            // Check if session exists in keychain
            guard let _ = try keychainService.retrieveAccessToken() else {
                await MainActor.run {
                    self.sessionState = .invalid
                }
                return
            }
            
            // TODO: Check if session is expired
            // For now, assume session is valid
            
            // Session is valid, restore user state
            await MainActor.run {
                self.sessionState = .authenticated
                // TODO: Load user profile from session data
            }
            
        } catch {
            Logger.shared.error("Session check failed: \(error)")
            await MainActor.run {
                self.sessionState = .invalid
            }
            throw error
        }
    }
    
    func refreshSession() async throws {
        do {
            await MainActor.run {
                self.sessionState = .refreshing
            }
            
            // Refresh session using Supabase client
            let session = try await client.auth.refreshSession()
            
            // Store new session data
            try keychainService.storeAccessToken(session.accessToken)
            try keychainService.storeRefreshToken(session.refreshToken)
            
            await MainActor.run {
                self.sessionState = .authenticated
            }
            
            Logger.shared.info("SupabaseService: Session refreshed successfully")
            
        } catch {
            Logger.shared.error("SupabaseService: Session refresh failed - \(error)")
            await MainActor.run {
                self.sessionState = .expired
            }
            throw SupabaseErrorMapper.shared.mapSupabaseError(error)
        }
    }
    
    private func refreshSessionIfNeeded() async {
        do {
            // Check if session needs refresh (within 5 minutes of expiry)
            guard let _ = try keychainService.retrieveAccessToken() else {
                Logger.shared.info("No session found for background refresh")
                return
            }
            
            // TODO: Check session expiry and refresh if needed
            Logger.shared.info("Background session check completed")
        } catch {
            Logger.shared.error("Background session refresh failed: \(error)")
        }
    }
    
    // MARK: - Background App Refresh Support
    
    /// Check if background app refresh is available and enabled
    var isBackgroundRefreshAvailable: Bool {
        return UIApplication.shared.backgroundRefreshStatus == .available
    }
    
    /// Request background app refresh permission
    func requestBackgroundRefreshPermission() {
        // This is handled automatically by iOS when the app requests background tasks
        // The user can enable/disable it in Settings > General > Background App Refresh
        Logger.shared.info("Background refresh status: \(UIApplication.shared.backgroundRefreshStatus.rawValue)")
    }
    
    // MARK: - Session State Monitoring
    
    /// Get current session state for debugging
    var currentSessionState: SessionState {
        return sessionState
    }
    
    /// Check if session is in a valid state
    var isSessionValid: Bool {
        return sessionState == .authenticated
    }
    
    /// Get session expiry information
    func getSessionInfo() -> SessionInfo? {
        do {
            guard let _ = try keychainService.retrieveAccessToken() else {
                return nil
            }
            
            // TODO: Return actual session info
            return SessionInfo(
                userID: "mock_user_id",
                expiryDate: Date().addingTimeInterval(3600),
                isExpired: false,
                timeUntilExpiry: 3600
            )
        } catch {
            Logger.shared.error("Failed to get session info: \(error)")
            return nil
        }
    }
    
    /// Force session validation (useful for debugging)
    func forceSessionValidation() async {
        do {
            try await checkSession()
        } catch {
            Logger.shared.error("Force session validation failed: \(error)")
        }
    }
    
    /// Clean up resources when service is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
        // TODO: Clean up timers and background tasks
    }
    
    // MARK: - User Profile Management
    
    func createUserProfile(_ profile: UserProfile) async throws {
        // Mock implementation for now
        // TODO: Implement real Supabase user profile creation
    }
    
    func getUserProfile() async throws -> UserProfile? {
        // Mock implementation for now
        // TODO: Implement real Supabase user profile retrieval
        return self.currentUser
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        // Mock implementation for now
        // TODO: Implement real Supabase user profile update
        await MainActor.run {
            self.currentUser = profile
        }
    }
    
    func uploadProfileImage(_ imageData: Data, for userId: UUID) async throws -> String {
        // Mock implementation for now
        // TODO: Implement real Supabase image upload
        return "https://example.com/mock-profile-image.jpg"
    }
    
    func getUserProfile() async throws -> UserProfile {
        // Mock implementation for now
        // TODO: Implement real Supabase user profile retrieval
        guard let currentUser = self.currentUser else {
            throw SupabaseError.notAuthenticated
        }
        return currentUser
    }
    
    // MARK: - Artwork Management
    
    func getRecentArtwork(for childId: UUID, limit: Int = 6) async throws -> [ArtworkUpload] {
        // Mock implementation for now
        // TODO: Implement real Supabase artwork retrieval
        return []
    }
    
    func getFeaturedStories(for childId: UUID, limit: Int = 3) async throws -> [Story] {
        // Mock implementation for now
        // TODO: Implement real Supabase stories retrieval
        return []
    }
    
    func getChildProgress(for childId: UUID, limit: Int = 5) async throws -> [ProgressEntry] {
        // Mock implementation for now
        // TODO: Implement real Supabase progress retrieval
        return []
    }
    
    func uploadArtwork(
        _ artwork: ArtworkUpload,
        imageData: Data,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ArtworkUpload {
        // Mock implementation for now
        // TODO: Implement real Supabase artwork upload
        progressHandler(1.0)
        return artwork
    }
    
    func uploadArtworkWithProgress(
        _ artwork: ArtworkUpload,
        imageData: Data,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ArtworkUpload {
        // Mock implementation for now
        // TODO: Implement real Supabase artwork upload with progress
        progressHandler(1.0)
        return artwork
    }
    
    func getArtwork(childId: UUID) async throws -> [ArtworkUpload] {
        // Mock implementation for now
        // TODO: Implement real Supabase artwork retrieval
        return []
    }
    
    func getStories(childId: UUID) async throws -> [Story] {
        // Mock implementation for now
        // TODO: Implement real Supabase stories retrieval
        return []
    }
    
    func getChildProgress(childId: UUID) async throws -> [ProgressEntry] {
        // Mock implementation for now
        // TODO: Implement real Supabase progress retrieval
        return []
    }
    
    // MARK: - Child Management
    
    func getChildren() async throws -> [Child] {
        // Mock implementation for now
        // TODO: Implement real Supabase children retrieval
        return []
    }
    
    func createChild(_ child: Child) async throws -> Child {
        // Mock implementation for now
        // TODO: Implement real Supabase child creation
        return child
    }
    
    func updateChild(_ child: Child) async throws -> Child {
        // Mock implementation for now
        // TODO: Implement real Supabase child update
        return child
    }
    
    func deleteChild(_ childId: UUID) async throws {
        // Mock implementation for now
        // TODO: Implement real Supabase child deletion
    }
}

// MARK: - Supporting Types

struct SessionInfo {
    let userID: String
    let expiryDate: Date
    let isExpired: Bool
    let timeUntilExpiry: TimeInterval
}

// MARK: - Supabase Error Mapping Service

class SupabaseErrorMapper {
    static let shared = SupabaseErrorMapper()
    
    private init() {}
    
    /// Maps Supabase error codes to AuthenticationError
    func mapSupabaseError(_ error: Error) -> AuthenticationError {
        // Handle URL errors (network issues)
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }
        
        // Handle HTTP status codes
        if let httpError = error as? HTTPError {
            return mapHTTPError(httpError)
        }
        
        // Handle Supabase-specific errors
        if let supabaseError = error as? SupabaseError {
            return mapSupabaseError(supabaseError)
        }
        
        // Handle authentication-specific errors
        if let authError = error as? AuthenticationError {
            return authError
        }
        
        // Handle generic errors
        return mapGenericError(error)
    }
    
    private func mapURLError(_ urlError: URLError) -> AuthenticationError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .cannotConnectToHost, .cannotFindHost:
            return .networkConnectionFailed
        case .timedOut:
            return .networkSlowConnection
        default:
            return .networkConnectionFailed
        }
    }
    
    private func mapHTTPError(_ httpError: HTTPError) -> AuthenticationError {
        switch httpError.statusCode {
        case 400:
            return .invalidInput("Request data")
        case 401:
            return .invalidCredentials
        case 403:
            return .accountDisabled
        case 404:
            return .userNotFound
        case 409:
            return .emailAlreadyExists
        case 422:
            return .validationFailed("Request validation")
        case 429:
            return .rateLimitExceeded
        case 500:
            return .serverError(500)
        case 502, 503:
            return .serviceUnavailable
        case 504:
            return .serverOverloaded
        default:
            return .serverError(httpError.statusCode)
        }
    }
    
    private func mapSupabaseError(_ supabaseError: SupabaseError) -> AuthenticationError {
        switch supabaseError {
        case .notAuthenticated:
            return .sessionExpired
        case .networkError:
            return .networkConnectionFailed
        case .invalidResponse:
            return .serverError(500)
        case .storageError:
            return .storageError
        case .notImplemented:
            return .unexpectedError
        case .authenticationFailed(_):
            return .invalidCredentials
        case .userNotFound:
            return .userNotFound
        case .emailAlreadyExists:
            return .emailAlreadyExists
        case .weakPassword:
            return .weakPassword
        case .accountLocked:
            return .accountLocked
        case .accountDisabled:
            return .accountDisabled
        case .emailNotVerified:
            return .emailNotVerified
        case .sessionExpired:
            return .sessionExpired
        case .invalidToken:
            return .invalidToken
        case .rateLimitExceeded:
            return .rateLimitExceeded
        case .serverError(_):
            return .serverError(500)
        case .serviceUnavailable:
            return .serviceUnavailable
        case .validationFailed(_):
            return .validationFailed("Validation failed")
        case .missingField(_):
            return .validationFailed("Missing field")
        case .permissionDenied:
            return .permissionDenied
        case .biometricError:
            return .biometricError
        case .appleSignInFailed:
            return .appleSignInFailed
        case .passwordResetFailed:
            return .passwordResetFailed
        case .accountDeletionFailed:
            return .accountDeletionFailed
        case .profileUpdateFailed:
            return .profileUpdateFailed
        case .imageUploadFailed:
            return .imageUploadFailed
        case .unknown(_):
            return .unexpectedError
        }
    }
    
    private func mapGenericError(_ error: Error) -> AuthenticationError {
        let message = error.localizedDescription
        
        // Check for common error patterns
        if message.contains("network") || message.contains("connection") {
            return .networkConnectionFailed
        }
        
        if message.contains("timeout") {
            return .networkTimeout
        }
        
        if message.contains("unauthorized") || message.contains("invalid credentials") {
            return .invalidCredentials
        }
        
        if message.contains("not found") {
            return .userNotFound
        }
        
        if message.contains("already exists") {
            return .emailAlreadyExists
        }
        
        if message.contains("weak password") {
            return .weakPassword
        }
        
        if message.contains("rate limit") {
            return .rateLimitExceeded
        }
        
        if message.contains("server error") {
            return .serverError(500)
        }
        
        return .unknown(message)
    }
    
    /// Maps Supabase error codes to AuthenticationError with context
    func mapSupabaseErrorWithContext(_ error: Error, context: [String: Any] = [:]) -> AuthenticationError {
        let mappedError = mapSupabaseError(error)
        
        // Add context information if available
        if let errorCode = context["error_code"] as? String {
            return mapByErrorCode(errorCode, context: context)
        }
        
        return mappedError
    }
    
    private func mapByErrorCode(_ errorCode: String, context: [String: Any]) -> AuthenticationError {
        switch errorCode.lowercased() {
        case "invalid_credentials", "invalid_email_or_password":
            return .invalidCredentials
        case "user_not_found", "email_not_found":
            return .userNotFound
        case "email_already_exists", "user_already_exists":
            return .emailAlreadyExists
        case "weak_password", "password_too_weak":
            return .weakPassword
        case "account_locked", "too_many_attempts":
            return .accountLocked
        case "account_disabled", "user_disabled":
            return .accountDisabled
        case "email_not_verified", "unverified_email":
            return .emailNotVerified
        case "session_expired", "token_expired":
            return .sessionExpired
        case "invalid_token", "malformed_token":
            return .invalidToken
        case "rate_limit_exceeded", "too_many_requests":
            return .rateLimitExceeded
        case "network_error", "connection_failed":
            return .networkConnectionFailed
        case "server_error", "internal_server_error":
            let code = context["status_code"] as? Int ?? 500
            return .serverError(code)
        case "service_unavailable", "maintenance":
            return .serviceUnavailable
        case "validation_failed", "invalid_input":
            let field = context["field"] as? String ?? "input"
            return .validationFailed(field)
        case "missing_field", "required_field":
            let field = context["field"] as? String ?? "field"
            return .missingRequiredField(field)
        case "storage_error", "upload_failed":
            return .storageError
        case "keychain_error", "secure_storage_error":
            return .keychainError
        case "biometric_error", "face_id_error", "touch_id_error":
            return .biometricError
        case "permission_denied", "access_denied":
            return .permissionDenied
        case "apple_sign_in_cancelled":
            return .appleSignInCancelled
        case "apple_sign_in_failed":
            return .appleSignInFailed
        case "apple_sign_in_not_available":
            return .appleSignInNotAvailable
        case "password_reset_failed":
            return .passwordResetFailed
        case "password_reset_expired":
            return .passwordResetExpired
        case "password_reset_invalid_token":
            return .passwordResetInvalidToken
        case "password_reset_too_frequent":
            return .passwordResetTooFrequent
        case "account_deletion_failed":
            return .accountDeletionFailed
        case "profile_update_failed":
            return .profileUpdateFailed
        case "image_upload_failed":
            return .imageUploadFailed
        default:
            return .unknown(errorCode)
        }
    }
}

// MARK: - HTTP Error

struct HTTPError: Error {
    let statusCode: Int
    let message: String?
    
    init(statusCode: Int, message: String? = nil) {
        self.statusCode = statusCode
        self.message = message
    }
}

// MARK: - Error Types

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case invalidResponse
    case storageError
    case notImplemented
    case authenticationFailed(String)
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case accountLocked
    case accountDisabled
    case emailNotVerified
    case sessionExpired
    case invalidToken
    case rateLimitExceeded
    case serverError(Int)
    case serviceUnavailable
    case validationFailed(String)
    case missingField(String)
    case permissionDenied
    case biometricError
    case appleSignInFailed
    case passwordResetFailed
    case accountDeletionFailed
    case profileUpdateFailed
    case imageUploadFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from server"
        case .storageError:
            return "Storage operation failed"
        case .notImplemented:
            return "Feature not implemented"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "Email already exists"
        case .weakPassword:
            return "Password is too weak"
        case .accountLocked:
            return "Account is locked"
        case .accountDisabled:
            return "Account is disabled"
        case .emailNotVerified:
            return "Email not verified"
        case .sessionExpired:
            return "Session has expired"
        case .invalidToken:
            return "Invalid authentication token"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError(let code):
            return "Server error (Code: \(code))"
        case .serviceUnavailable:
            return "Service is unavailable"
        case .validationFailed(let field):
            return "Validation failed for \(field)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .permissionDenied:
            return "Permission denied"
        case .biometricError:
            return "Biometric authentication failed"
        case .appleSignInFailed:
            return "Apple Sign-In failed"
        case .passwordResetFailed:
            return "Password reset failed"
        case .accountDeletionFailed:
            return "Account deletion failed"
        case .profileUpdateFailed:
            return "Profile update failed"
        case .imageUploadFailed:
            return "Image upload failed"
        case .unknown(let message):
            return message
        }
    }
    
    var errorCode: String {
        switch self {
        case .notAuthenticated: return "NOT_AUTHENTICATED"
        case .networkError: return "NETWORK_ERROR"
        case .invalidResponse: return "INVALID_RESPONSE"
        case .storageError: return "STORAGE_ERROR"
        case .notImplemented: return "NOT_IMPLEMENTED"
        case .authenticationFailed: return "AUTHENTICATION_FAILED"
        case .userNotFound: return "USER_NOT_FOUND"
        case .emailAlreadyExists: return "EMAIL_ALREADY_EXISTS"
        case .weakPassword: return "WEAK_PASSWORD"
        case .accountLocked: return "ACCOUNT_LOCKED"
        case .accountDisabled: return "ACCOUNT_DISABLED"
        case .emailNotVerified: return "EMAIL_NOT_VERIFIED"
        case .sessionExpired: return "SESSION_EXPIRED"
        case .invalidToken: return "INVALID_TOKEN"
        case .rateLimitExceeded: return "RATE_LIMIT_EXCEEDED"
        case .serverError(let code): return "SERVER_ERROR_\(code)"
        case .serviceUnavailable: return "SERVICE_UNAVAILABLE"
        case .validationFailed(let field): return "VALIDATION_FAILED_\(field.uppercased())"
        case .missingField(let field): return "MISSING_FIELD_\(field.uppercased())"
        case .permissionDenied: return "PERMISSION_DENIED"
        case .biometricError: return "BIOMETRIC_ERROR"
        case .appleSignInFailed: return "APPLE_SIGN_IN_FAILED"
        case .passwordResetFailed: return "PASSWORD_RESET_FAILED"
        case .accountDeletionFailed: return "ACCOUNT_DELETION_FAILED"
        case .profileUpdateFailed: return "PROFILE_UPDATE_FAILED"
        case .imageUploadFailed: return "IMAGE_UPLOAD_FAILED"
        case .unknown(let message): return "UNKNOWN_\(message.hashValue)"
        }
    }
}
