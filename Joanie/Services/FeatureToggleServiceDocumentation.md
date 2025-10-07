# Feature Toggle Service Documentation

## Overview

The Feature Toggle Service provides a comprehensive solution for managing feature flags, A/B testing, and user targeting in the Joanie iOS app. It supports multiple scopes (global, user, group, device), secure storage, and real-time updates.

## Architecture

### Core Components

1. **FeatureToggle Protocol** - Defines the contract for all feature toggles
2. **FeatureToggleService** - Manages toggle storage and retrieval
3. **ToggleScopeManager** - Handles targeting and scoping logic
4. **FeatureToggleManager** - Main coordinator and public API
5. **NotificationToggleService** - Notification-specific implementation
6. **SecureStorageManager** - Encrypted storage for sensitive data

### Data Flow

```
FeatureToggleManager
    ↓
FeatureToggleService ← → SecureStorageManager
    ↓
ToggleScopeManager ← → TargetingService
    ↓
NotificationToggleService
```

## API Reference

### FeatureToggleManager

The main entry point for feature toggle functionality.

#### Initialization

```swift
let featureToggleManager = FeatureToggleManager()
```

#### Basic Operations

```swift
// Check if a toggle is enabled
let isEnabled = featureToggleManager.isToggleEnabled(id: "notifications_enabled")

// Set toggle state
await featureToggleManager.setToggleEnabled(id: "notifications_enabled", enabled: true)

// Get a specific toggle
let notificationToggle = featureToggleManager.getToggle(id: "notifications_enabled", as: NotificationToggle.self)

// Sync with remote server
await featureToggleManager.syncToggles()
```

#### User Context Management

```swift
// Update user context for targeting
featureToggleManager.updateUserContext(userId: "user123", groups: ["premium", "beta"])

// Clear user context
featureToggleManager.clearUserContext()

// Update online status
featureToggleManager.updateOnlineStatus(true)
```

#### A/B Testing

```swift
// Check if user should be included in experiment
let shouldInclude = featureToggleManager.shouldIncludeInExperiment(
    experimentId: "notification_timing_test",
    targetingRules: [
        TargetingRule(type: .user, operator: .in, value: "premium", values: ["premium", "beta"])
    ]
)

// Get experiment variant
let variant = featureToggleManager.getExperimentVariant(
    experimentId: "notification_timing_test",
    variants: ["control", "treatment"]
)
```

### FeatureToggle Protocol

Base protocol for all feature toggles.

```swift
protocol FeatureToggle: Identifiable, Codable, Equatable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var isEnabled: Bool { get set }
    var scope: ToggleScope { get }
    var experimentId: String? { get }
    var variant: String? { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var expiresAt: Date? { get }
    var isActive: Bool { get }
    var metadata: [String: Any]? { get }
}
```

### Toggle Scopes

Defines the targeting scope for feature toggles.

```swift
enum ToggleScope: String, Codable, CaseIterable {
    case global = "global"      // Applies to all users
    case user = "user"          // Applies to specific user
    case group = "group"        // Applies to specific group
    case device = "device"      // Applies to specific device
}
```

### NotificationToggle

Specialized toggle for notification features.

```swift
struct NotificationToggle: FeatureToggle {
    let notificationTypes: [NotificationType]
    let quietHours: QuietHours?
    
    // ... other FeatureToggle properties
}
```

## Usage Examples

### Basic Toggle Usage

```swift
// In your ViewModel or Service
class MyViewModel: ObservableObject {
    @Environment(\.featureToggleManager) var featureToggleManager
    
    func performAction() {
        if featureToggleManager.isToggleEnabled(id: "new_feature") {
            // Execute new feature logic
            executeNewFeature()
        } else {
            // Execute legacy logic
            executeLegacyFeature()
        }
    }
}
```

### SwiftUI Integration

```swift
struct MyView: View {
    @Environment(\.featureToggleManager) var featureToggleManager
    
    var body: some View {
        VStack {
            // Show content only if toggle is enabled
            if featureToggleManager.isToggleEnabled(id: "new_ui") {
                NewUIView()
            } else {
                LegacyUIView()
            }
            
            // Alternative using view modifier
            NewUIView()
                .featureToggle("new_ui", fallback: false)
        }
    }
}
```

### A/B Testing Implementation

```swift
class ExperimentService {
    private let featureToggleManager: FeatureToggleManager
    
    func runNotificationExperiment() async {
        let experimentId = "notification_timing_test"
        
        if featureToggleManager.shouldIncludeInExperiment(experimentId: experimentId) {
            let variant = featureToggleManager.getExperimentVariant(
                experimentId: experimentId,
                variants: ["immediate", "delayed", "scheduled"]
            )
            
            switch variant {
            case "immediate":
                await sendImmediateNotification()
            case "delayed":
                await sendDelayedNotification()
            case "scheduled":
                await sendScheduledNotification()
            default:
                await sendDefaultNotification()
            }
            
            // Track experiment participation
            featureToggleManager.trackExperimentParticipation(
                experimentId: experimentId,
                variant: variant
            )
        }
    }
}
```

### Notification Integration

```swift
class NotificationService {
    private let notificationToggleService: NotificationToggleService
    
    func sendArtworkNotification(childName: String, artworkTitle: String) async {
        let success = await notificationToggleService.sendArtworkCompletionNotification(
            childName: childName,
            artworkTitle: artworkTitle
        )
        
        if success {
            print("Notification sent successfully")
        } else {
            print("Notification not sent (toggle disabled or permission denied)")
        }
    }
}
```

## Security Considerations

### Data Encryption

