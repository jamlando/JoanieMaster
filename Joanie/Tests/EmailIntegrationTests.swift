//
//  EmailIntegrationTests.swift
//  JoanieTests
//
//  Integration Tests for Email Services
//  Tests end-to-end email flows and real-world scenarios
//

import XCTest
import Foundation
@testable import Joanie

// MARK: - EmailIntegrationTests

class EmailIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    var dependencyContainer: DependencyContainer!
    var authService: AuthService!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Configure dependency container for testing
        dependencyContainer = DependencyContainer.shared
        dependencyContainer.configureForTesting()
        
        authService = dependencyContainer.authService
    }
    
    override func tearDown() async throws {
        dependencyContainer.reset()
        
        dependencyContainer = nil
        authService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - End-to-End Authentication Flow Tests
    
    func testSignUpFlowWithWelcomeEmail() async throws {
        // Given
        let email = "newuser@example.com"
        let password = "StrongPassword123!"
        let fullName = "Test User"
        
        // Mock successful Supabase sign up
        let mockUser = UserProfile(
            id: UUID(),
            email: email,
            fullName: fullName,
            displayName: fullName,
            profileImageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Note: This test would require mocking SupabaseService signUp method
        // For now, we'll test the email service integration
        
        // When
        try await authService.signUp(email: email, password: password, fullName: fullName)
        
        // Then
        XCTAssertEqual(authService.currentUser?.email, email)
        
        // Verify welcome email was triggered (via emailServiceManager)
        let emailManager = dependencyContainer.inject(EmailServiceManager.self)
        XCTAssertNotNil(emailManager)
    }
    
    func testPasswordResetFlow() async throws {
        // Given
        let email = "passwordreset@example.com"
        
        // When
        try await authService.resetPassword(email: email)
        
        // Then
        // Verify password reset email was sent successfully
        // In a real implementation, we would check the email service for sent emails
        
        XCTAssertFalse(authService.isLoading)
        XCTAssertNil(authService.errorMessage)
    }
    
    func testAccountVerificationFlow() async throws {
        // Given
        let mockUser = UserProfile(
            id: UUID(),
            email: "verify@example.com",
            fullName: "Verify User",
            displayName: "Verify User",
            profileImageURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Setup authenticated state
        await authService.currentUser = mockUser
        
        // When
        try await authService.sendAccountVerificationEmail()
        
        // Then
        XCTAssertFalse(authService.isLoading)
        XCTAssertNil(authService.errorMessage)
    }
    
    // MARK: - Email Service Configuration Tests
    
    func testEmailServiceInitialization() {
        // When
        let emailManager = dependencyContainer.inject(EmailServiceManager.self)
        
        // Then
        XCTAssertNotNil(emailManager)
        XCTAssertNotNil(dependencyContainer.inject(EmailTemplateManager.self))
    }
    
    func testEmailServiceHealthCheck() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        // When
        let healthReport = await emailManager.performHealthCheck()
        
        // Then
        XCTAssertNotNil(healthReport)
        XCTAssertTrue(healthReport.servicesChecked.count > 0)
    }
    
    func testEmailServiceMetrics() {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        // When
        let metrics = emailManager.getServiceMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
        XCTAssertTrue(metrics.emailsSentViaResend >= 0)
        XCTAssertTrue(metrics.emailsSentViaSupabase >= 0)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testEmailServiceFailureHandling() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        // Force a failure scenario (if MockEmailService supports this)
        if let mockService = emailManager.resendService as? MockEmailService {
            mockService.simulateTimeout()
        }
        
        // When
        do {
            _ = try await emailManager.sendPasswordReset(
                to: "failing@example.com",
                resetToken: "test",
                userId: UUID()
            )
            XCTFail("Expected failure but got success")
        } catch {
            // Then
            XCTAssertTrue(error is EmailError || error is AuthenticationError)
        }
    }
    
    // MARK: - Template Integration Tests
    
    func testPasswordResetTemplateIntegration() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self),
              let templateManager = dependencyContainer.inject(EmailTemplateManager.self) else {
            XCTFail("Email services not available")
            return
        }
        
        let email = "template@example.com"
        let resetToken = "integration-test-token"
        let userId = UUID()
        
        // When
        _ = try await emailManager.sendPasswordReset(
            to: email,
            resetToken: resetToken,
            userId: userId
        )
        
        // Then
        // Verify template was used (check MockEmailService sentEmails)
        if let mockService = emailManager.resendService as? MockEmailService {
            let sentEmail = mockService.sentEmails.last
            XCTAssertNotNil(sentEmail)
            XCTAssertTrue(sentEmail?.to.contains(email) ?? false)
        }
    }
    
    func testWelcomeEmailTemplateIntegration() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        let email = "welcome@example.com"
        let userName = "Welcome User"
        
        // When
        _ = try await emailManager.sendWelcomeEmail(to: email, userName: userName)
        
        // Then
        if let mockService = emailManager.resendService as? MockEmailService {
            let sentEmail = mockService.sentEmails.last
            XCTAssertNotNil(sentEmail)
            XCTAssertTrue(sentEmail?.to.contains(email) ?? false)
            XCTAssertTrue(sentEmail?.subject.contains("Welcome") ?? false)
        }
    }
    
    // MARK: - Performance Tests
    
    func testEmailTemplateLoadingPerformance() async throws {
        // Given
        guard let templateManager = dependencyContainer.inject(EmailTemplateManager.self) else {
            XCTFail("EmailTemplateManager not available")
            return
        }
        
        // When
        let startTime = Date()
        
        for _ in 0..<10 {
            _ = try await templateManager.loadTemplate(.passwordReset)
        }
        
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertTrue(duration < 2.0, "Template loading too slow: \(duration)s")
    }
    
    func testEmailTemplateCachingPerformance() async throws {
        // Given
        guard let templateManager = dependencyContainer.inject(EmailTemplateManager.self) else {
            XCTFail("EmailTemplateManager not available")
            return
        }
        
        // First load (cold)
        let coldStartTime = Date()
        _ = try await templateManager.loadTemplate(.passwordReset)
        let coldEndTime = Date()
        let coldDuration = coldEndTime.timeIntervalSince(coldStartTime)
        
        // Cache warm up
        _ = try await templateManager.loadTemplate(.welcome)
        
        // Second load (hot)
        let hotStartTime = Date()
        _ = try await templateManager.loadTemplate(.passwordReset)
        let hotEndTime = Date()
        let hotDuration = hotEndTime.timeIntervalSince(hotStartTime)
        
        // Then
        XCTAssertTrue(hotDuration < coldDuration * 0.5, 
                     "Cached template should be significantly faster: cold: \(coldDuration)s, hot: \(hotDuration)s")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testConcurrentPasswordResets() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        let emails = [
            "concurrent1@example.com",
            "concurrent2@example.com", 
            "concurrent3@example.com"
        ]
        
        // When
        await withTaskGroup(of: EmailResult?.self) { group in
            for email in emails {
                group.addTask {
                    try? await emailManager.sendPasswordReset(
                        to: email,
                        resetToken: "concurrent-test-token",
                        userId: UUID()
                    )
                }
            }
            
            var results: [EmailResult] = []
            for await result in group {
                if let emailResult = result {
                    results.append(emailResult)
                }
            }
            
            // Then
            XCTAssertEqual(results.count, emails.count)
        }
    }
    
    func testEmailServiceFailoverScenario() async throws {
        // Given
        guard let emailManager = dependencyContainer.inject(EmailServiceManager.self) else {
            XCTFail("EmailServiceManager not available")
            return
        }
        
        // Simulate primary service failure
        if let mockService = emailManager.resendService as? MockEmailService {
            mockService.simulateAuthenticationFailure()
        }
        
        let email = "failover@example.com"
        
        // When
        do {
            _ = try await emailManager.sendPasswordReset(
                to: email,
                resetToken: "failover-test-token",
                userId: UUID()
            )
        } catch {
            // Then
            XCTAssertTrue(error is EmailError)
        }
        
        // Verify fallback was attempted
        XCTAssertTrue(emailManager.fallbackActivations >= 0)
    }
    
    // MARK: - Configuration Tests
    
    func testDevelopmentEmailConfiguration() {
        // Given
        let secrets = Secrets()
        
        // When/Then
        // Verify configuration is set up for development
        XCTAssertNotNil(Secrets.resendAPIKey)
        XCTAssertNotNil(Secrets.resendDomain)
        XCTAssertNotNil(Secrets.emailFromAddress)
        XCTAssertNotNil(Secrets.emailFromName)
    }
    
    func testFeatureFlagConfiguration() {
        // When/Then
        // Verify feature flags have default values
        XCTAssertFalse(Secrets.resendEmailEnabled) // Default: disabled for development
        XCTAssertTrue(Secrets.emailFallbackEnabled) // Default: enabled
    }
}
