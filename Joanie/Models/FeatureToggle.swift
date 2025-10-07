import Foundation
import Combine

// MARK: - Feature Toggle Protocol

/// Protocol defining the contract for feature toggles with A/B testing support
protocol FeatureToggle: Identifiable {
    /// Unique identifier for the toggle
    var id: String { get }
    
    /// Human-readable name of the feature toggle
    var name: String { get }
    
    /// Description of what this toggle controls
    var description: String { get }
    
    /// Current state of the toggle (enabled/disabled)
    var isEnabled: Bool { get set }
    
    /// Scope of the toggle (global, user, group, device)
    var scope: ToggleScope { get }
    
    /// Optional experiment ID for A/B testing
    var experimentId: String? { get }
    
    /// Optional variant for A/B testing (e.g., "control", "treatment")
    var variant: String? { get }
    
    /// Timestamp when the toggle was created
    var createdAt: Date { get }
    
    /// Timestamp when the toggle was last updated
    var updatedAt: Date { get set }
    
    /// Optional expiration date for the toggle
    var expiresAt: Date? { get }
    
    /// Whether the toggle is currently active (not expired)
    var isActive: Bool { get }
    
    /// Metadata for additional configuration
    var metadata: [String: String]? { get }
}

// MARK: - Toggle Scope

/// Defines the scope/audience for a feature toggle
enum ToggleScope: String, Codable, CaseIterable {
    case global = "global"
    case user = "user"
    case group = "group"
    case device = "device"
    
    var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .user:
            return "User-specific"
        case .group:
            return "Group-specific"
        case .device:
            return "Device-specific"
        }
    }
    
    var description: String {
        switch self {
        case .global:
            return "Applies to all users"
        case .user:
            return "Applies to specific user"
        case .group:
            return "Applies to specific group of users"
        case .device:
            return "Applies to specific device"
        }
    }
}

// MARK: - Feature Toggle Types

/// Base implementation of FeatureToggle protocol
struct BaseFeatureToggle: FeatureToggle, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    var isEnabled: Bool
    let scope: ToggleScope
    let experimentId: String?
    let variant: String?
    let createdAt: Date
    var updatedAt: Date
    let expiresAt: Date?
    let metadata: [String: String]?
    
    var isActive: Bool {
        guard let expiresAt = expiresAt else { return true }
        return Date() < expiresAt
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        isEnabled: Bool = false,
        scope: ToggleScope = .global,
        experimentId: String? = nil,
        variant: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.scope = scope
        self.experimentId = experimentId
        self.variant = variant
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, isEnabled, scope
        case experimentId, variant, createdAt, updatedAt, expiresAt
        case metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        scope = try container.decode(ToggleScope.self, forKey: .scope)
        experimentId = try container.decodeIfPresent(String.self, forKey: .experimentId)
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        
        // Handle metadata decoding
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(scope, forKey: .scope)
        try container.encodeIfPresent(experimentId, forKey: .experimentId)
        try container.encodeIfPresent(variant, forKey: .variant)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        
        // Handle metadata encoding
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: BaseFeatureToggle, rhs: BaseFeatureToggle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.scope == rhs.scope &&
               lhs.experimentId == rhs.experimentId &&
               lhs.variant == rhs.variant &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.expiresAt == rhs.expiresAt &&
               lhs.metadata == rhs.metadata
    }
}

// MARK: - Specific Toggle Types

