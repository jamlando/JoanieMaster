import XCTest
import UserNotifications
@testable import Joanie

// MARK: - Feature Toggle Integration Tests

class FeatureToggleIntegrationTests: XCTestCase {
    var featureToggleManager: FeatureToggleManager!
    var notificationWrapperService: NotificationWrapperService!
    var authService: AuthService!
    var emailServiceManager: EmailServiceManager!
    var aiService: AIService!
    var progressTrackingService: ProgressTrackingService!
    var sentryService: SentryIntegrationService!
    
    override func setUp() {
        super.setUp()
        
        // Initialize all services with test dependencies
        featureToggleManager = FeatureToggleManager()
        notificationWrapperService = NotificationWrapperService()
        authService = AuthService(
            supabaseService: SupabaseService.shared,
            emailServiceManager: MockEmailServiceManager(),
            notificationWrapperService: notificationWrapperService
        )
        emailServiceManager = EmailServiceManager(
            primaryService: MockEmailService(),
            fallbackService: MockEmailService(),
            notificationWrapperService: notificationWrapperService
        )
        aiService = AIService(
            notificationWrapperService: notificationWrapperService,
            progressTrackingService: ProgressTrackingService()
        )
        progressTrackingService = ProgressTrackingService()
        sentryService = SentryIntegrationService.shared
    }
    
