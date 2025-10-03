//
//  MockEmailService.swift
//  Joanie
//
//  Mock Email Service for Testing
//  Provides controlled testing capabilities for email operations
//

import Foundation

// MARK: - Mock Email Service

@MainActor
class MockEmailService: ObservableObject, EmailService {
    // MARK: - Configuration
    @Published var sentEmails: [EmailMessage] = []
    @Published var shouldFail: Bool = false
    @Published var failureError: EmailError = .networkError("Mock failure")
    @Published var shouldDelay: Bool = false
    @Published var simulatedDelay: TimeInterval = 1.0
    @Published var simulatedResponseTime: TimeInterval = 0.5
    @Published var mockServiceStatus: EmailServiceStatus = .healthy
    
    // MARK: - Statistics
    @Published var emailsSentCount: Int = 0
    @Published var failureCount: Int = 0
    @Published var averageResponseTime: TimeInterval = 0.0
    @Published var lastError: EmailError?
    @Published var isSending: Bool = false
    
    // MARK: - Testing Configuration
    private var customResponses: [EmailTemplate: EmailResult] = [:]
    private var failureProbabilities: [EmailTemplate: Double] = [:]
    private var callbackMetrics: MockCallbackMetrics = MockCallbackMetrics()
    
    // MARK: - Callbacks for Testing
    var onEmailSent: ((EmailMessage) -> Void)?
    var onEmailFailed: ((EmailMessage, EmailError) -> Void)?
    var onServiceStatusChanged: ((EmailServiceStatus) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupDefaultTestingConfiguration()
        
        Logger.shared.info("MockEmailService initialized", metadata: [
            "serviceType": "mock",
            "shouldFail": shouldFail,
            "simulatedDelay": simulatedDelay
        ])
    }
    
    // MARK: - EmailService Protocol Implementation
    
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        isSending = true
        
        // Simulate network delay
        if shouldDelay {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        isSending = false
        
        // Check if we should fail
        if shouldFail || shouldSimulateFailure(for: email) {
            failureCount += 1
            lastError = failureError
            
            Logger.shared.error("Mock email send failed", metadata: [
                "emailId": email.id.uuidString,
                "error": failureError.localizedDescription,
                "failureCount": failureCount
            ])
            
            onEmailFailed?(email, failureError)
            throw failureError
        }
        
        // Record successful send
        sentEmails.append(email)
        emailsSentCount += 1
        
        // Update response time metrics
        averageResponseTime = (averageResponseTime + simulatedResponseTime) / 2.0
        
        // Check for custom response
        let result = getCustomResponse(for: email) ?? createDefaultResult(for: email)
        
        Logger.shared.info("Mock email sent successfully", metadata: [
            "emailId": email.id.uuidString,
            "totalSent": emailsSentCount,
            "resultId": result.id.uuidString
        ])
        
        onEmailSent?(email)
        return result
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        let emailMessage = EmailMessage.passwordReset(to: email, resetToken: resetToken, userName: nil)
        
        // Check if we have a custom response for password reset
        if let customResult = customResponses[.passwordReset] {
            sentEmails.append(emailMessage)
            emailsSentCount += 1
            onEmailSent?(emailMessage)
            return createResultFromBase(customResult, emailMessage: emailMessage)
        }
        
        return try await sendEmail(emailMessage)
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        let emailMessage = EmailMessage.welcome(to: email, userName: userName)
        
        if let customResult = customResponses[.welcome] {
            sentEmails.append(emailMessage)
            emailsSentCount += 1
            onEmailSent?(emailMessage)
            return createResultFromBase(customResult, emailMessage: emailMessage)
        }
        
        return try await sendEmail(emailMessage)
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        let templateData: EmailTemplateData = [
            "verificationToken": verificationToken,
            "email": email,
            "verificationURL": "https://joanie.app/verify?token=\(verificationToken)",
            "appName": "Joanie"
        ]
        
        let emailMessage = EmailMessage(
            to: [email],
            subject: "🔐 Verify Your Joanie Account",
            content: .template(.accountVerification, templateData: templateData),
            metadata: EmailMetadata(priority: .normal)
        )
        
        if let customResult = customResponses[.accountVerification] {
            sentEmails.append(emailMessage)
            emailsSentCount += 1
            onEmailSent?(emailMessage)
            return createResultFromBase(customResult, emailMessage: emailMessage)
        }
        
        return try await sendEmail(emailMessage)
    }
    
    // MARK: - Testing Configuration Methods
    