/// Notification toggle implementation
struct NotificationToggle: FeatureToggle, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    var isEnabled: Bool
    let scope: ToggleScope
    let experimentId: String?
    let variant: String?
    let createdAt: Date
    var updatedAt: Date
    let expiresAt: Date?
    let metadata: [String: String]?
    
    var isActive: Bool {
        guard let expiresAt = expiresAt else { return true }
        return Date() < expiresAt
    }
    
    /// Notification-specific configuration
    let notificationTypes: [NotificationType]
    let quietHours: QuietHours?
    
    init(
        id: String = UUID().uuidString,
        name: String = "Notifications",
        description: String = "Controls whether the app can send push notifications",
        isEnabled: Bool = false,
        scope: ToggleScope = .global,
        experimentId: String? = nil,
        variant: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: [String: String]? = nil,
        notificationTypes: [NotificationType] = NotificationType.allCases,
        quietHours: QuietHours? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.scope = scope
        self.experimentId = experimentId
        self.variant = variant
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
        self.notificationTypes = notificationTypes
        self.quietHours = quietHours
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, isEnabled, scope
        case experimentId, variant, createdAt, updatedAt, expiresAt
        case metadata, notificationTypes, quietHours
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        scope = try container.decode(ToggleScope.self, forKey: .scope)
        experimentId = try container.decodeIfPresent(String.self, forKey: .experimentId)
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        notificationTypes = try container.decode([NotificationType].self, forKey: .notificationTypes)
        quietHours = try container.decodeIfPresent(QuietHours.self, forKey: .quietHours)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(scope, forKey: .scope)
        try container.encodeIfPresent(experimentId, forKey: .experimentId)
        try container.encodeIfPresent(variant, forKey: .variant)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(notificationTypes, forKey: .notificationTypes)
        try container.encodeIfPresent(quietHours, forKey: .quietHours)
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: NotificationToggle, rhs: NotificationToggle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.scope == rhs.scope &&
               lhs.experimentId == rhs.experimentId &&
               lhs.variant == rhs.variant &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.expiresAt == rhs.expiresAt &&
               lhs.metadata == rhs.metadata &&
               lhs.notificationTypes == rhs.notificationTypes &&
               lhs.quietHours == rhs.quietHours
    }
}

// MARK: - Supporting Types

/// Types of notifications that can be controlled
enum NotificationType: String, Codable, CaseIterable {
    case artwork = "artwork"
    case story = "story"
    case progress = "progress"
    case reminder = "reminder"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .artwork:
            return "Artwork Updates"
        case .story:
            return "Story Updates"
        case .progress:
            return "Progress Updates"
        case .reminder:
            return "Reminders"
        case .system:
            return "System Notifications"
        }
    }
}

/// Quiet hours configuration for notifications
struct QuietHours: Codable, Equatable {
    let startTime: TimeInterval // Seconds from midnight
    let endTime: TimeInterval   // Seconds from midnight
    let timezone: String
    
    init(startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0, timezone: String = "UTC") {
        self.startTime = TimeInterval(startHour * 3600 + startMinute * 60)
        self.endTime = TimeInterval(endHour * 3600 + endMinute * 60)
        self.timezone = timezone
    }
    
    var isQuietTime: Bool {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = TimeInterval(hour * 3600 + minute * 60)
        
        if startTime < endTime {
            return currentTime >= startTime && currentTime < endTime
        } else {
            // Quiet hours span midnight
            return currentTime >= startTime || currentTime < endTime
        }
    }
}

// MARK: - Feature Toggle Extensions

extension FeatureToggle {
    /// Creates a copy of the toggle with updated enabled state
    func withEnabled(_ enabled: Bool) -> Self {
        var copy = self
        copy.isEnabled = enabled
        return copy
    }
    
    /// Creates a copy of the toggle with updated timestamp
    func withUpdatedTimestamp() -> Self {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }
    
    /// Checks if the toggle should be active for a specific user
    func isActiveForUser(userId: String?) -> Bool {
        guard isActive else { return false }
        
        switch scope {
        case .global:
            return true
        case .user:
            return userId != nil
        case .group, .device:
            // These would require additional logic based on user groups or device IDs
            return true
        }
    }
}

// MARK: - Feature Toggle Factory

/// Factory for creating different types of feature toggles
struct FeatureToggleFactory {
    static func createNotificationToggle(
        isEnabled: Bool = false,
        scope: ToggleScope = .global,
        experimentId: String? = nil,
        variant: String? = nil
    ) -> NotificationToggle {
        return NotificationToggle(
            isEnabled: isEnabled,
            scope: scope,
            experimentId: experimentId,
            variant: variant
        )
    }
    
    static func createBaseToggle(
        name: String,
        description: String,
        isEnabled: Bool = false,
        scope: ToggleScope = .global,
        experimentId: String? = nil,
        variant: String? = nil
    ) -> BaseFeatureToggle {
        return BaseFeatureToggle(
            name: name,
            description: description,
            isEnabled: isEnabled,
            scope: scope,
            experimentId: experimentId,
            variant: variant
        )
    }
}
