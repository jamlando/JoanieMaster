import Foundation
import Combine
import UserNotifications
import UIKit

// MARK: - Feature Toggle Analytics Service

class FeatureToggleAnalyticsService {
    static let shared = FeatureToggleAnalyticsService()
    
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Toggle Analytics Events
    
    enum ToggleEvent {
        case toggleEnabled(String, scope: ToggleScope, experimentId: String?)
        case toggleDisabled(String, scope: ToggleScope, experimentId: String?)
        case toggleChecked(String, enabled: Bool, scope: ToggleScope)
        case experimentParticipated(String, variant: String, userId: String?)
        case notificationSent(String, type: NotificationType, success: Bool)
        case permissionRequested(UNAuthorizationStatus)
        case permissionGranted(Bool)
        case syncPerformed(success: Bool, toggleCount: Int)
        case targetingRuleEvaluated(String, result: Bool, userId: String?)
    }
    
    // MARK: - Analytics Data Structures
    
    struct ToggleAnalyticsData {
        let eventName: String
        let toggleId: String?
        let toggleName: String?
        let scope: ToggleScope?
        let experimentId: String?
        let variant: String?
        let userId: String?
        let timestamp: Date
        let sessionId: String
        let deviceInfo: DeviceInfo
        let context: [String: Any]
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
    
    private init() {
        setupAnalyticsTracking()
    }
    
    // MARK: - Public Methods
    
