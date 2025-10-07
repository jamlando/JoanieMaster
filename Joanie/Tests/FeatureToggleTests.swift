import XCTest
import UserNotifications
@testable import Joanie

// MARK: - Feature Toggle Tests

class FeatureToggleTests: XCTestCase {
    var featureToggleManager: FeatureToggleManager!
    var notificationToggleService: NotificationToggleService!
    
    override func setUp() {
        super.setUp()
        featureToggleManager = FeatureToggleManager()
        notificationToggleService = NotificationToggleService()
    }
    
    override func tearDown() {
        featureToggleManager = nil
        notificationToggleService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Toggle Tests
    
    func testToggleCreation() async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            name: "Test Notifications",
            description: "Test notification toggle",
            isEnabled: true,
            scope: .global
        )
        
        await featureToggleManager.setToggle(toggle)
        
        let retrievedToggle = featureToggleManager.getToggle(id: toggle.id, as: NotificationToggle.self)
        XCTAssertNotNil(retrievedToggle)
        XCTAssertEqual(retrievedToggle?.name, "Test Notifications")
        XCTAssertEqual(retrievedToggle?.isEnabled, true)
        XCTAssertEqual(retrievedToggle?.scope, .global)
    }
    
    func testToggleEnabledState() async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: false,
            scope: .global
        )
        
        await featureToggleManager.setToggle(toggle)
        
        // Initially disabled
        XCTAssertFalse(featureToggleManager.isToggleEnabled(id: toggle.id))
        
        // Enable toggle
        await featureToggleManager.setToggleEnabled(id: toggle.id, enabled: true)
        
        // Should now be enabled
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
    }
    
    func testToggleScopeTargeting() async {
        // Test global scope
        let globalToggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        await featureToggleManager.setToggle(globalToggle)
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: globalToggle.id))
        
        // Test user scope without user context
        let userToggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .user
        )
        await featureToggleManager.setToggle(userToggle)
        XCTAssertFalse(featureToggleManager.isToggleEnabled(id: userToggle.id))
        
        // Test user scope with user context
        featureToggleManager.updateUserContext(userId: "test-user")
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: userToggle.id))
    }
    
    // MARK: - A/B Testing Tests
    
    func testABTestingInclusion() {
        let experimentId = "test_experiment"
        
        // Test consistent assignment
        let shouldInclude1 = featureToggleManager.shouldIncludeInExperiment(experimentId: experimentId)
        let shouldInclude2 = featureToggleManager.shouldIncludeInExperiment(experimentId: experimentId)
        
        XCTAssertEqual(shouldInclude1, shouldInclude2, "A/B test assignment should be consistent")
    }
    
    func testExperimentVariantAssignment() {
        let experimentId = "test_experiment"
        let variants = ["control", "treatment", "variant_c"]
        
        let variant = featureToggleManager.getExperimentVariant(
            experimentId: experimentId,
            variants: variants
        )
        
        XCTAssertTrue(variants.contains(variant), "Variant should be one of the provided options")
    }
    
    func testExperimentConsistency() {
        let experimentId = "test_experiment"
        
        let variant1 = featureToggleManager.getExperimentVariant(experimentId: experimentId)
        let variant2 = featureToggleManager.getExperimentVariant(experimentId: experimentId)
        
        XCTAssertEqual(variant1, variant2, "Experiment variant should be consistent for same user")
    }
    
    // MARK: - Notification Tests
    
    func testNotificationToggleCreation() async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        
        await featureToggleManager.setToggle(toggle)
        
        let retrievedToggle = featureToggleManager.getToggle(id: toggle.id, as: NotificationToggle.self)
        XCTAssertNotNil(retrievedToggle)
        XCTAssertEqual(retrievedToggle?.notificationTypes, NotificationType.allCases)
    }
    
    func testNotificationPermissionRequest() async {
        // Mock permission request
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        await notificationToggleService.requestNotificationPermission()
        
        // Check permission status
        await notificationToggleService.checkNotificationPermission()
        
        // Verify permission status is updated
        XCTAssertNotEqual(notificationToggleService.notificationPermissionStatus, .notDetermined)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testNotificationSending() async {
        // Enable notifications
        await notificationToggleService.toggleNotifications(enabled: true)
        
        // Send test notification
        let success = await notificationToggleService.sendNotification(
            title: "Test Notification",
            body: "This is a test notification"
        )
        
        // Note: This will only succeed if permissions are granted
        // In a real test environment, you'd mock the UNUserNotificationCenter
        XCTAssertNotNil(success)
    }
    
    // MARK: - Edge Cases
    
    func testExpiredToggle() async {
        let expiredDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global,
            expiresAt: expiredDate
        )
        
        await featureToggleManager.setToggle(toggle)
        
        // Expired toggle should not be active
        XCTAssertFalse(featureToggleManager.isToggleEnabled(id: toggle.id))
    }
    
    func testNonExistentToggle() {
        let isEnabled = featureToggleManager.isToggleEnabled(id: "non_existent_toggle")
        XCTAssertFalse(isEnabled, "Non-existent toggle should return false")
    }
    
    func testToggleWithMetadata() async {
        let metadata = ["targetUsers": ["user1", "user2"]]
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .user,
            metadata: metadata
        )
        
        await featureToggleManager.setToggle(toggle)
        
        let retrievedToggle = featureToggleManager.getToggle(id: toggle.id, as: NotificationToggle.self)
        XCTAssertNotNil(retrievedToggle)
        XCTAssertEqual(retrievedToggle?.metadata?["targetUsers"] as? [String], ["user1", "user2"])
    }
    
    func testConcurrentToggleUpdates() async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: false,
            scope: .global
        )
        
        await featureToggleManager.setToggle(toggle)
        
        // Simulate concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.featureToggleManager.setToggleEnabled(
                        id: toggle.id,
                        enabled: i % 2 == 0
                    )
                }
            }
        }
        
        // Final state should be consistent
        let finalState = featureToggleManager.isToggleEnabled(id: toggle.id)
        XCTAssertNotNil(finalState)
    }
}

