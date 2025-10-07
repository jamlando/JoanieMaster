import Foundation
import Combine

// MARK: - Toggle Scope Manager

/// Manages feature toggle scoping and targeting logic
class ToggleScopeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentUserId: String?
    @Published var currentUserGroups: [String] = []
    @Published var deviceId: String
    @Published var isOnline: Bool = true
    
    // MARK: - Dependencies
    
    private let keychainService: KeychainService
    private let logger: Logger
    
    // MARK: - Configuration
    
    private let deviceIdKey = "device_id"
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainService = KeychainService.shared,
        logger: Logger = Logger.shared
    ) {
        self.keychainService = keychainService
        self.logger = logger
        self.deviceId = Self.generateDeviceId()
        
        loadUserContext()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Checks if a toggle should be active for the current context
    func isToggleActiveForCurrentContext<T: FeatureToggle>(_ toggle: T) -> Bool {
        guard toggle.isActive else { return false }
        
        switch toggle.scope {
        case .global:
            return isGlobalToggleActive(toggle)
        case .user:
            return isUserToggleActive(toggle)
        case .group:
            return isGroupToggleActive(toggle)
        case .device:
            return isDeviceToggleActive(toggle)
        }
    }
    
    /// Gets the effective toggle state for the current context
    func getEffectiveToggleState<T: FeatureToggle>(_ toggle: T) -> Bool {
        return toggle.isEnabled && isToggleActiveForCurrentContext(toggle)
    }
    
    /// Updates the current user context
    func updateUserContext(userId: String?, groups: [String] = []) {
        currentUserId = userId
        currentUserGroups = groups
        
        // Store user ID securely
        if let userId = userId {
            do {
                try keychainService.storeUserID(userId)
            } catch {
                logger.error("Failed to store user ID: \(error.localizedDescription)")
            }
        }
        
        logger.info("User context updated: \(userId ?? "nil"), groups: \(groups)")
    }
    
    /// Clears the current user context
    func clearUserContext() {
        currentUserId = nil
        currentUserGroups = []
        
        do {
            try keychainService.delete(key: "user_id")
        } catch {
            logger.error("Failed to clear user ID: \(error.localizedDescription)")
        }
        
        logger.info("User context cleared")
    }
    
    /// Updates the online/offline status
    func updateOnlineStatus(_ isOnline: Bool) {
        self.isOnline = isOnline
        logger.info("Online status updated: \(isOnline)")
    }
    
    /// Gets targeting information for A/B testing
    func getTargetingInfo() -> TargetingInfo {
        return TargetingInfo(
            userId: currentUserId,
            userGroups: currentUserGroups,
            deviceId: deviceId,
            isOnline: isOnline,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func loadUserContext() {
        // Load user ID from keychain
        do {
            currentUserId = try keychainService.retrieveUserID()
        } catch {
            logger.error("Failed to load user ID: \(error.localizedDescription)")
        }
        
        // Load user groups from UserDefaults (in production, this would come from the server)
        if let groups = UserDefaults.standard.array(forKey: "user_groups") as? [String] {
            currentUserGroups = groups
        }
        
        logger.info("User context loaded: \(currentUserId ?? "nil"), groups: \(currentUserGroups)")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleContextSave()
        }
    }
    
    private func handleContextSave() {
        // Update user groups if they've changed
        if let groups = UserDefaults.standard.array(forKey: "user_groups") as? [String] {
            currentUserGroups = groups
        }
    }
    
    // MARK: - Scope-Specific Logic
    
    private func isGlobalToggleActive<T: FeatureToggle>(_ toggle: T) -> Bool {
        // Global toggles are always active if enabled
        return true
    }
    
    private func isUserToggleActive<T: FeatureToggle>(_ toggle: T) -> Bool {
        // User toggles require a valid user ID
        guard let userId = currentUserId else {
            logger.warning("User toggle \(toggle.id) requires user context")
            return false
        }
        
        // Check if toggle has user-specific metadata
        if let metadata = toggle.metadata,
           let targetUsers = metadata["targetUsers"] as? [String] {
            return targetUsers.contains(userId)
        }
        
        // Default: active for any authenticated user
        return true
    }
    
    private func isGroupToggleActive<T: FeatureToggle>(_ toggle: T) -> Bool {
        // Group toggles require user groups
        guard !currentUserGroups.isEmpty else {
            logger.warning("Group toggle \(toggle.id) requires user groups")
            return false
        }
        
        // Check if toggle has group-specific metadata
        if let metadata = toggle.metadata,
           let targetGroups = metadata["targetGroups"] as? [String] {
            return !Set(currentUserGroups).isDisjoint(with: Set(targetGroups))
        }
        
        // Default: active for any user with groups
        return true
    }
    
    private func isDeviceToggleActive<T: FeatureToggle>(_ toggle: T) -> Bool {
        // Device toggles require device ID
        guard !deviceId.isEmpty else {
            logger.warning("Device toggle \(toggle.id) requires device ID")
            return false
        }
        
        // Check if toggle has device-specific metadata
        if let metadata = toggle.metadata,
           let targetDevices = metadata["targetDevices"] as? [String] {
            return targetDevices.contains(deviceId)
        }
        
        // Default: active for current device
        return true
    }
    
    // MARK: - Device ID Generation
    
    private static func generateDeviceId() -> String {
        // Try to get existing device ID from UserDefaults
        if let existingId = UserDefaults.standard.string(forKey: "device_id") {
            return existingId
        }
        
        // Generate new device ID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "device_id")
        
        return newId
    }
}

// MARK: - Targeting Information

/// Information used for targeting feature toggles
struct TargetingInfo: Codable, Equatable {
    let userId: String?
    let userGroups: [String]
    let deviceId: String
    let isOnline: Bool
    let timestamp: Date
    
    var hasUserContext: Bool {
        return userId != nil
    }
    
    var hasGroupContext: Bool {
        return !userGroups.isEmpty
    }
    
    var contextHash: String {
        let components = [
            userId ?? "nil",
            userGroups.sorted().joined(separator: ","),
            deviceId,
            isOnline ? "online" : "offline"
        ]
        return components.joined(separator: "|")
    }
}

// MARK: - Toggle Targeting Service

/// Service for advanced toggle targeting and A/B testing
class ToggleTargetingService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let scopeManager: ToggleScopeManager
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        scopeManager: ToggleScopeManager,
        logger: Logger = Logger.shared
    ) {
        self.scopeManager = scopeManager
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Determines if a user should be included in an A/B test
    func shouldIncludeInExperiment(
        experimentId: String,
        userId: String?,
        targetingRules: [TargetingRule] = []
    ) -> Bool {
        // Check targeting rules first
        for rule in targetingRules {
            if !evaluateTargetingRule(rule) {
                return false
            }
        }
        
        // Use consistent hashing for A/B test assignment
        let hashInput = "\(experimentId)|\(userId ?? scopeManager.deviceId)"
        let hash = hashInput.hashValue
        
        // Simple 50/50 split (can be made configurable)
        return hash % 2 == 0
    }
    
    /// Gets the variant for a user in an A/B test
    func getExperimentVariant(
        experimentId: String,
        userId: String?,
        variants: [String] = ["control", "treatment"]
    ) -> String {
        let hashInput = "\(experimentId)|\(userId ?? scopeManager.deviceId)"
        let hash = abs(hashInput.hashValue)
        
        return variants[hash % variants.count]
    }
    
    /// Evaluates targeting rules for a toggle
    func evaluateTargetingRules(_ rules: [TargetingRule]) -> Bool {
        for rule in rules {
            if !evaluateTargetingRule(rule) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Private Methods
    
    private func evaluateTargetingRule(_ rule: TargetingRule) -> Bool {
        switch rule.type {
        case .user:
            return evaluateUserRule(rule)
        case .group:
            return evaluateGroupRule(rule)
        case .device:
            return evaluateDeviceRule(rule)
        case .time:
            return evaluateTimeRule(rule)
        case .percentage:
            return evaluatePercentageRule(rule)
        }
    }
    
    private func evaluateUserRule(_ rule: TargetingRule) -> Bool {
        guard let userId = scopeManager.currentUserId else { return false }
        
        switch rule.operator {
        case .equals:
            return rule.value == userId
        case .in:
            return rule.values?.contains(userId) ?? false
        case .notIn:
            return !(rule.values?.contains(userId) ?? true)
        default:
            return false
        }
    }
    
    private func evaluateGroupRule(_ rule: TargetingRule) -> Bool {
        let userGroups = scopeManager.currentUserGroups
        
        switch rule.operator {
        case .equals:
            return userGroups.contains(rule.value)
        case .in:
            return !Set(userGroups).isDisjoint(with: Set(rule.values ?? []))
        case .notIn:
            return Set(userGroups).isDisjoint(with: Set(rule.values ?? []))
        default:
            return false
        }
    }
    
    private func evaluateDeviceRule(_ rule: TargetingRule) -> Bool {
        let deviceId = scopeManager.deviceId
        
        switch rule.operator {
        case .equals:
            return rule.value == deviceId
        case .in:
            return rule.values?.contains(deviceId) ?? false
        case .notIn:
            return !(rule.values?.contains(deviceId) ?? true)
        default:
            return false
        }
    }
    
    private func evaluateTimeRule(_ rule: TargetingRule) -> Bool {
        let now = Date()
        
        switch rule.operator {
        case .after:
            if let afterDate = rule.dateValue {
                return now > afterDate
            }
        case .before:
            if let beforeDate = rule.dateValue {
                return now < beforeDate
            }
        case .between:
            if let startDate = rule.dateValue,
               let endDate = rule.endDateValue {
                return now >= startDate && now <= endDate
            }
        default:
            return false
        }
        
        return false
    }
    
    private func evaluatePercentageRule(_ rule: TargetingRule) -> Bool {
        guard let percentage = rule.percentageValue else { return false }
        
        let hashInput = "\(rule.value)|\(scopeManager.currentUserId ?? scopeManager.deviceId)"
        let hash = abs(hashInput.hashValue)
        
        return (hash % 100) < percentage
    }
}

// MARK: - Targeting Rule

/// Rule for targeting feature toggles to specific users, groups, or conditions
struct TargetingRule: Codable, Equatable {
    let type: TargetingRuleType
    let `operator`: TargetingOperator
    let value: String
    let values: [String]?
    let dateValue: Date?
    let endDateValue: Date?
    let percentageValue: Int?
    
    init(
        type: TargetingRuleType,
        operator: TargetingOperator,
        value: String,
        values: [String]? = nil,
        dateValue: Date? = nil,
        endDateValue: Date? = nil,
        percentageValue: Int? = nil
    ) {
        self.type = type
        self.`operator` = `operator`
        self.value = value
        self.values = values
        self.dateValue = dateValue
        self.endDateValue = endDateValue
        self.percentageValue = percentageValue
    }
}

enum TargetingRuleType: String, Codable, CaseIterable {
    case user = "user"
    case group = "group"
    case device = "device"
    case time = "time"
    case percentage = "percentage"
}

enum TargetingOperator: String, Codable, CaseIterable {
    case equals = "equals"
    case notEquals = "not_equals"
    case `in` = "in"
    case notIn = "not_in"
    case after = "after"
    case before = "before"
    case between = "between"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
}

// MARK: - Extensions

extension FeatureToggle {
    /// Checks if this toggle should be active for the current user context
    @MainActor
    func isActiveForCurrentContext(scopeManager: ToggleScopeManager) -> Bool {
        return scopeManager.isToggleActiveForCurrentContext(self)
    }
    
    /// Gets the effective state for the current user context
    @MainActor
    func getEffectiveState(scopeManager: ToggleScopeManager) -> Bool {
        return scopeManager.getEffectiveToggleState(self)
    }
}