    func trackToggleEnabled(_ toggleId: String, scope: ToggleScope, experimentId: String? = nil, userId: String? = nil) {
        let event = ToggleEvent.toggleEnabled(toggleId, scope: scope, experimentId: experimentId)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "toggle_enabled",
            toggleId: toggleId,
            scope: scope,
            experimentId: experimentId,
            userId: userId
        ))
    }
    
    func trackToggleDisabled(_ toggleId: String, scope: ToggleScope, experimentId: String? = nil, userId: String? = nil) {
        let event = ToggleEvent.toggleDisabled(toggleId, scope: scope, experimentId: experimentId)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "toggle_disabled",
            toggleId: toggleId,
            scope: scope,
            experimentId: experimentId,
            userId: userId
        ))
    }
    
    func trackToggleChecked(_ toggleId: String, enabled: Bool, scope: ToggleScope, userId: String? = nil) {
        let event = ToggleEvent.toggleChecked(toggleId, enabled: enabled, scope: scope)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "toggle_checked",
            toggleId: toggleId,
            scope: scope,
            userId: userId,
            context: ["enabled": enabled]
        ))
    }
    
    func trackExperimentParticipation(_ experimentId: String, variant: String, userId: String? = nil) {
        let event = ToggleEvent.experimentParticipated(experimentId, variant: variant, userId: userId)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "experiment_participated",
            experimentId: experimentId,
            variant: variant,
            userId: userId
        ))
    }
    
    func trackNotificationSent(_ notificationType: NotificationType, success: Bool, userId: String? = nil) {
        let event = ToggleEvent.notificationSent("notification_sent", type: notificationType, success: success)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "notification_sent",
            userId: userId,
            context: [
                "notification_type": notificationType.rawValue,
                "success": success
            ]
        ))
    }
    
    func trackPermissionRequested(_ status: UNAuthorizationStatus) {
        let event = ToggleEvent.permissionRequested(status)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "notification_permission_requested",
            context: ["status": status.rawValue]
        ))
    }
    
    func trackPermissionGranted(_ granted: Bool) {
        let event = ToggleEvent.permissionGranted(granted)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "notification_permission_granted",
            context: ["granted": granted]
        ))
    }
    
    func trackSyncPerformed(_ success: Bool, toggleCount: Int) {
        let event = ToggleEvent.syncPerformed(success: success, toggleCount: toggleCount)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "toggle_sync_performed",
            context: [
                "success": success,
                "toggle_count": toggleCount
            ]
        ))
    }
    
    func trackTargetingRuleEvaluated(_ ruleType: String, result: Bool, userId: String? = nil) {
        let event = ToggleEvent.targetingRuleEvaluated(ruleType, result: result, userId: userId)
        logEvent(event)
        sendToAnalytics(createAnalyticsData(
            eventName: "targeting_rule_evaluated",
            userId: userId,
            context: [
                "rule_type": ruleType,
                "result": result
            ]
        ))
    }
    
    // MARK: - Analytics Integration
    
    private func sendToAnalytics(_ data: ToggleAnalyticsData) {
        let analyticsData: [String: Any] = [
            "event": data.eventName,
            "toggle_id": data.toggleId ?? "",
            "toggle_name": data.toggleName ?? "",
            "scope": data.scope?.rawValue ?? "",
            "experiment_id": data.experimentId ?? "",
            "variant": data.variant ?? "",
            "user_id": data.userId ?? "anonymous",
            "timestamp": data.timestamp.timeIntervalSince1970,
            "session_id": data.sessionId,
            "device_model": data.deviceInfo.model,
            "os_version": data.deviceInfo.osVersion,
            "app_version": data.deviceInfo.appVersion,
            "screen_size": data.deviceInfo.screenSize,
            "orientation": data.deviceInfo.orientation,
            "context": data.context
        ]
        
        // Send to Firebase Analytics
        sendToFirebaseAnalytics(analyticsData)
        
        // Send to custom analytics if needed
        sendToCustomAnalytics(analyticsData)
    }
    
    private func sendToFirebaseAnalytics(_ data: [String: Any]) {
        // Mock Firebase Analytics integration
        // In production, this would use Firebase Analytics SDK
        logger.info("Firebase Analytics: Sending toggle event - \(data["event"] ?? "unknown")")
        
        // Example Firebase Analytics call:
        // Analytics.logEvent(data["event"] as? String ?? "unknown_event", parameters: data)
    }
    
    private func sendToCustomAnalytics(_ data: [String: Any]) {
        // Send to custom analytics service if needed
        logger.info("Custom Analytics: Sending toggle event - \(data["event"] ?? "unknown")")
    }
    
    // MARK: - Analytics Reports
    
    func generateToggleUsageReport() -> String {
        // Mock implementation - in production, this would query analytics data
        return """
        FEATURE TOGGLE USAGE REPORT
        ===========================
        
        Generated: \(Date())
        
        Summary:
        - Total toggle checks: 0
        - Most used toggle: notifications_enabled
        - Experiment participation rate: 0%
        - Notification success rate: 0%
        
        Top Toggles:
        1. notifications_enabled - 0 checks
        2. new_ui_enabled - 0 checks
        
        Experiments:
        - notification_timing_test: 0 participants
        
        Recommendations:
        - Monitor toggle usage patterns
        - Analyze experiment results
        - Optimize notification delivery
        """
    }
    
    // MARK: - Private Methods
    
    private func setupAnalyticsTracking() {
        // Set up automatic tracking for analytics events
        // Note: Logger doesn't have a $logLevel property, so this is commented out
        // In a real implementation, you would set up proper analytics tracking
    }
    
    private func createAnalyticsData(
        eventName: String,
        toggleId: String? = nil,
        toggleName: String? = nil,
        scope: ToggleScope? = nil,
        experimentId: String? = nil,
        variant: String? = nil,
        userId: String? = nil,
        context: [String: Any] = [:]
    ) -> ToggleAnalyticsData {
        return ToggleAnalyticsData(
            eventName: eventName,
            toggleId: toggleId,
            toggleName: toggleName,
            scope: scope,
            experimentId: experimentId,
            variant: variant,
            userId: userId,
            timestamp: Date(),
            sessionId: generateSessionId(),
            deviceInfo: DeviceInfo.current,
            context: context
        )
    }
    
    private func logEvent(_ event: ToggleEvent) {
        switch event {
        case .toggleEnabled(let toggleId, let scope, let experimentId):
            logger.info("Toggle enabled: \(toggleId) (\(scope)) - experiment: \(experimentId ?? "none")")
        case .toggleDisabled(let toggleId, let scope, let experimentId):
            logger.info("Toggle disabled: \(toggleId) (\(scope)) - experiment: \(experimentId ?? "none")")
        case .toggleChecked(let toggleId, let enabled, let scope):
            logger.info("Toggle checked: \(toggleId) = \(enabled) (\(scope))")
        case .experimentParticipated(let experimentId, let variant, let userId):
            logger.info("Experiment participation: \(experimentId) (\(variant)) - user: \(userId ?? "anonymous")")
        case .notificationSent(let message, let type, let success):
            logger.info("Notification sent: \(message) - type: \(type) - success: \(success)")
        case .permissionRequested(let status):
            logger.info("Permission requested: \(status.rawValue)")
        case .permissionGranted(let granted):
            logger.info("Permission granted: \(granted)")
        case .syncPerformed(let success, let toggleCount):
            logger.info("Sync performed: success=\(success), count=\(toggleCount)")
        case .targetingRuleEvaluated(let ruleType, let result, let userId):
            logger.info("Targeting rule evaluated: \(ruleType) = \(result) - user: \(userId ?? "anonymous")")
        }
    }
    
    private func generateSessionId() -> String {
        return UUID().uuidString
    }
}