- All sensitive toggle data is encrypted using AES-256
- Encryption keys are stored securely in the iOS Keychain
- User-specific metadata is encrypted before storage

### Access Control

- Toggle access is controlled by scope (global, user, group, device)
- User context is required for user and group scopes
- Device-specific toggles require device ID

### Audit Trail

```swift
// Perform security audit
let auditResult = await secureStorageManager.performSecurityAudit()

if !auditResult.isSecure {
    print("Security issues found:")
    for issue in auditResult.issues {
        print("- \(issue.description) (\(issue.severity))")
    }
}
```

## Testing

### Unit Testing

```swift
class FeatureToggleTests: XCTestCase {
    var featureToggleManager: FeatureToggleManager!
    
    override func setUp() {
        super.setUp()
        featureToggleManager = FeatureToggleManager()
    }
    
    func testToggleEnabled() async {
        // Create test toggle
        let toggle = FeatureToggleFactory.createBaseToggle(
            name: "Test Toggle",
            description: "Test Description",
            isEnabled: true
        )
        
        await featureToggleManager.setToggle(toggle)
        
        // Test toggle state
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
    }
    
    func testABTesting() async {
        let experimentId = "test_experiment"
        
        // Test experiment inclusion
        let shouldInclude = featureToggleManager.shouldIncludeInExperiment(
            experimentId: experimentId
        )
        
        XCTAssertTrue(shouldInclude)
        
        // Test variant assignment
        let variant = featureToggleManager.getExperimentVariant(
            experimentId: experimentId,
            variants: ["control", "treatment"]
        )
        
        XCTAssertTrue(["control", "treatment"].contains(variant))
    }
}
```

### Integration Testing

```swift
class FeatureToggleIntegrationTests: XCTestCase {
    func testNotificationToggleIntegration() async {
        let notificationService = NotificationToggleService()
        
        // Test notification permission
        await notificationService.requestNotificationPermission()
        
        // Test notification sending
        let success = await notificationService.sendNotification(
            title: "Test",
            body: "Test notification"
        )
        
        XCTAssertTrue(success)
    }
}
```

## Performance Considerations

### Optimization Tips

1. **Toggle Checks**: Use `isToggleEnabled()` for fast boolean checks (< 1ms)
2. **Caching**: Toggles are cached in memory for instant access
3. **Background Sync**: Sync operations run in background to avoid UI blocking
4. **Lazy Loading**: Toggles are loaded on-demand to reduce startup time

### Memory Management

- Toggles are stored in memory for fast access
- Automatic cleanup of expired toggles
- Efficient serialization/deserialization

## Troubleshooting

### Common Issues

1. **Toggle Not Working**
   - Check if toggle is active (not expired)
   - Verify user context is set correctly
   - Ensure toggle scope matches current context

2. **Sync Failures**
   - Check network connectivity
   - Verify server endpoint configuration
   - Check for authentication issues

3. **Security Issues**
   - Run security audit: `secureStorageManager.performSecurityAudit()`
   - Check encryption key status
   - Verify keychain access permissions

### Debugging

```swift
// Enable debug logging
Logger.shared.setLevel(.debug)

// Check toggle state
let toggle = featureToggleManager.getToggle(id: "my_toggle", as: BaseFeatureToggle.self)
print("Toggle state: \(toggle?.isEnabled ?? false)")

// Check targeting info
let targetingInfo = featureToggleManager.getTargetingInfo()
print("Targeting info: \(targetingInfo)")
```

## Migration Guide

### From Legacy Feature Flags

1. **Identify existing feature flags**
2. **Create corresponding FeatureToggle instances**
3. **Update code to use FeatureToggleManager**
4. **Test thoroughly in staging environment**
5. **Deploy with gradual rollout**

### Example Migration

```swift
// Old way
if UserDefaults.standard.bool(forKey: "notifications_enabled") {
    sendNotification()
}

// New way
if featureToggleManager.isToggleEnabled(id: "notifications_enabled") {
    await notificationService.sendNotification(...)
}
```

## Best Practices

### Toggle Design

1. **Clear Naming**: Use descriptive, consistent naming conventions
2. **Scope Appropriately**: Choose the right scope for each toggle
3. **Expiration**: Set expiration dates for temporary toggles
4. **Documentation**: Document the purpose and impact of each toggle

### A/B Testing

1. **Statistical Significance**: Ensure adequate sample sizes
2. **Consistent Assignment**: Use deterministic hashing for user assignment
3. **Metrics Tracking**: Track relevant metrics for each variant
4. **Gradual Rollout**: Start with small percentages and increase gradually

### Security

1. **Encrypt Sensitive Data**: Use SecureStorageManager for sensitive toggles
2. **Regular Audits**: Perform security audits regularly
3. **Access Control**: Implement proper access controls
4. **Key Management**: Secure encryption key storage and rotation

## Future Enhancements

### Planned Features

1. **Remote Configuration**: Real-time toggle updates from server
2. **Analytics Integration**: Built-in analytics for toggle usage
3. **Visual Toggle Editor**: UI for managing toggles
4. **Automated Testing**: Integration with testing frameworks
5. **Performance Monitoring**: Toggle performance impact tracking

### Extension Points

The system is designed to be extensible:

- Custom toggle types can be created by implementing `FeatureToggle`
- New targeting rules can be added to `TargetingRuleType`
- Additional storage backends can be integrated
- Custom analytics providers can be plugged in

## Support

For questions or issues with the Feature Toggle Service:

1. Check this documentation
2. Review the code examples
3. Run diagnostic tools (`performSecurityAudit()`, `validateSecurityConfiguration()`)
4. Contact the development team

---

*Last updated: [Current Date]*
*Version: 1.0.0*