    /// Configure failure behavior for specific email template
    func configureFailure(for template: EmailTemplate, probability: Double, error: EmailError? = nil) {
        failureProbabilities[template] = probability
        
        if let error = error {
            customResponses[template] = EmailResult(
                service: .mock,
                status: .failed,
                error: error.localizedDescription
            )
        }
        
        Logger.shared.info("Mock service configured for template", metadata: [
            "template": template.rawValue,
            "failureProba": probability,
            "error": error?.localizedDescription ?? "default"
        ])
    }
    
    /// Configure custom response for specific template
    func configureResponse(for template: EmailTemplate, response: EmailResult) {
        customResponses[template] = response
        
        Logger.shared.info("Mock service custom response configured", metadata: [
            "template": template.rawValue,
            "responseStatus": response.status.rawValue
        ])
    }
    
    /// Configure network delay simulation
    func configureDelay(_ delay: TimeInterval, shouldDelay: Bool = true) {
        simulatedDelay = delay
        shouldDelay = shouldDelay
        
        Logger.shared.info("Mock service delay configured", metadata: [
            "delay": delay,
            "shouldDelay": shouldDelay
        })
    }
    
    /// Configure response time simulation
    func configureResponseTime(_ responseTime: TimeInterval) {
        simulatedResponseTime = responseTime
        
        Logger.shared.info("Mock service response time configured", metadata: [
            "responseTime": responseTime
        ])
    }
    
    /// Simulate service status change
    func simulateServiceStatus(_ status: EmailServiceStatus) {
        mockServiceStatus = status
        onServiceStatusChanged?(status)
        
            Logger.shared.info("Mock service status changed", metadata: [
            "status": status.rawValue
        ])
    }
    
    /// Simulate network timeouts
    func simulateTimeout(timeout: TimeInterval = 30.0) {
        shouldFail = true
        failureError = .timeoutError
        shouldDelay = true
        simulatedDelay = timeout
        
            Logger.shared.info("Mock service timeout configured", metadata: [
            "timeout": timeout
        ])
    }
    
    /// Simulate rate limiting
    func simulateRateLimit(retryAfter: TimeInterval = 60.0) {
        shouldFail = true
        failureError = .rateLimited(retryAfter)
        
            Logger.shared.info("Mock service rate limit configured", metadata: [
            "retryAfter": retryAfter
        ])
    }
    
    /// Simulate authentication failure
    func simulateAuthenticationFailure() {
        shouldFail = true
        failureError = .authenticationFailed
        
        Logger.shared.info("Mock service authentication failure configured")
    }
    
    /// Simulate quota exceeded
    func simulateQuotaExceeded() {
        shouldFail = true
        failureError = .quotaExceeded(1000, "Monthly limit reached")
        
        Logger.shared.info("Mock service quota exceeded configured")
    }
    
    /// Reset all testing configuration
    func resetConfiguration() {
        sentEmails.removeAll()
        shouldFail = false
        shouldDelay = false
        simulatedDelay = 1.0
        simulatedResponseTime = 0.5
        mockServiceStatus = .healthy
        emailsSentCount = 0
        failureCount = 0
        averageResponseTime = 0.0
        lastError = nil
        customResponses.removeAll()
        failureProbabilities.removeAll()
        
        Logger.shared.info("Mock service configuration reset")
    }
    
    /// Get comprehensive testing metrics
    func getTestingMetrics() -> MockTestingMetrics {
        return MockTestingMetrics(
            emailsSentCount: emailsSentCount,
            failureCount: failureCount,
            successRate: emailsSentCount > 0 ? Double(emailsSentCount - failureCount) / Double(emailsSentCount) : 0.0,
            averageResponseTime: averageResponseTime,
            mockServiceStatus: mockServiceStatus,
            callbackMetrics: callbackMetrics,
            sentEmails: sentEmails,
            customResponsesCount: customResponses.count,
            configuredFailureProbabilities: failureProbabilities.count
        )
    }
    
