//
//  EmailServiceTests.swift
//  JoanieTests
//
//  Comprehensive Test Suite for Email Services
//  Tests EmailServiceManager, ResendService, SupabaseEmailService, and EmailTemplateManager
//

import XCTest
import Foundation
@testable import Joanie

// MARK: - EmailServiceTests

class EmailServiceTests: XCTestCase {
    
    // MARK: - Properties
    var emailServiceManager: EmailServiceManager!
    var mockPrimaryService: MockEmailService!
    var mockFallbackService: MockEmailService!
    var emailTemplateManager: EmailTemplateManager!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup mock services
        mockPrimaryService = MockEmailService()
        mockFallbackService = MockEmailService()
        
        // Setup email service manager
        emailServiceManager = EmailServiceManager(
            primaryService: mockPrimaryService,
            fallbackService: mockFallbackService
        )
        
        // Setup template manager
        emailTemplateManager = EmailTemplateManager()
        
        // Configure test environment
        mockPrimaryService.resetConfiguration()
        mockFallbackService.resetConfiguration()
    }
    
    override func tearDown() async throws {
        emailServiceManager = nil
        mockPrimaryService = nil
        mockFallbackService = nil
        emailTemplateManager = nil
        
        try await super.tearDown()
    }
    
    // MARK: - EmailServiceManager Tests
    
    func testEmailServiceManagerInitialization() {
        XCTAssertNotNil(emailServiceManager)
        XCTAssertEqual(emailServiceManager.currentService, .supabase) // Default fallback service
        XCTAssertTrue(emailServiceManager.serviceHealthStatus.canSendEmails)
    }
    
    func testSendPasswordResetEmailSuccess() async throws {
        // Given
        let email = "test@example.com"
        let resetToken = "test-reset-token"
        let userId = UUID()
        
        // Mock successful response
        mockPrimaryService.configureResponse(for: .passwordReset, response: EmailResult(
            service: .mock,
            status: .sent,
            messageId: "test-message-id"
        ))
        
        // When
        let result = try await emailServiceManager.sendPasswordReset(
            to: email,
            resetToken: resetToken,
            userId: userId
        )
        
        // Then
        XCTAssertEqual(result.status, .sent)
        XCTAssertEqual(result.service, .mock)
        XCTAssertNotNil(result.messageId)
        XCTAssertTrue(mockPrimaryService.emailsSentCount > 0)
    }
    
    func testSendWelcomeEmailSuccess() async throws {
        // Given
        let email = "welcome@example.com"
        let userName = "Test User"
        
        mockPrimaryService.configureResponse(for: .welcome, response: EmailResult(
            service: .mock,
            status: .sent,
            messageId: "welcome-message-id"
        ))
        
        // When
        let result = try await emailServiceManager.sendWelcomeEmail(
            to: email,
            userName: userName
        )
        
        // Then
        XCTAssertEqual(result.status, .sent)
        XCTAssertEqual(result.service, .mock)
        XCTAssertTrue(mockPrimaryService.emailsSentCount > 0)
    }
    
    func testSendAccountVerificationEmailSuccess() async throws {
        // Given
        let email = "verify@example.com"
        let verificationToken = "verify-token-123"
        
        mockPrimaryService.configureResponse(for: .accountVerification, response: EmailResult(
            service: .mock,
            status: .sent,
            messageId: "verification-message-id"
        ))
        
        // When
        let result = try await emailServiceManager.sendAccountVerification(
            to: email,
            verificationToken: verificationToken
        )
        
        // Then
        XCTAssertEqual(result.status, .sent)
        XCTAssertEqual(result.service, .mock)
        XCTAssertTrue(mockPrimaryService.emailsSentCount > 0)
    }
    
    func testFallbackMechanismAfterPrimaryFailure() async throws {
        // Given
        let email = "fallback@example.com"
        let resetToken = "test-token"
        let userId = UUID()
        
        // Configure primary service to fail
        mockPrimaryService.configureFailure(for: .passwordReset, probability: 1.0, error: .timeoutError)
        
        // Configure fallback service to succeed
        mockFallbackService.configureResponse(for: .passwordReset, response: EmailResult(
            service: .supabase,
            status: .sent,
            messageId: "fallback-message-id"
        ))
        
        // When
        let result = try await emailServiceManager.sendPasswordReset(
            to: email,
            resetToken: resetToken,
            userId: userId
        )
        
        // Then
        XCTAssertEqual(result.status, .sent)
        XCTAssertEqual(result.service, .supabase)
        XCTAssertTrue(mockPrimaryService.failureCount > 0)
        XCTAssertTrue(mockFallbackService.emailsSentCount > 0)
       XCTAssertTrue(emailServiceManager.fallbackActivations > 0)
    }
    
    func testServiceHealthCheck() async throws {
        // When
        let healthReport = await emailServiceManager.performHealthCheck()
        
        // Then
        XCTAssertNotNil(healthReport)
        XCTAssertTrue(healthReport.overallHealthy)
        XCTAssertEqual(healthReport.servicesChecked.count, 2)
        XCTAssertTrue(healthReport.servicesChecked.contains(.supabase))
    }
    
    func testServiceMetrics() {
        // When
        let metrics = emailServiceManager.getServiceMetrics()
        
        // Then
        XCTAssertNotNil(metrics)
        XCTAssertTrue(metrics.emailsSentViaResend >= 0)
        XCTAssertTrue(metrics.emailsSentViaSupabase >= 0)
        XCTAssertEqual(metrics.fallbackActivations, 0)
        XCTAssertEqual(metrics.totalFailures, 0)
    }
    
    // MARK: - EmailTemplateManager Tests
    
    func testLoadPasswordResetTemplate() async throws {
        // When
        let template = try await emailTemplateManager.loadTemplate(.passwordReset)
        
        // Then
        XCTAssertEqual(template.subject, "🔒 Reset Your Joanie Password")
        XCTAssertTrue(template.htmlBody.contains("Password Reset Request"))
        XCTAssertTrue(template.textBody.contains("Password Reset"))
        XCTAssertTrue(template.htmlBody.contains("{{ resetToken }}"))
        XCTAssertTrue(template.htmlBody.contains("{{ resetUrl }}"))
    }
    
    func testLoadWelcomeTemplate() async throws {
        // When
        let template = try await emailTemplateManager.loadTemplate(.welcome)
        
        // Then
        XCTAssertEqual(template.subject, "🎉 Welcome to Joanie, {{ userName }}!")
        XCTAssertTrue(template.htmlBody.contains("Welcome to Joanie"))
        XCTAssertTrue(template.textBody.contains("Welcome to Joanie"))
        XCTAssertTrue(template.htmlBody.contains("{{ userName }}"))
    }
    
    func testLoadAccountVerificationTemplate() async throws {
        // When
        let template = try await emailTemplateManager.loadTemplate(.accountVerification)
        
        // Then
        XCTAssertEqual(template.subject, "🔐 Verify Your Joanie Account")
        XCTAssertTrue(template.htmlBody.contains("Email Verification"))
        XCTAssertTrue(template.textBody.contains("Email Verification"))
        XCTAssertTrue(template.htmlBody.contains("{{ verificationToken }}"))
    }
    
    func testLoadFollowUpWelcomeTemplate() async throws {
        // When
        let template = try await emailTemplateManager.loadTemplate(.followUpWelcome)
        
        // Then
        XCTAssertTrue(template.subject.contains("Getting Started"))
        XCTAssertTrue(template.htmlBody.contains("{{ userName }}"))
        XCTAssertTrue(template.htmlBody.contains("{{ daysSinceSignup }}"))
        XCTAssertTrue(template.textBody.contains("{{ userName }}"))
        XCTAssertTrue(template.textBody.contains("{{ daysSinceSignup }}"))
    }
    
    func testFollowUpWelcomeEmailSending() async throws {
        // Given
        mockPrimaryService.configureForSuccess()
        
        // When
        let result = try await emailServiceManager.sendFollowUpWelcomeEmail(
            to: "test@example.com",
            userName: "Test User",
            daysSinceSignup: 7
        )
        
        // Then
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.service, .resend)
        XCTAssertNotNil(result.messageId)
        
        // Verify the email was sent with correct parameters
        XCTAssertEqual(mockPrimaryService.lastSentEmail?.to.first, "test@example.com")
        XCTAssertTrue(mockPrimaryService.lastSentEmail?.subject.contains("Getting Started") ?? false)
    }
    
    func testTemplateRenderingWithData() async throws {
        // Given
        let template = try await emailTemplateManager.loadTemplate(.passwordReset)
        let templateData: EmailTemplateData = [
            "resetToken": "abc123",
            "resetUrl": "https://joanie.app/reset?token=abc123",
            "userName": "Test User"
        ]
        
        // When
        let rendered = try emailTemplateManager.renderTemplate(template, with: templateData)
        
        // Then
        XCTAssertTrue(rendered.subject.contains("Reset Your Joanie Password"))
        XCTAssertTrue(rendered.htmlBody.contains("abc123"))
        XCTAssertTrue(rendered.htmlBody.contains("https://joanie.app/reset?token=abc123"))
        XCTAssertFalse(rendered.htmlBody.contains("{{ resetToken }}"))
        XCTAssertFalse(rendered.htmlBody.contains("{{ resetUrl }}"))
    }
    
    func testTemplateValidationSuccess() {
        // Given
        let template = EmailTemplate.passwordReset
        let templateData: EmailTemplateData = [
            "resetToken": "test123",
            "resetUrl": "https://joanie.app/reset?token=test123"
        ]
        
        // When
        let validation = emailTemplateManager.validateTemplateData(template, data: templateData)
        
        // Then
        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.missingVariables.isEmpty)
    }
    
    func testTemplateValidationFailure() {
        // Given
        let template = EmailTemplate.passwordReset
        let templateData: EmailTemplateData = [
            "resetToken": "test123"
            // Missing resetUrl
        ]
        
        // When
        let validation = emailTemplateManager.validateTemplateData(template, data: templateData)
        
        // Then
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.missingVariables.contains("resetUrl"))
    }
    
    func testTemplateCaching() async throws {
        // When - load template first time
        let template1 = try await emailTemplateManager.loadTemplate(.passwordReset)
        
        // When - load template second time
        let template2 = try await emailTemplateManager.loadTemplate(.passwordReset)
        
        // Then
        XCTAssertEqual(template1.subject, template2.subject)
        XCTAssertEqual(template1.htmlBody, template2.htmlBody)
        XCTAssertEqual(emailTemplateManager.cachedTemplateCount, 1)
    }
    
    func testCacheStatistics() {
        // When
        let stats = emailTemplateManager.getCacheStatistics()
        
        // Then
        XCTAssertNotNil(stats)
        XCTAssertTrue(stats.totalCached >= 0)
        XCTAssertTrue(stats.validCached >= 0)
        XCTAssertTrue(stats.cacheHitRate >= 0.0)
        XCTAssertTrue(stats.cacheHitRate <= 1.0)
    }
    
    // MARK: - MockEmailService Tests
    
    func testMockEmailServiceConfiguration() {
        // Given
        let mockService = MockEmailService()
        
        // When
        mockService.configureFailure(for: .passwordReset, probability: 0.5)
        mockService.configureDelay(2.0)
        mockService.configureResponseTime(1.5)
        
        // Then
        XCTAssertFalse(mockService.shouldFail)
        XCTAssertTrue(mockService.shouldDelay)
        XCTAssertEqual(mockService.simulatedDelay, 2.0)
        XCTAssertEqual(mockService.simulatedResponseTime, 1.5)
    }
    
    func testMockEmailServiceFailureSimulation() async throws {
        // Given
        let mockService = MockEmailService()
        mockService.configureFailure(for: .passwordReset, probability: 1.0, error: .networkError("Test failure"))
        
        let email = EmailMessage.passwordReset(to: "test@example.com", resetToken: "test")
        
        // When/Then
        do {
            _ = try await mockService.sendEmail(email)
            XCTFail("Expected failure but got success")
        } catch {
            XCTAssertTrue(mockService.failureCount > 0)
            XCTAssertTrue(mockService.lastError is EmailError)
        }
    }
    
    func testMockEmailServiceSuccessSimulation() async throws {
        // Given
        let mockService = MockEmailService()
        mockService.configureResponse(for: .passwordReset, response: EmailResult(
            service: .mock,
            status: .sent,
            messageId: "mock-success"
        ))
        
        let email = EmailMessage.passwordReset(to: "test@example.com", resetToken: "test")
        
        // When
        let result = try await mockService.sendEmail(email)
        
        // Then
        XCTAssertEqual(result.status, .sent)
        XCTAssertTrue(mockService.emailsSentCount > 0)
        XCTAssertTrue(mockService.sentEmails.contains(where: { $0.id == email.id }))
    }
    
    // MARK: - Error Handling Tests
    
    func testEmailErrorMapping() {
        // Given
        let emailError = EmailError.rateLimited(60.0)
        
        // When
        let authError = emailError.toAuthenticationError()
        let appError = emailError.toAppError()
        
        // Then
        XCTAssertEqual(authError, .rateLimitExceeded)
        XCTAssertTrue(appError is AppError)
        XCTAssertTrue(emailError.canRetry)
        XCTAssertTrue(emailError.shouldTriggerFallback)
    }
    
    func testNetworkErrorMapping() {
        // Given
        let networkError = URLError(.networkConnectionLost)
        
        // When
        let emailError = EmailError.fromNetworkError(networkError)
        
        // Then
        XCTAssertEqual(emailError, EmailError.networkError(networkError.localizedDescription))
        XCTAssertTrue(emailError.canRetry)
    }
}
