import Foundation
import UserNotifications
import Combine
import UIKit

// MARK: - Notification Toggle Service

/// Service that manages notification permissions and respects feature toggle state
class NotificationToggleService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isNotificationEnabled: Bool = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var isToggleActive: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let featureToggleService: FeatureToggleService
    private let scopeManager: ToggleScopeManager
    private let logger: Logger
    
    // MARK: - Configuration
    
    private let notificationToggleId = "notifications_enabled"
    
    // MARK: - Initialization
    
    init(
        featureToggleService: FeatureToggleService = FeatureToggleService(),
        scopeManager: ToggleScopeManager = ToggleScopeManager(),
        logger: Logger = Logger.shared
    ) {
        self.featureToggleService = featureToggleService
        self.scopeManager = scopeManager
        self.logger = logger
        
        setupInitialState()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Requests notification permission from the user
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                self.isNotificationEnabled = granted
                self.updateNotificationPermissionStatus()
            }
            
            if granted {
                logger.info("Notification permission granted")
                await registerForRemoteNotifications()
            } else {
                logger.info("Notification permission denied")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
        }
    }
    
    /// Checks current notification permission status
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        await MainActor.run {
            self.notificationPermissionStatus = settings.authorizationStatus
            self.isNotificationEnabled = settings.authorizationStatus == .authorized
            self.updateNotificationPermissionStatus()
        }
        
        logger.info("Notification permission status: \(settings.authorizationStatus.rawValue)")
    }
    
    /// Toggles the notification feature on/off
    func toggleNotifications(enabled: Bool) async {
        do {
            // Update the feature toggle
            await featureToggleService.setToggleEnabled(id: notificationToggleId, enabled: enabled)
            
            // Update local state
            isToggleActive = enabled
            
            // If enabling, request permission if not already granted
            if enabled && notificationPermissionStatus != .authorized {
                await requestNotificationPermission()
            }
            
            logger.info("Notification toggle set to: \(enabled)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            logger.error("Failed to toggle notifications: \(error.localizedDescription)")
        }
    }
    
    /// Sends a notification if permissions are granted and toggle is active
    func sendNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger? = nil
    ) async -> Bool {
        // Check if notifications are enabled and toggle is active
        guard isNotificationEnabled && isToggleActive else {
            logger.warning("Notifications disabled or toggle inactive - not sending notification")
            return false
        }
        
        // Check permission status
        guard notificationPermissionStatus == .authorized else {
            logger.warning("Notification permission not granted - not sending notification")
            return false
        }
        
        do {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.userInfo = userInfo
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Notification sent: \(title)")
            return true
            
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Schedules a local notification
    func scheduleNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString,
        userInfo: [String: Any] = [:]
    ) async -> Bool {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        return await sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            userInfo: userInfo,
            trigger: trigger
        )
    }
    
    /// Cancels a scheduled notification
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("Cancelled notification: \(identifier)")
    }
    
    /// Cancels all pending notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        logger.info("Cancelled all pending notifications")
    }
    
    /// Gets the current effective notification state
    func getEffectiveNotificationState() -> Bool {
        return isNotificationEnabled && isToggleActive
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        // Load initial toggle state
        Task {
            await loadToggleState()
            await checkNotificationPermission()
        }
    }
    
    private func setupNotifications() {
        // Listen for toggle changes
        NotificationCenter.default.addObserver(
            forName: .featureToggleChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let toggleId = notification.userInfo?["toggleId"] as? String,
               toggleId == self?.notificationToggleId {
                Task {
                    await self?.loadToggleState()
                }
            }
        }
        
        // Listen for app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.checkNotificationPermission()
            }
        }
    }
    
    private func loadToggleState() async {
        let isEnabled = await featureToggleService.isToggleEnabled(id: notificationToggleId)
        
        await MainActor.run {
            self.isToggleActive = isEnabled
        }
        
        logger.info("Notification toggle state loaded: \(isEnabled)")
    }
    
    private func updateNotificationPermissionStatus() {
        // This method can be used to update UI or trigger other actions
        // when permission status changes
    }
    
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
        logger.info("Registered for remote notifications")
    }
}