    /// Validate email message (mock validation)
    func validateEmailMessage(_ email: EmailMessage) -> MockValidationResult {
        var errors: [String] = []
        
        // Validate recipients
        if email.to.isEmpty {
            errors.append("No recipients")
        }
        
        // Validate subject
        if email.subject.isEmpty {
            errors.append("Empty subject")
        }
        
        return MockValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            emailId: email.id
        )
    }
    
    /// Get email history filtered by template
    func getEmailHistory(for template: EmailTemplate) -> [EmailMessage] {
        return sentEmails.filter { email in
            switch email.content {
            case .template(let emailTemplate, _):
                return emailTemplate == template
            default:
                return false
            }
        }
    }
    
    /// Clear email history
    func clearHistory() {
        sentEmails.removeAll()
        
        Logger.shared.info("Mock service email history cleared")
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultTestingConfiguration() {
        // Configure default failure probabilities
        failureProbabilities[.passwordReset] = 0.02 // 2% failure rate
        failureProbabilities[.welcome] = 0.01 // 1% failure rate
        failureProbabilities[.accountVerification] = 0.02 // 2% failure rate
        failureProbabilities[.accountNotification] = 0.03 // 3% failure rate
    }
    
    private func shouldSimulateFailure(for email: EmailMessage) -> Bool {
        let template: EmailTemplate
        
        switch email.content {
        case .template(let emailTemplate, _):
            template = emailTemplate
        
        default:
            template = .accountNotification // Default template for general emails
        }
        
        if let probability = failureProbabilities[template] {
            return Double.random(in: 0...1) < probability
        }
        
        return false
    }
    
    private func getCustomResponse(for email: EmailMessage) -> EmailResult? {
        let template: EmailTemplate
        
        switch email.content {
        case .template(let emailTemplate, _):
            template = emailTemplate
        default:
            template = .accountNotification
        }
        
        return customResponses[template]
    }
    
    private func createDefaultResult(for email: EmailMessage) -> EmailResult {
        return EmailResult(
            id: UUID(),
            service: .mock,
            status: .sent,
            sentAt: Date(),
            messageId: "mock-\(UUID().uuidString)",
            metadata: EmailDeliveryMetadata(
                deliveryAttempts: 1,
                lastAttemptAt: Date(),
                estimatedDeliveryTime: Date().addingTimeInterval(30),
                serviceResponseTime: simulatedResponseTime
            )
        )
    }
    
    private func createResultFromBase(_ baseResult: EmailResult, emailMessage: EmailMessage) -> EmailResult {
        return EmailResult(
            id: UUID(),
            service: .mock,
            status: baseResult.status,
            sentAt: baseResult.sentAt,
            messageId: baseResult.messageId ?? "mock-\(UUID().uuidString)",
            error: baseResult.error,
            metadata: baseResult.metadata
        )
    }
}

// MARK: - Supporting Types

/// Mock service callback metrics
struct MockCallbackMetrics {
    var emailsSentCallbacks: Int = 0
    var emailsFailedCallbacks: Int = 0
    var serviceStatusChangedCallbacks: Int = 0
    
    mutating func recordEmailSent() {
        emailsSentCallbacks += 1
    }
    
    mutating func recordEmailFailed() {
        emailsFailedCallbacks += 1
    }
    
    mutating func recordServiceStatusChanged() {
        serviceStatusChangedCallbacks += 1
    }
    
    var summary: [String: Int] {
        return [
            "emailsSentCallbacks": emailsSentCallbacks,
            "emailsFailedCallbacks": emailsFailedCallbacks,
            "serviceStatusChangedCallbacks": serviceStatusChangedCallbacks
        ]
    }
}

/// Mock validation result
struct MockValidationResult {
    let isValid: Bool
    let errors: [String]
    let emailId: UUID
    
    var summary: [String: Any] {
        return [
            "isValid": isValid,
            "errors": errors,
            "emailId": emailId.uuidString
        ]
    }
}

/// Mock testing metrics container
struct MockTestingMetrics {
    let emailsSentCount: Int
    let failureCount: Int
    let successRate: Double
    let averageResponseTime: TimeInterval
    let mockServiceStatus: EmailServiceStatus
    let callbackMetrics: MockCallbackMetrics
    let sentEmails: [EmailMessage]
    let customResponsesCount: Int
    let configuredFailureProbabilities: Int
    
    var summary: [String: Any] {
        return [
            "emailsSentCount": emailsSentCount,
            "failureCount": failureCount,
            "successRate": successRate,
            "averageResponseTime": averageResponseTime,
            "serviceStatus": mockServiceStatus.rawValue,
            "callbackMetrics": callbackMetrics.summary,
            "sentEmailsCount": sentEmails.count,
            "customResponsesCount": customResponsesCount,
            "configuredFailureProbabilities": configuredFailureProbabilities
        ]
    }
}

// MARK: - Error Extensions for Mock Service

extension EmailError {
    /// Create mock-specific error for testing
    static func mockTestingError(_ message: String) -> EmailError {
        return .serverError(999, message)
    }
}
