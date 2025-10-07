import Foundation
import Combine
import SwiftUI

// MARK: - Feature Toggle Manager

/// Main manager that coordinates all feature toggle functionality
class FeatureToggleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var toggles: [String: any FeatureToggle] = [:]
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var currentUserId: String?
    @Published var isOnline: Bool = true
    
    // MARK: - Dependencies
    
    private let featureToggleService: FeatureToggleService
    private let scopeManager: ToggleScopeManager
    private let targetingService: ToggleTargetingService
    private let notificationToggleService: NotificationToggleService
    private let logger: Logger
    
    // MARK: - Combine Publishers
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        featureToggleService: FeatureToggleService,
        scopeManager: ToggleScopeManager,
        targetingService: ToggleTargetingService,
        notificationToggleService: NotificationToggleService,
        logger: Logger = Logger.shared
    ) {
        self.featureToggleService = featureToggleService
        self.scopeManager = scopeManager
        self.targetingService = targetingService
        self.notificationToggleService = notificationToggleService
        self.logger = logger
        
        setupBindings()
        initializeToggles()
    }
    
    // MARK: - Public Methods
    
    /// Checks if a feature toggle is enabled for the current context
    func isToggleEnabled(id: String) -> Bool {
        guard let toggle = toggles[id] else { return false }
        return scopeManager.getEffectiveToggleState(toggle)
    }
    
    /// Gets a feature toggle by ID
    func getToggle<T: FeatureToggle>(id: String, as type: T.Type) -> T? {
        return toggles[id] as? T
    }
    
    /// Sets a feature toggle's enabled state
    func setToggleEnabled(id: String, enabled: Bool) async {
        await featureToggleService.setToggleEnabled(id: id, enabled: enabled)
        await refreshToggles()
    }
    
    /// Adds or updates a feature toggle
    func setToggle<T: FeatureToggle>(_ toggle: T) async {
        do {
            await featureToggleService.setToggle(toggle)
            await refreshToggles()
        } catch {
            // Log to Sentry
            logToggleError(error, toggleId: toggle.id, context: [
                "toggle_name": toggle.name,
                "toggle_scope": toggle.scope.rawValue
            ])
            
            logger.error("Failed to set toggle \(toggle.id): \(error.localizedDescription)")
        }
    }
    
    /// Removes a feature toggle
    func removeToggle(id: String) async {
        await featureToggleService.removeToggle(id: id)
        await refreshToggles()
    }
    
    /// Syncs all toggles with remote server
    func syncToggles() async {
        isLoading = true
        syncError = nil
        
        do {
            await featureToggleService.syncToggles()
            
            // Update local state
            lastSyncDate = featureToggleService.lastSyncDate
            syncError = featureToggleService.syncError
            
            await refreshToggles()
            isLoading = false
        } catch {
            isLoading = false
            syncError = error.localizedDescription
            
            // Log to Sentry
            logSyncError(error, toggleCount: toggles.count, lastSyncDate: lastSyncDate)
            
            logger.error("Failed to sync toggles: \(error.localizedDescription)")
        }
    }
    
    /// Updates user context for targeting
    func updateUserContext(userId: String?, groups: [String] = []) {
        currentUserId = userId
        scopeManager.updateUserContext(userId: userId, groups: groups)
        logger.info("User context updated: \(userId ?? "nil")")
    }
    
    /// Clears user context
    func clearUserContext() {
        currentUserId = nil
        scopeManager.clearUserContext()
        logger.info("User context cleared")
    }
    
    /// Updates online/offline status
    func updateOnlineStatus(_ isOnline: Bool) {
        self.isOnline = isOnline
        scopeManager.updateOnlineStatus(isOnline)
        logger.info("Online status updated: \(isOnline)")
    }
    
    /// Gets targeting information for A/B testing
    func getTargetingInfo() -> TargetingInfo {
        return scopeManager.getTargetingInfo()
    }
    
    /// Determines if a user should be included in an A/B test
    @MainActor
    func shouldIncludeInExperiment(
        experimentId: String,
        targetingRules: [TargetingRule] = []
    ) -> Bool {
        return targetingService.shouldIncludeInExperiment(
            experimentId: experimentId,
            userId: currentUserId,
            targetingRules: targetingRules
        )
    }
    
    /// Gets the variant for a user in an A/B test
    @MainActor
    func getExperimentVariant(
        experimentId: String,
        variants: [String] = ["control", "treatment"]
    ) -> String {
        return targetingService.getExperimentVariant(
            experimentId: experimentId,
            userId: currentUserId,
            variants: variants
        )
    }
    
    /// Creates a notification toggle
    func createNotificationToggle(
        isEnabled: Bool = false,
        scope: ToggleScope = .global,
        experimentId: String? = nil,
        variant: String? = nil
    ) async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: isEnabled,
            scope: scope,
            experimentId: experimentId,
            variant: variant
        )
        
        await setToggle(toggle)
        logger.info("Notification toggle created")
    }
    
    /// Gets the notification toggle service
    func getNotificationToggleService() -> NotificationToggleService {
        return notificationToggleService
    }
    
    /// Refreshes all toggles from storage
    @MainActor
    func refreshToggles() async {
        await featureToggleService.loadTogglesFromStorage()
        toggles = featureToggleService.toggles
        logger.info("Toggles refreshed: \(toggles.count) total")
    }
    
    /// Clears all toggles (for testing)
    func clearAllToggles() async {
        await featureToggleService.clearAllToggles()
        toggles.removeAll()
        logger.info("All toggles cleared")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to feature toggle service changes
        featureToggleService.$toggles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newToggles in
                self?.toggles = newToggles
            }
            .store(in: &cancellables)
        
        featureToggleService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
        
        featureToggleService.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lastSyncDate in
                self?.lastSyncDate = lastSyncDate
            }
            .store(in: &cancellables)
        
        featureToggleService.$syncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncError in
                self?.syncError = syncError
            }
            .store(in: &cancellables)
        
        // Bind to scope manager changes
        scopeManager.$currentUserId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userId in
                self?.currentUserId = userId
            }
            .store(in: &cancellables)
        
        scopeManager.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOnline in
                self?.isOnline = isOnline
            }
            .store(in: &cancellables)
    }
    
    private func initializeToggles() {
        Task {
            await refreshToggles()
            
            // Create default notification toggle if it doesn't exist
            if toggles["notifications_enabled"] == nil {
                await createNotificationToggle()
            }
        }
    }
}

