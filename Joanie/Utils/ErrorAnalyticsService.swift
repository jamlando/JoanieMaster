import Foundation
import Combine
import UIKit

// MARK: - Error Analytics Service

class ErrorAnalyticsService {
    static let shared = ErrorAnalyticsService()
    
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Error Metrics
    
    struct ErrorMetrics {
        let errorCode: String
        let errorType: String
        let severity: ErrorSeverity
        let timestamp: Date
        let sessionID: String
        let userID: String?
        let deviceInfo: DeviceInfo
        let networkInfo: NetworkInfo
        let context: [String: Any]
        let retryAttempts: Int
        let recoveryAction: String?
        let duration: TimeInterval?
    }
    
    struct DeviceInfo {
        let model: String
        let osVersion: String
        let appVersion: String
        let screenSize: String
        let orientation: String
        
        static var current: DeviceInfo {
            let screen = UIScreen.main
            let bounds = screen.bounds
            let orientation = screen.bounds.width > screen.bounds.height ? "landscape" : "portrait"
            
            return DeviceInfo(
                model: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                screenSize: "\(Int(bounds.width))x\(Int(bounds.height))",
                orientation: orientation
            )
        }
    }
    
    struct NetworkInfo {
        let connectionType: String
        let isConnected: Bool
        let reachabilityStatus: String
        
        static var current: NetworkInfo {
            // Mock implementation - in real app, use Network framework
            return NetworkInfo(
                connectionType: "wifi", // or "cellular", "ethernet", etc.
                isConnected: true,
                reachabilityStatus: "reachable"
            )
        }
    }
    
    // MARK: - Error Events
    
    enum ErrorEvent {
        case errorOccurred(AuthenticationError, context: [String: Any])
        case retryAttempted(AuthenticationError, attempt: Int)
        case retrySucceeded(AuthenticationError, attempts: Int, duration: TimeInterval)
        case retryFailed(AuthenticationError, attempts: Int, finalError: Error)
        case recoveryActionTriggered(AuthenticationError, action: String)
        case errorDismissed(AuthenticationError, dismissedBy: String)
    }
    
    private init() {
        setupErrorTracking()
    }
    
    // MARK: - Public Methods
    
    func trackError(_ error: AuthenticationError, context: [String: Any] = [:]) {
        let metrics = createErrorMetrics(for: error, context: context)
        logErrorMetrics(metrics)
        sendToAnalytics(metrics)
    }
    
    func trackRetryAttempt(_ error: AuthenticationError, attempt: Int) {
        let event = ErrorEvent.retryAttempted(error, attempt: attempt)
        logEvent(event)
    }
    
    func trackRetrySuccess(_ error: AuthenticationError, attempts: Int, duration: TimeInterval) {
        let event = ErrorEvent.retrySucceeded(error, attempts: attempts, duration: duration)
        logEvent(event)
    }
    
    func trackRetryFailure(_ error: AuthenticationError, attempts: Int, finalError: Error) {
        let event = ErrorEvent.retryFailed(error, attempts: attempts, finalError: finalError)
        logEvent(event)
    }
    
    func trackRecoveryAction(_ error: AuthenticationError, action: String) {
        let event = ErrorEvent.recoveryActionTriggered(error, action: action)
        logEvent(event)
    }
    
    func trackErrorDismissal(_ error: AuthenticationError, dismissedBy: String) {
        let event = ErrorEvent.errorDismissed(error, dismissedBy: dismissedBy)
        logEvent(event)
    }
    
    // MARK: - Analytics Integration
    