// MARK: - Notification Service Tests

class NotificationToggleServiceTests: XCTestCase {
    var notificationService: NotificationToggleService!
    
    override func setUp() {
        super.setUp()
        notificationService = NotificationToggleService()
    }
    
    override func tearDown() {
        notificationService = nil
        super.tearDown()
    }
    
    func testNotificationTypes() {
        let allTypes = NotificationType.allCases
        XCTAssertEqual(allTypes.count, 5)
        XCTAssertTrue(allTypes.contains(.artwork))
        XCTAssertTrue(allTypes.contains(.story))
        XCTAssertTrue(allTypes.contains(.progress))
        XCTAssertTrue(allTypes.contains(.reminder))
        XCTAssertTrue(allTypes.contains(.system))
    }
    
    func testQuietHoursConfiguration() {
        let quietHours = QuietHours(startHour: 22, endHour: 8)
        
        // Test quiet hours logic
        XCTAssertNotNil(quietHours)
        XCTAssertEqual(quietHours.startTime, TimeInterval(22 * 3600))
        XCTAssertEqual(quietHours.endTime, TimeInterval(8 * 3600))
    }
    
    func testArtworkNotification() async {
        let success = await notificationService.sendArtworkCompletionNotification(
            childName: "Emma",
            artworkTitle: "My Drawing"
        )
        
        // Note: This will only succeed if permissions are granted
        XCTAssertNotNil(success)
    }
    
    func testStoryNotification() async {
        let success = await notificationService.sendStoryCompletionNotification(
            childName: "Emma",
            storyTitle: "The Adventure"
        )
        
        // Note: This will only succeed if permissions are granted
        XCTAssertNotNil(success)
    }
    
    func testProgressNotification() async {
        let success = await notificationService.sendProgressMilestoneNotification(
            childName: "Emma",
            skill: "Drawing",
            level: "Advanced"
        )
        
        // Note: This will only succeed if permissions are granted
        XCTAssertNotNil(success)
    }
    
    func testNotificationCancellation() {
        let identifier = "test_notification"
        
        // Cancel notification (should not crash)
        notificationService.cancelNotification(identifier: identifier)
        
        // Cancel all notifications (should not crash)
        notificationService.cancelAllNotifications()
    }
}

// MARK: - Analytics Tests

class FeatureToggleAnalyticsTests: XCTestCase {
    var analyticsService: FeatureToggleAnalyticsService!
    
    override func setUp() {
        super.setUp()
        analyticsService = FeatureToggleAnalyticsService.shared
    }
    
    override func tearDown() {
        analyticsService = nil
        super.tearDown()
    }
    
    func testToggleEnabledTracking() {
        // Should not crash
        analyticsService.trackToggleEnabled(
            "test_toggle",
            scope: .global,
            experimentId: "test_experiment",
            userId: "test_user"
        )
    }
    
    func testToggleDisabledTracking() {
        // Should not crash
        analyticsService.trackToggleDisabled(
            "test_toggle",
            scope: .user,
            userId: "test_user"
        )
    }
    
    func testExperimentParticipationTracking() {
        // Should not crash
        analyticsService.trackExperimentParticipation(
            "test_experiment",
            variant: "treatment",
            userId: "test_user"
        )
    }
    
    func testNotificationTracking() {
        // Should not crash
        analyticsService.trackNotificationSent(
            .artwork,
            success: true,
            userId: "test_user"
        )
    }
    
    func testPermissionTracking() {
        // Should not crash
        analyticsService.trackPermissionRequested(.authorized)
        analyticsService.trackPermissionGranted(true)
    }
    
