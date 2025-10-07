import Foundation
import Combine

// MARK: - Sentry Integration Service

class SentryIntegrationService {
    static let shared = SentryIntegrationService()
    
    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private var isEnabled: Bool = true
    private var dsn: String?
    private var environment: String = "development"
    private var release: String?
    
    private init() {
        self.logger = Logger.shared
        setupConfiguration()
    }
    
    // MARK: - Configuration
    
    private func setupConfiguration() {
        // Load configuration from environment or config file
        dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String
        environment = Bundle.main.object(forInfoDictionaryKey: "SENTRY_ENVIRONMENT") as? String ?? "development"
        release = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        
        // Enable/disable based on configuration
        isEnabled = dsn != nil && environment != "development"
        
        logger.info("Sentry integration initialized - Enabled: \(isEnabled), Environment: \(environment)")
    }
    
    // MARK: - Public Methods
    
    /// Logs a feature toggle error to Sentry
    func logToggleError(
        error: Error,
        toggleId: String,
        context: [String: Any] = [:]
    ) {
        guard isEnabled else {
            logger.debug("Sentry logging disabled, skipping toggle error: \(error.localizedDescription)")
            return
        }
        
        let sentryEvent = createToggleErrorEvent(
            error: error,
            toggleId: toggleId,
            context: context
        )
        
        sendToSentry(sentryEvent)
    }
    
    /// Logs a feature toggle configuration error
    func logToggleConfigurationError(
        toggleId: String,
        configuration: [String: Any],
        error: Error
    ) {
        guard isEnabled else {
            logger.debug("Sentry logging disabled, skipping configuration error: \(error.localizedDescription)")
            return
        }
        
        let sentryEvent = createConfigurationErrorEvent(
            toggleId: toggleId,
            configuration: configuration,
            error: error
        )
        
        sendToSentry(sentryEvent)
    }
    
    /// Logs a notification permission error
    func logNotificationPermissionError(
        error: Error,
        toggleId: String,
        permissionStatus: String
    ) {
        guard isEnabled else {
            logger.debug("Sentry logging disabled, skipping permission error: \(error.localizedDescription)")
            return
        }
        
        let sentryEvent = createPermissionErrorEvent(
            error: error,
            toggleId: toggleId,
            permissionStatus: permissionStatus
        )
        
        sendToSentry(sentryEvent)
    }
    
    /// Logs a toggle sync error
    func logToggleSyncError(
        error: Error,
        toggleCount: Int,
        lastSyncDate: Date?
    ) {
        guard isEnabled else {
            logger.debug("Sentry logging disabled, skipping sync error: \(error.localizedDescription)")
            return
        }
        
        let sentryEvent = createSyncErrorEvent(
            error: error,
            toggleCount: toggleCount,
            lastSyncDate: lastSyncDate
        )
        
        sendToSentry(sentryEvent)
    }
    
    /// Logs a toggle evaluation error
    func logToggleEvaluationError(
        error: Error,
        toggleId: String,
        userId: String?,
        scope: String
    ) {
        guard isEnabled else {
            logger.debug("Sentry logging disabled, skipping evaluation error: \(error.localizedDescription)")
            return
        }
        
        let sentryEvent = createEvaluationErrorEvent(
            error: error,
            toggleId: toggleId,
            userId: userId,
            scope: scope
        )
        
        sendToSentry(sentryEvent)
    }
    
    /// Sets user context for Sentry
    func setUserContext(userId: String?, email: String?, username: String?) {
        guard isEnabled else { return }
        
        let userContext: [String: Any] = [
            "id": userId ?? "anonymous",
            "email": email ?? "",
            "username": username ?? ""
        ]
        
        logger.info("Sentry user context set: \(userContext)")
        // In real implementation, this would call Sentry SDK
    }
    
    /// Sets custom context for Sentry
    func setCustomContext(key: String, value: Any) {
        guard isEnabled else { return }
        
        logger.info("Sentry custom context set: \(key) = \(value)")
        // In real implementation, this would call Sentry SDK
    }
    
    // MARK: - Private Methods
    
    private func createToggleErrorEvent(
        error: Error,
        toggleId: String,
        context: [String: Any]
    ) -> SentryEvent {
        return SentryEvent(
            level: .error,
            message: "Feature toggle error: \(error.localizedDescription)",
            tags: [
                "toggle_id": toggleId,
                "error_type": String(describing: type(of: error))
            ],
            extra: [
                "toggle_id": toggleId,
                "error_description": error.localizedDescription,
                "context": context
            ],
            fingerprint: ["toggle_error", toggleId],
            user: getUserContext(),
            release: release,
            environment: environment
        )
    }
    
    private func createConfigurationErrorEvent(
        toggleId: String,
        configuration: [String: Any],
        error: Error
    ) -> SentryEvent {
        return SentryEvent(
            level: .error,
            message: "Toggle configuration error: \(error.localizedDescription)",
            tags: [
                "toggle_id": toggleId,
                "error_type": "configuration_error"
            ],
            extra: [
                "toggle_id": toggleId,
                "configuration": configuration,
                "error_description": error.localizedDescription
            ],
            fingerprint: ["toggle_config_error", toggleId],
            user: getUserContext(),
            release: release,
            environment: environment
        )
    }
    
    private func createPermissionErrorEvent(
        error: Error,
        toggleId: String,
        permissionStatus: String
    ) -> SentryEvent {
        return SentryEvent(
            level: .warning,
            message: "Notification permission error: \(error.localizedDescription)",
            tags: [
                "toggle_id": toggleId,
                "permission_status": permissionStatus,
                "error_type": "permission_error"
            ],
            extra: [
                "toggle_id": toggleId,
                "permission_status": permissionStatus,
                "error_description": error.localizedDescription
            ],
            fingerprint: ["permission_error", toggleId],
            user: getUserContext(),
            release: release,
            environment: environment
        )
    }
    