    func sendToAnalytics(_ metrics: ErrorMetrics) {
        // Integration with analytics services (Firebase, Mixpanel, etc.)
        let analyticsData: [String: Any] = [
            "event": "auth_error",
            "error_code": metrics.errorCode,
            "error_type": metrics.errorType,
            "severity": metrics.severity.rawValue,
            "timestamp": metrics.timestamp.timeIntervalSince1970,
            "session_id": metrics.sessionID,
            "user_id": metrics.userID ?? "anonymous",
            "device_model": metrics.deviceInfo.model,
            "os_version": metrics.deviceInfo.osVersion,
            "app_version": metrics.deviceInfo.appVersion,
            "screen_size": metrics.deviceInfo.screenSize,
            "orientation": metrics.deviceInfo.orientation,
            "connection_type": metrics.networkInfo.connectionType,
            "is_connected": metrics.networkInfo.isConnected,
            "retry_attempts": metrics.retryAttempts,
            "recovery_action": metrics.recoveryAction ?? "none",
            "duration": metrics.duration ?? 0,
            "context": metrics.context
        ]
        
        // Send to analytics service
        sendToFirebaseAnalytics(analyticsData)
        sendToCrashlytics(metrics)
    }
    
    private func sendToFirebaseAnalytics(_ data: [String: Any]) {
        // Mock Firebase Analytics integration
        logger.logInfo("Firebase Analytics: Sending error event - \(data["error_code"] ?? "unknown")")
    }
    
    private func sendToCrashlytics(_ metrics: ErrorMetrics) {
        // Mock Crashlytics integration
        logger.logError("Crashlytics: Error tracked - \(metrics.errorCode)")
    }
    
    // MARK: - Error Reporting
    
    func generateErrorReport(for error: AuthenticationError, context: [String: Any] = [:]) -> String {
        let metrics = createErrorMetrics(for: error, context: context)
        
        var report = """
        ERROR REPORT
        ============
        
        Error Code: \(metrics.errorCode)
        Error Type: \(metrics.errorType)
        Severity: \(metrics.severity)
        Timestamp: \(metrics.timestamp)
        
        Device Information:
        - Model: \(metrics.deviceInfo.model)
        - OS Version: \(metrics.deviceInfo.osVersion)
        - App Version: \(metrics.deviceInfo.appVersion)
        - Screen Size: \(metrics.deviceInfo.screenSize)
        - Orientation: \(metrics.deviceInfo.orientation)
        
        Network Information:
        - Connection Type: \(metrics.networkInfo.connectionType)
        - Connected: \(metrics.networkInfo.isConnected)
        - Status: \(metrics.networkInfo.reachabilityStatus)
        
        Session Information:
        - Session ID: \(metrics.sessionID)
        - User ID: \(metrics.userID ?? "anonymous")
        
        Error Details:
        - Description: \(error.localizedDescription)
        - Recovery Suggestion: \(error.recoverySuggestion ?? "none")
        - Can Retry: \(error.canRetry)
        - Retry Attempts: \(metrics.retryAttempts)
        - Recovery Action: \(metrics.recoveryAction ?? "none")
        - Duration: \(metrics.duration?.description ?? "none")
        
        Context:
        """
        
        for (key, value) in metrics.context {
            report += "\n- \(key): \(value)"
        }
        
        return report
    }
    
    // MARK: - Error Statistics
    
    func getErrorStatistics() -> ErrorStatistics {
        // Mock implementation - in real app, this would query a database
        return ErrorStatistics(
            totalErrors: 0,
            errorsByType: [:],
            errorsBySeverity: [:],
            averageRetryAttempts: 0,
            successRate: 0,
            mostCommonErrors: []
        )
    }
    
    struct ErrorStatistics {
        let totalErrors: Int
        let errorsByType: [String: Int]
        let errorsBySeverity: [ErrorSeverity: Int]
        let averageRetryAttempts: Double
        let successRate: Double
        let mostCommonErrors: [String]
    }
    
    // MARK: - Private Methods
    
    private func setupErrorTracking() {
        // Set up automatic error tracking
        logger.$logLevel
            .sink { [weak self] level in
                if level == .error {
                    // Track logger errors
                }
            }
            .store(in: &cancellables)
    }
    