// MARK: - Feature Toggle Environment

/// Environment key for accessing the feature toggle manager
struct FeatureToggleManagerKey: EnvironmentKey {
    static let defaultValue: FeatureToggleManager = {
        let scopeManager = ToggleScopeManager()
        let targetingService = ToggleTargetingService(scopeManager: scopeManager)
        let featureToggleService = FeatureToggleService()
        let notificationToggleService = NotificationToggleService()
        let notificationWrapperService = NotificationWrapperService(notificationToggleService: notificationToggleService)
        
        return FeatureToggleManager(
            featureToggleService: featureToggleService,
            scopeManager: scopeManager,
            targetingService: targetingService,
            notificationToggleService: notificationToggleService
        )
    }()
}

extension EnvironmentValues {
    var featureToggleManager: FeatureToggleManager {
        get { self[FeatureToggleManagerKey.self] }
        set { self[FeatureToggleManagerKey.self] = newValue }
    }
}

// MARK: - Feature Toggle View Modifier

/// View modifier for checking feature toggle state
struct FeatureToggleModifier: ViewModifier {
    let toggleId: String
    let fallback: Bool
    @Environment(\.featureToggleManager) var featureToggleManager
    
    func body(content: Content) -> some View {
        if featureToggleManager.isToggleEnabled(id: toggleId) {
            content
        } else if fallback {
            content
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Shows content only if the specified feature toggle is enabled
    func featureToggle(_ toggleId: String, fallback: Bool = false) -> some View {
        modifier(FeatureToggleModifier(toggleId: toggleId, fallback: fallback))
    }
}

// MARK: - Feature Toggle Property Wrapper

/// Property wrapper for accessing feature toggle state
@propertyWrapper
struct FeatureToggleWrapper {
    let toggleId: String
    let fallback: Bool
    
    @Environment(\.featureToggleManager) var featureToggleManager
    
    var wrappedValue: Bool {
        return featureToggleManager.isToggleEnabled(id: toggleId) || fallback
    }
    
    init(_ toggleId: String, fallback: Bool = false) {
        self.toggleId = toggleId
        self.fallback = fallback
    }
}

// MARK: - Feature Toggle Testing Utilities

extension FeatureToggleManager {
    /// Creates test toggles for development and testing
    func createTestToggles() async {
        let testToggles: [any FeatureToggle] = [
            FeatureToggleFactory.createBaseToggle(
                name: "Test Toggle 1",
                description: "A test toggle for development",
                isEnabled: true,
                scope: .global
            ),
            FeatureToggleFactory.createBaseToggle(
                name: "Test Toggle 2",
                description: "A test toggle for user-specific features",
                isEnabled: false,
                scope: .user
            ),
            FeatureToggleFactory.createBaseToggle(
                name: "Test Toggle 3",
                description: "A test toggle for group-specific features",
                isEnabled: true,
                scope: .group
            ),
            FeatureToggleFactory.createNotificationToggle(
                isEnabled: true,
                scope: .global
            )
        ]
        
        for toggle in testToggles {
            await setToggle(toggle)
        }
        
        logger.info("Test toggles created")
    }
    
    /// Simulates A/B test scenario
    @MainActor
    func simulateABTest() async {
        let experimentId = "notification_timing_test"
        let shouldInclude = shouldIncludeInExperiment(experimentId: experimentId)
        
        if shouldInclude {
            let variant = getExperimentVariant(
                experimentId: experimentId,
                variants: ["immediate", "delayed"]
            )
            
            logger.info("User included in A/B test: \(experimentId), variant: \(variant)")
            
            // Apply variant-specific logic
            switch variant {
            case "immediate":
                await setToggleEnabled(id: "notifications_enabled", enabled: true)
            case "delayed":
                // Delayed notification logic would go here
                break
            default:
                break
            }
        } else {
            logger.info("User not included in A/B test: \(experimentId)")
        }
    }
    
    // MARK: - Error Logging
    
    private func logToggleError(_ error: Error, toggleId: String, context: [String: Any] = [:]) {
        logger.error("Toggle error for \(toggleId): \(error.localizedDescription)")
        // TODO: Integrate with Sentry or other error tracking service
    }
    
    private func logSyncError(_ error: Error, toggleCount: Int, lastSyncDate: Date?) {
        logger.error("Sync error: \(error.localizedDescription), toggleCount: \(toggleCount), lastSync: \(lastSyncDate?.description ?? "nil")")
        // TODO: Integrate with Sentry or other error tracking service
    }
}