    private func createSyncErrorEvent(
        error: Error,
        toggleCount: Int,
        lastSyncDate: Date?
    ) -> SentryEvent {
        return SentryEvent(
            level: .error,
            message: "Toggle sync error: \(error.localizedDescription)",
            tags: [
                "error_type": "sync_error",
                "toggle_count": String(toggleCount)
            ],
            extra: [
                "toggle_count": toggleCount,
                "last_sync_date": lastSyncDate?.timeIntervalSince1970 ?? 0,
                "error_description": error.localizedDescription
            ],
            fingerprint: ["sync_error"],
            user: getUserContext(),
            release: release,
            environment: environment
        )
    }
    
    private func createEvaluationErrorEvent(
        error: Error,
        toggleId: String,
        userId: String?,
        scope: String
    ) -> SentryEvent {
        return SentryEvent(
            level: .error,
            message: "Toggle evaluation error: \(error.localizedDescription)",
            tags: [
                "toggle_id": toggleId,
                "scope": scope,
                "error_type": "evaluation_error"
            ],
            extra: [
                "toggle_id": toggleId,
                "user_id": userId ?? "anonymous",
                "scope": scope,
                "error_description": error.localizedDescription
            ],
            fingerprint: ["evaluation_error", toggleId],
            user: getUserContext(),
            release: release,
            environment: environment
        )
    }
    
    private func sendToSentry(_ event: SentryEvent) {
        // Mock implementation - in production, this would use Sentry SDK
        logger.error("""
        Sentry Event:
        - Level: \(event.level.rawValue)
        - Message: \(event.message)
        - Tags: \(event.tags)
        - Extra: \(event.extra)
        - Fingerprint: \(event.fingerprint)
        """)
        
        // Real implementation would be:
        // SentrySDK.capture(event: event)
    }
    
    private func getUserContext() -> [String: Any] {
        // Get user context from AuthService or AppState
        return [
            "id": "anonymous", // TODO: Get from AuthService
            "email": "",
            "username": ""
        ]
    }
}

// MARK: - Sentry Event Model

struct SentryEvent {
    let level: SentryLevel
    let message: String
    let tags: [String: String]
    let extra: [String: Any]
    let fingerprint: [String]
    let user: [String: Any]
    let release: String?
    let environment: String
    let timestamp: Date
    
    init(
        level: SentryLevel,
        message: String,
        tags: [String: String] = [:],
        extra: [String: Any] = [:],
        fingerprint: [String] = [],
        user: [String: Any] = [:],
        release: String? = nil,
        environment: String = "development",
        timestamp: Date = Date()
    ) {
        self.level = level
        self.message = message
        self.tags = tags
        self.extra = extra
        self.fingerprint = fingerprint
        self.user = user
        self.release = release
        self.environment = environment
        self.timestamp = timestamp
    }
}

enum SentryLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"
}

// MARK: - Feature Toggle Error Extensions

extension FeatureToggleManager {
    func logToggleError(_ error: Error, toggleId: String, context: [String: Any] = [:]) {
        SentryIntegrationService.shared.logToggleError(
            error: error,
            toggleId: toggleId,
            context: context
        )
    }
    
    func logConfigurationError(toggleId: String, configuration: [String: Any], error: Error) {
        SentryIntegrationService.shared.logToggleConfigurationError(
            toggleId: toggleId,
            configuration: configuration,
            error: error
        )
    }
    
    func logSyncError(_ error: Error, toggleCount: Int, lastSyncDate: Date?) {
        SentryIntegrationService.shared.logToggleSyncError(
            error: error,
            toggleCount: toggleCount,
            lastSyncDate: lastSyncDate
        )
    }
    
    func logEvaluationError(_ error: Error, toggleId: String, userId: String?, scope: String) {
        SentryIntegrationService.shared.logToggleEvaluationError(
            error: error,
            toggleId: toggleId,
            userId: userId,
            scope: scope
        )
    }
}

extension NotificationToggleService {
    func logPermissionError(_ error: Error, toggleId: String, permissionStatus: UNAuthorizationStatus) {
        SentryIntegrationService.shared.logNotificationPermissionError(
            error: error,
            toggleId: toggleId,
            permissionStatus: String(permissionStatus.rawValue)
        )
    }
}

extension FeatureToggleService {
    func logStorageError(_ error: Error, toggleId: String) {
        SentryIntegrationService.shared.logToggleError(
            error: error,
            toggleId: toggleId,
            context: [
                "error_type": "storage_error",
                "storage_type": "core_data"
            ]
        )
    }
}

extension ToggleScopeManager {
    func logScopeError(_ error: Error, toggleId: String, scope: ToggleScope) {
        SentryIntegrationService.shared.logToggleError(
            error: error,
            toggleId: toggleId,
            context: [
                "error_type": "scope_error",
                "scope": scope.rawValue
            ]
        )
    }
}

// MARK: - Error Handling Integration

extension FeatureToggleManager {
    func handleToggleError(_ error: Error, toggleId: String, context: [String: Any] = [:]) {
        // Log to Sentry
        logToggleError(error, toggleId: toggleId, context: context)
        
        // Log to local logger
        logger.error("Toggle error for \(toggleId): \(error.localizedDescription)")
        
        // Update error state
        syncError = error.localizedDescription
        
        // Track analytics
        FeatureToggleAnalyticsService.shared.trackToggleChecked(
            toggleId,
            enabled: false,
            scope: .global,
            userId: currentUserId
        )
    }
}