    private func createErrorMetrics(for error: AuthenticationError, context: [String: Any]) -> ErrorMetrics {
        return ErrorMetrics(
            errorCode: error.errorCode,
            errorType: String(describing: type(of: error)),
            severity: error.severity,
            timestamp: Date(),
            sessionID: generateSessionID(),
            userID: getCurrentUserID(),
            deviceInfo: DeviceInfo.current,
            networkInfo: NetworkInfo.current,
            context: context,
            retryAttempts: context["retry_attempts"] as? Int ?? 0,
            recoveryAction: context["recovery_action"] as? String,
            duration: context["duration"] as? TimeInterval
        )
    }
    
    private func logErrorMetrics(_ metrics: ErrorMetrics) {
        logger.logError("""
        Error Analytics:
        - Code: \(metrics.errorCode)
        - Type: \(metrics.errorType)
        - Severity: \(metrics.severity)
        - Session: \(metrics.sessionID)
        - User: \(metrics.userID ?? "anonymous")
        - Retry Attempts: \(metrics.retryAttempts)
        - Recovery Action: \(metrics.recoveryAction ?? "none")
        """)
    }
    
    private func logEvent(_ event: ErrorEvent) {
        switch event {
        case .errorOccurred(let error, let context):
            logger.logError("Error occurred: \(error.errorCode) - \(context)")
        case .retryAttempted(let error, let attempt):
            logger.logInfo("Retry attempted for \(error.errorCode) - attempt \(attempt)")
        case .retrySucceeded(let error, let attempts, let duration):
            logger.logInfo("Retry succeeded for \(error.errorCode) after \(attempts) attempts in \(duration)s")
        case .retryFailed(let error, let attempts, let finalError):
            logger.logError("Retry failed for \(error.errorCode) after \(attempts) attempts - final error: \(finalError)")
        case .recoveryActionTriggered(let error, let action):
            logger.logInfo("Recovery action '\(action)' triggered for \(error.errorCode)")
        case .errorDismissed(let error, let dismissedBy):
            logger.logInfo("Error \(error.errorCode) dismissed by \(dismissedBy)")
        }
    }
    
    private func generateSessionID() -> String {
        return UUID().uuidString
    }
    
    private func getCurrentUserID() -> String? {
        // Get current user ID from AuthService
        return nil // Mock implementation
    }
}

// MARK: - Error Analytics Extensions

extension AuthenticationError {
    func track(context: [String: Any] = [:]) {
        ErrorAnalyticsService.shared.trackError(self, context: context)
    }
    
    func trackRetryAttempt(_ attempt: Int) {
        ErrorAnalyticsService.shared.trackRetryAttempt(self, attempt: attempt)
    }
    
    func trackRetrySuccess(attempts: Int, duration: TimeInterval) {
        ErrorAnalyticsService.shared.trackRetrySuccess(self, attempts: attempts, duration: duration)
    }
    
    func trackRetryFailure(attempts: Int, finalError: Error) {
        ErrorAnalyticsService.shared.trackRetryFailure(self, attempts: attempts, finalError: finalError)
    }
    
    func trackRecoveryAction(_ action: String) {
        ErrorAnalyticsService.shared.trackRecoveryAction(self, action: action)
    }
    
    func trackDismissal(dismissedBy: String) {
        ErrorAnalyticsService.shared.trackErrorDismissal(self, dismissedBy: dismissedBy)
    }
}

// MARK: - Error Analytics Integration

extension AuthService {
    func trackAuthenticationError(_ error: AuthenticationError, context: [String: Any] = [:]) {
        var trackingContext = context
        trackingContext["auth_method"] = "email_password" // or "apple_sign_in", etc.
        trackingContext["user_authenticated"] = isAuthenticated
        trackingContext["session_valid"] = currentUser != nil
        
        error.track(context: trackingContext)
    }
}

extension SupabaseService {
    func trackSupabaseError(_ error: Error, context: [String: Any] = [:]) {
        let authError = SupabaseErrorMapper.shared.mapSupabaseError(error)
        var trackingContext = context
        trackingContext["supabase_error"] = true
        trackingContext["original_error"] = error.localizedDescription
        
        authError.track(context: trackingContext)
    }
}