// MARK: - Feature Toggle Analytics Extensions

extension FeatureToggleManager {
    func trackToggleUsage(toggleId: String, action: String) {
        switch action {
        case "enabled":
            FeatureToggleAnalyticsService.shared.trackToggleEnabled(
                toggleId,
                scope: getToggle(id: toggleId, as: BaseFeatureToggle.self)?.scope ?? .global,
                experimentId: getToggle(id: toggleId, as: BaseFeatureToggle.self)?.experimentId,
                userId: currentUserId
            )
        case "disabled":
            FeatureToggleAnalyticsService.shared.trackToggleDisabled(
                toggleId,
                scope: getToggle(id: toggleId, as: BaseFeatureToggle.self)?.scope ?? .global,
                experimentId: getToggle(id: toggleId, as: BaseFeatureToggle.self)?.experimentId,
                userId: currentUserId
            )
        case "checked":
            FeatureToggleAnalyticsService.shared.trackToggleChecked(
                toggleId,
                enabled: isToggleEnabled(id: toggleId),
                scope: getToggle(id: toggleId, as: BaseFeatureToggle.self)?.scope ?? .global,
                userId: currentUserId
            )
        default:
            break
        }
    }
    
    func trackExperimentParticipation(experimentId: String, variant: String) {
        FeatureToggleAnalyticsService.shared.trackExperimentParticipation(
            experimentId,
            variant: variant,
            userId: currentUserId
        )
    }
}

extension NotificationToggleService {
    func trackNotificationSent(_ type: NotificationType, success: Bool) {
        FeatureToggleAnalyticsService.shared.trackNotificationSent(
            type,
            success: success,
            userId: nil // TODO: Get from user context
        )
    }
    
    func trackPermissionRequested(_ status: UNAuthorizationStatus) {
        FeatureToggleAnalyticsService.shared.trackPermissionRequested(status)
    }
    
    func trackPermissionGranted(_ granted: Bool) {
        FeatureToggleAnalyticsService.shared.trackPermissionGranted(granted)
    }
}

extension ToggleScopeManager {
    func trackTargetingRuleEvaluated(_ ruleType: String, result: Bool) {
        FeatureToggleAnalyticsService.shared.trackTargetingRuleEvaluated(
            ruleType,
            result: result,
            userId: currentUserId
        )
    }
}

extension FeatureToggleService {
    func trackSyncPerformed(_ success: Bool, toggleCount: Int) {
        FeatureToggleAnalyticsService.shared.trackSyncPerformed(success, toggleCount: toggleCount)
    }
}