// MARK: - Notification Wrapper Service

/// Wrapper service that respects notification toggle state for all notification operations
class NotificationWrapperService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let notificationToggleService: NotificationToggleService
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        notificationToggleService: NotificationToggleService,
        logger: Logger = Logger.shared
    ) {
        self.notificationToggleService = notificationToggleService
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Sends a notification respecting the toggle state
    func sendNotification(
        title: String,
        body: String,
        identifier: String = UUID().uuidString,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger? = nil
    ) async -> Bool {
        return await notificationToggleService.sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            userInfo: userInfo,
            trigger: trigger
        )
    }
    
    /// Schedules a notification respecting the toggle state
    func scheduleNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString,
        userInfo: [String: Any] = [:]
    ) async -> Bool {
        return await notificationToggleService.scheduleNotification(
            title: title,
            body: body,
            timeInterval: timeInterval,
            identifier: identifier,
            userInfo: userInfo
        )
    }
    
    /// Sends artwork completion notification
    func sendArtworkCompletionNotification(
        childName: String,
        artworkTitle: String,
        identifier: String = UUID().uuidString
    ) async -> Bool {
        let title = "🎨 New Artwork!"
        let body = "\(childName) just created '\(artworkTitle)'"
        
        return await sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            userInfo: [
                "type": "artwork_completion",
                "childName": childName,
                "artworkTitle": artworkTitle
            ]
        )
    }
    
    /// Sends story completion notification
    func sendStoryCompletionNotification(
        childName: String,
        storyTitle: String,
        identifier: String = UUID().uuidString
    ) async -> Bool {
        let title = "📚 Story Complete!"
        let body = "\(childName) finished '\(storyTitle)'"
        
        return await sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            userInfo: [
                "type": "story_completion",
                "childName": childName,
                "storyTitle": storyTitle
            ]
        )
    }
    
    /// Sends progress milestone notification
    func sendProgressMilestoneNotification(
        childName: String,
        skill: String,
        level: String,
        identifier: String = UUID().uuidString
    ) async -> Bool {
        let title = "🌟 Milestone Reached!"
        let body = "\(childName) reached \(level) in \(skill)"
        
        return await sendNotification(
            title: title,
            body: body,
            identifier: identifier,
            userInfo: [
                "type": "progress_milestone",
                "childName": childName,
                "skill": skill,
                "level": level
            ]
        )
    }
    
    /// Sends reminder notification
    func sendReminderNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString
    ) async -> Bool {
        return await scheduleNotification(
            title: title,
            body: body,
            timeInterval: timeInterval,
            identifier: identifier,
            userInfo: [
                "type": "reminder"
            ]
        )
    }
    
    /// Cancels a notification
    func cancelNotification(identifier: String) {
        notificationToggleService.cancelNotification(identifier: identifier)
    }
    
    /// Cancels all notifications
    func cancelAllNotifications() {
        notificationToggleService.cancelAllNotifications()
    }
    
    /// Gets the current notification state
    func isNotificationEnabled() -> Bool {
        return notificationToggleService.getEffectiveNotificationState()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let featureToggleChanged = Notification.Name("featureToggleChanged")
}

// MARK: - Notification Categories

extension NotificationToggleService {
    /// Sets up notification categories for interactive notifications
    func setupNotificationCategories() {
        let artworkCategory = UNNotificationCategory(
            identifier: "artwork_category",
            actions: [
                UNNotificationAction(
                    identifier: "view_artwork",
                    title: "View Artwork",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "share_artwork",
                    title: "Share",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let storyCategory = UNNotificationCategory(
            identifier: "story_category",
            actions: [
                UNNotificationAction(
                    identifier: "read_story",
                    title: "Read Story",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "share_story",
                    title: "Share",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            artworkCategory,
            storyCategory
        ])
        
        logger.info("Notification categories set up")
    }
}