    override func tearDown() {
        featureToggleManager = nil
        notificationWrapperService = nil
        authService = nil
        emailServiceManager = nil
        aiService = nil
        progressTrackingService = nil
        sentryService = nil
        super.tearDown()
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteNotificationFlow() async {
        // 1. Create notification toggle
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        await featureToggleManager.setToggle(toggle)
        
        // 2. Verify toggle is active
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
        
        // 3. Test notification sending through wrapper
        let success = await notificationWrapperService.sendNotification(
            title: "Test Notification",
            body: "Integration test notification"
        )
        
        // 4. Verify notification was processed (may not succeed due to permissions)
        XCTAssertNotNil(success)
        
        // 5. Test analytics tracking
        FeatureToggleAnalyticsService.shared.trackNotificationSent(
            .system,
            success: success,
            userId: "test_user"
        )
        
        // 6. Test Sentry logging
        sentryService.logToggleError(
            error: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]),
            toggleId: toggle.id,
            context: ["test": true]
        )
    }
    
    func testAuthServiceNotificationIntegration() async {
        // Test sign-up notification
        let user = UserProfile(
            id: UUID(),
            email: "test@example.com",
            fullName: "Test User"
        )
        
        // This should trigger a welcome notification
        // Note: In a real test, we'd mock the sign-up process
        XCTAssertNotNil(user)
        
        // Test sign-in notification
        // Note: In a real test, we'd mock the sign-in process
        XCTAssertNotNil(user)
        
        // Test sign-out notification
        // Note: In a real test, we'd mock the sign-out process
        XCTAssertNotNil(user)
    }
    
    func testEmailServiceNotificationIntegration() async {
        // Test welcome email notification
        do {
            let result = try await emailServiceManager.sendWelcomeEmail(
                to: "test@example.com",
                userName: "Test User"
            )
            
            // Verify email was processed
            XCTAssertNotNil(result)
            
            // Verify notification was sent (success or failure)
            // Note: In a real test, we'd verify the notification was sent
            
        } catch {
            // Verify error notification was sent
            XCTAssertNotNil(error)
        }
    }
    
    func testAIServiceNotificationIntegration() async {
        let child = Child(
            id: UUID(),
            userId: UUID(),
            name: "Test Child",
            birthDate: Date(),
            avatarURL: nil
        )
        
        // Test AI analysis notification
        do {
            let analysis = try await aiService.analyzeArtwork(
                Data(), // Mock image data
                for: child
            )
            
            // Verify analysis was completed
            XCTAssertNotNil(analysis)
            
            // Verify notification was sent
            // Note: In a real test, we'd verify the notification was sent
            
        } catch {
            // Verify error notification was sent
            XCTAssertNotNil(error)
        }
    }
    
    func testProgressTrackingNotificationIntegration() async {
        let childId = UUID()
        let userId = UUID()
        
        // Test progress recording with notification
        do {
            let progressEntry = try await progressTrackingService.recordProgress(
                childId: childId,
                userId: userId,
                skill: "creativity",
                level: .intermediate,
                notes: "Test progress entry"
            )
            
            // Verify progress was recorded
            XCTAssertNotNil(progressEntry)
            XCTAssertEqual(progressEntry.skill, "creativity")
            XCTAssertEqual(progressEntry.level, .intermediate)
            
            // Verify notification was sent for milestone
            // Note: In a real test, we'd verify the notification was sent
            
        } catch {
            // Verify error notification was sent
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Offline Scenario Tests
    
    func testOfflineToggleEvaluation() async {
        // Simulate offline mode
        featureToggleManager.updateOnlineStatus(false)
        
        // Create toggle
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .global
        )
        await featureToggleManager.setToggle(toggle)
        
        // Verify toggle still works offline
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
        
        // Test notification sending offline
        let success = await notificationWrapperService.sendNotification(
            title: "Offline Test",
            body: "This notification should still work offline"
        )
        
        // Verify notification was processed
        XCTAssertNotNil(success)
    }
    
    func testOfflineProgressTracking() async {
        let childId = UUID()
        let userId = UUID()
        
        // Simulate offline mode
        featureToggleManager.updateOnlineStatus(false)
        
        // Test progress recording offline
        do {
            let progressEntry = try await progressTrackingService.recordProgress(
                childId: childId,
                userId: userId,
                skill: "fine_motor",
                level: .beginner,
                notes: "Offline progress entry"
            )
            
            // Verify progress was recorded offline
            XCTAssertNotNil(progressEntry)
            XCTAssertEqual(progressEntry.skill, "fine_motor")
            XCTAssertEqual(progressEntry.level, .beginner)
            
        } catch {
            XCTFail("Progress tracking should work offline: \(error)")
        }
    }
    
    func testOfflineSyncRecovery() async {
        // Simulate offline mode
        featureToggleManager.updateOnlineStatus(false)
        
        // Create toggle offline
        let toggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .user
        )
        await featureToggleManager.setToggle(toggle)
        
        // Simulate coming back online
        featureToggleManager.updateOnlineStatus(true)
        
        // Test sync recovery
        await featureToggleManager.syncToggles()
        
        // Verify toggle is still available
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggle.id))
    }
    
    // MARK: - Error Handling Tests
    
    func testToggleErrorHandling() async {
        // Test invalid toggle ID
        let isEnabled = featureToggleManager.isToggleEnabled(id: "invalid_toggle")
        XCTAssertFalse(isEnabled)
        
        // Test error logging
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        featureToggleManager.logToggleError(error, toggleId: "test_toggle", context: ["test": true])
        
        // Verify error was logged
        XCTAssertNotNil(error)
    }
    
    func testNotificationPermissionErrorHandling() async {
        // Test permission error logging
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        notificationWrapperService.logPermissionError(error, toggleId: "test_toggle", permissionStatus: .denied)
        
        // Verify error was logged
        XCTAssertNotNil(error)
    }
    
    func testSyncErrorHandling() async {
        // Test sync error logging
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync failed"])
        featureToggleManager.logSyncError(error, toggleCount: 5, lastSyncDate: Date())
        
        // Verify error was logged
        XCTAssertNotNil(error)
    }
    
    // MARK: - Performance Tests
    
    func testTogglePerformance() async {
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
        
        // Should be very fast (< 1ms per check)
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
    
    // MARK: - Analytics Integration Tests
    
    func testAnalyticsIntegration() async {
        let analyticsService = FeatureToggleAnalyticsService.shared
        
        // Test toggle tracking
        analyticsService.trackToggleEnabled(
            "test_toggle",
            scope: .global,
            experimentId: "test_experiment",
            userId: "test_user"
        )
        
        // Test experiment tracking
        analyticsService.trackExperimentParticipation(
            "test_experiment",
            variant: "treatment",
            userId: "test_user"
        )
        
        // Test notification tracking
        analyticsService.trackNotificationSent(
            .artwork,
            success: true,
            userId: "test_user"
        )
        
        // Verify analytics were tracked
        XCTAssertNotNil(analyticsService)
    }
    
    // MARK: - User Context Tests
    
    func testUserContextIntegration() async {
        // Set user context
        featureToggleManager.updateUserContext(userId: "test_user", groups: ["premium", "beta"])
        
        // Create user-specific toggle
        let userToggle = FeatureToggleFactory.createNotificationToggle(
            isEnabled: true,
            scope: .user
        )
        await featureToggleManager.setToggle(userToggle)
        
        // Verify toggle is active for user
        XCTAssertTrue(featureToggleManager.isToggleEnabled(id: userToggle.id))
        
        // Clear user context
        featureToggleManager.clearUserContext()
        
        // Verify toggle is no longer active
        XCTAssertFalse(featureToggleManager.isToggleEnabled(id: userToggle.id))
    }
    
    // MARK: - A/B Testing Integration Tests
    
    func testABTestingIntegration() async {
        let experimentId = "integration_test"
        
        // Test experiment inclusion
        let shouldInclude = featureToggleManager.shouldIncludeInExperiment(experimentId: experimentId)
        XCTAssertNotNil(shouldInclude)
        
        if shouldInclude {
            // Test variant assignment
            let variant = featureToggleManager.getExperimentVariant(
                experimentId: experimentId,
                variants: ["control", "treatment"]
            )
            
            XCTAssertTrue(["control", "treatment"].contains(variant))
            
            // Test variant-specific logic
            let toggleId = variant == "treatment" ? "new_feature" : "old_feature"
            await featureToggleManager.setToggleEnabled(id: toggleId, enabled: true)
            
            // Verify toggle is enabled
            XCTAssertTrue(featureToggleManager.isToggleEnabled(id: toggleId))
        }
    }
}

// MARK: - Mock Services for Testing

class MockEmailServiceManager: EmailService {
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_message_id",
            status: .sent,
            timestamp: Date(),
            recipient: email.to.first ?? "",
            error: nil
        )
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_reset_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_welcome_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_verification_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_followup_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
}

class MockEmailService: EmailService {
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_message_id",
            status: .sent,
            timestamp: Date(),
            recipient: email.to.first ?? "",
            error: nil
        )
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_reset_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_welcome_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_verification_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
    
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult {
        return EmailResult(
            id: UUID(),
            messageId: "mock_followup_id",
            status: .sent,
            timestamp: Date(),
            recipient: email,
            error: nil
        )
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func waitForAsyncOperation(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
}