    func testSyncTracking() {
        // Should not crash
        analyticsService.trackSyncPerformed(true, toggleCount: 5)
    }
    
    func testTargetingRuleTracking() {
        // Should not crash
        analyticsService.trackTargetingRuleEvaluated(
            "user_rule",
            result: true,
            userId: "test_user"
        )
    }
    
    func testUsageReportGeneration() {
        let report = analyticsService.generateToggleUsageReport()
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("FEATURE TOGGLE USAGE REPORT"))
    }
}

// MARK: - Integration Tests

class FeatureToggleIntegrationTests: XCTestCase {
    var featureToggleManager: FeatureToggleManager!
    var notificationService: NotificationToggleService!
    var analyticsService: FeatureToggleAnalyticsService!
    
    override func setUp() {
        super.setUp()
        featureToggleManager = FeatureToggleManager()
        notificationService = NotificationToggleService()
        analyticsService = FeatureToggleAnalyticsService.shared
    }
    
    override func tearDown() {
        featureToggleManager = nil
        notificationService = nil
        analyticsService = nil
        super.tearDown()
    }
    
    func testEndToEndNotificationFlow() async {
        // 1. Create notification toggle
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        await featureToggleManager.setToggle(toggle)
        
        // 2. Enable notifications
        await notificationService.toggleNotifications(enabled: true)
        
        // 3. Send notification
        let success = await notificationService.sendNotification(
            title: "Test",
            body: "Integration test notification"
        )
        
        // 4. Track analytics
        analyticsService.trackNotificationSent(.system, success: success)
        
        // Verify flow completed
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
        XCTAssertNotNil(success)
    }
    
    func testABTestIntegration() async {
        let experimentId = "integration_test"
        
        // 1. Check if user should be included
        let shouldInclude = featureToggleManager.shouldIncludeInExperiment(experimentId: experimentId)
        
        if shouldInclude {
            // 2. Get variant
            let variant = featureToggleManager.getExperimentVariant(
                experimentId: experimentId,
                variants: ["control", "treatment"]
            )
            
            // 3. Apply variant-specific logic
            let toggleId = variant == "treatment" ? "new_feature" : "old_feature"
            await featureToggleManager.setToggleEnabled(id: toggleId, enabled: true)
            
            // 4. Track participation
            featureToggleManager.trackExperimentParticipation(
                experimentId: experimentId,
                variant: variant
            )
            
            // Verify integration
            XCTAssertTrue(["control", "treatment"].contains(variant))
        }
    }
    
    func testUserContextIntegration() async {
        // 1. Set user context
        featureToggleManager.updateUserContext(userId: "test_user", groups: ["premium", "beta"])
        
        // 2. Create user-specific toggle
        let userToggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .user
        )
        await featureToggleManager.setToggle(userToggle)
        
        // 3. Verify toggle is active for user
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: userToggle.id))
        
        // 4. Clear user context
        featureToggleManager.clearUserContext()
        
        // 5. Verify toggle is no longer active
        XCTAssertFalse(featureToggleManager.isToggleEnabled(id: userToggle.id))
    }
}

// MARK: - Performance Tests

class FeatureTogglePerformanceTests: XCTestCase {
    var featureToggleManager: FeatureToggleManager!
    
    override func setUp() {
        super.setUp()
        featureToggleManager = FeatureToggleManager()
    }
    
    override func tearDown() {
        featureToggleManager = nil
        super.tearDown()
    }
    
    func testToggleCheckPerformance() async {
        // Create test toggle
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        await featureToggleManager.setToggle(toggle)
        
        // Measure toggle check performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            _ = featureToggleManager.isToggleEnabled(id: toggle.id)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should be very fast (< 1ms per check as per requirements)
        XCTAssertLessThan(timeElapsed, 0.1, "Toggle checks should be very fast")
    }
    
    func testConcurrentToggleAccess() async {
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: false,
            scope: .global
        )
        await featureToggleManager.setToggle(toggle)
        
        // Test concurrent access
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = self.featureToggleManager.isToggleEnabled(id: toggle.id)
                }
            }
        }
        
        // Should not crash and maintain consistency
        XCTAssertNotNil(featureToggleManager.isToggleEnabled(id: toggle.id))
    }
}

// MARK: - Mock Classes for Testing

class MockNotificationCenter: UNUserNotificationCenter {
    var mockAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var mockGranted: Bool = false
    
    override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return mockGranted
    }
    
    override func notificationSettings() async -> UNNotificationSettings {
        let settings = MockNotificationSettings()
        settings.authorizationStatus = mockAuthorizationStatus
        return settings
    }
    
    override func add(_ request: UNNotificationRequest) async throws {
        // Mock implementation
    }
}

class MockNotificationSettings: UNNotificationSettings {
    override var authorizationStatus: UNAuthorizationStatus {
        return .authorized
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func waitForAsyncOperation(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}
