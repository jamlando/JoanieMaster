//
//  ResendService.swift
//  Joanie
//
//  Resend Email Service Implementation
//  Primary email service using Resend API with comprehensive error handling
//

import Foundation

// MARK: - Resend Service

@MainActor
class ResendService: ObservableObject, EmailService {
    // MARK: - Dependencies
    private let apiClient: ResendAPIClient
    private let templateManager: EmailTemplateManager
    private let retryService: RetryService
    private let logger: Logger
    
    // MARK: - Configuration
    private let configuration: ResendConfiguration
    
    // MARK: - Published Properties
    @Published var isSending: Bool = false
    @Published var lastSentEmail: EmailResult?
    @Published var errorMessage: String?
    @Published var serviceStatus: EmailServiceStatus = .unknown
    
    // MARK: - Statistics
    @Published var emailsSentToday: Int = 0
    @Published var emailsSentTotal: Int = 0
    @Published var lastError: EmailError?
    
    // MARK: - Initialization
    init(
        configuration: ResendConfiguration = EmailConfiguration.resendConfig,
        dependencies: EmailServiceDependencies = .default
    ) {
        self.configuration = configuration
        self.apiClient = ResendAPIClient(apiKey: configuration.apiKey, baseURL: configuration.apiBaseURL)
        self.templateManager = EmailTemplateManager()
        self.retryService = dependencies.retryService
        self.logger = dependencies.logger
        
        validateConfiguration()
    }
    
    // MARK: - EmailService Protocol Implementation
    
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        guard serviceStatus != .disabled else {
            throw EmailError.primaryServiceUnavailable
        }
        
        isSending = true
        errorMessage = nil
        
        do {
            let result = try await executeEmailSending(email)
            
            isSending = false
            lastSentEmail = result
            
            // Update statistics
            emailsSentToday += 1
            emailsSentTotal += 1
            
            logger.info("Email sent successfully", metadata: [
                "service": "resend",
                "emailId": result.id.uuidString,
                "messageId": result.messageId ?? "",
                "status": result.status.rawValue
            ])
            
            return result
            
        } catch {
            isSending = false
            
            if let emailError = error as? EmailError {
                lastError = emailError
                errorMessage = emailError.userFacingMessage
                
                // Update service status based on error
                updateServiceStatusForError(emailError)
                
                logger.error("Email send failed", metadata: [
                    "service": "resend",
                    "error": emailError.localizedDescription,
                    "canRetry": emailError.canRetry,
                    "severity": emailError.severity.rawValue
                ])
                
                throw emailError
            } else {
                let emailError = EmailError.fromNetworkError(error)
                lastError = emailError
                errorMessage = emailError.userFacingMessage
                
                logger.error("Unexpected error during email send", metadata: [
                    "service": "resend",
                    "error": error.localizedDescription
                ])
                
                throw emailError
            }
        }
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        let emailMessage = EmailMessage.passwordReset(to: email, resetToken: resetToken, userName: nil)
        return try await sendEmail(emailMessage)
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        let emailMessage = EmailMessage.welcome(to: email, userName: userName)
        return try await sendEmail(emailMessage)
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        let templateData: EmailTemplateData = [
            "verificationToken": verificationToken,
            "email": email,
            "appName": "Joanie",
            "verificationURL": "https://joanie.app/verify?token=\(verificationToken)"
        ]
        
        let emailMessage = EmailMessage(
            to: [email],
            subject: "Verify Your Joanie Account",
            content: .template(.accountVerification, templateData: templateData),
            metadata: EmailMetadata(priority: .normal)
        )
        
        return try await sendEmail(emailMessage)
    }
    
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult {
        let emailMessage = EmailMessage.followUpWelcome(to: email, userName: userName, daysSinceSignup: daysSinceSignup)
        return try await sendEmail(emailMessage)
    }
    
    // MARK: - Public Methods
    
    /// Check service health and connectivity
    func checkHealth() async -> EmailServiceHealth {
        do {
            let isValid = try await apiClient.validateAPIKey()
            
            if isValid {
                serviceStatus = .healthy
                return EmailServiceHealth(
                    isHealthy: true,
                    responseTime: apiClient.lastResponseTime,
                    lastChecked: Date(),
                    error: nil
                )
            } else {
                serviceStatus = .unhealthy
                return EmailServiceHealth(
                    isHealthy: false,
                    responseTime: nil,
                    lastChecked: Date(),
                    error: EmailError.serviceHealthCheckFailed("resend")
                )
            }
        } catch {
            serviceStatus = .unhealthy
            return EmailServiceHealth(
                isHealthy: false,
                responseTime: nil,
                lastChecked: Date(),
                error: EmailError.fromNetworkError(error)
            )
        }
    }
    
    /// Get service statistics and metrics
    func getServiceMetrics() -> EmailServiceMetrics {
        return EmailServiceMetrics(
            emailsSentToday: emailsSentToday,
            emailsSentTotal: emailsSentTotal,
            lastError: lastError,
            serviceStatus: serviceStatus,
            averageResponseTime: apiClient.lastResponseTime,
            uptime: calculateUpTime(),
            quotaUsage: nil // Will be populated when quota checking is implemented
        )
    }
    
    /// Reset daily statistics
    func resetDailyStatistics() {
        emailsSentToday = 0
        logger.info("Daily email statistics reset")
    }
    
    // MARK: - Private Methods
    
    private func executeEmailSending(_ email: EmailMessage) async throws -> EmailResult {
        // Validate email before sending
        try validateEmailMessage(email)
        
        // Render email content if using templates
        let emailRequest = try await prepareEmailRequest(email)
        
        // Execute retry logic if needed
        return try await retryService.executeWithRetry(
            maxRetries: configuration.maxRetries,
            delay: configuration.timeoutSeconds
        ) {
            do {
                let resendResponse = try await apiClient.sendEmail(emailRequest)
                
                return EmailResult(
                    id: UUID(),
                    service: .resend,
                    status: .sent,
                    sentAt: Date(),
                    messageId: resendResponse.id,
                    metadata: EmailDeliveryMetadata(
                        deliveryAttempts: 1,
                        lastAttemptAt: Date(),
                        estimatedDeliveryTime: Date().addingTimeInterval(30), // 30 seconds estimated
                        serviceResponseTime: apiClient.lastResponseTime
                    )
                )
                
            } catch let error as EmailError {
                if error.canRetry {
                    logger.warning("Email send failed, retrying", metadata: [
                        "attempt": "retrying",
                        "error": error.localizedDescription
                    ])
                    throw error // Let retry service handle it
                } else {
                    // Fatal error, don't retry
                    throw error
                }
            }
        }
    }
    
    private func prepareEmailRequest(_ email: EmailMessage) async throws -> ResendEmailRequest {
        switch email.content {
        case .template(let template, let data):
            // Load and render template
            let templateContent = try await templateManager.loadTemplate(template)
            let renderedContent = try templateManager.renderTemplate(
                templateContent,
                with: data
            )
            
            // Create new email message with rendered content
            let renderedEmail = EmailMessage(
                to: email.to,
                subject: renderedContent.subject,
                content: .html(renderedContent.htmlBody),
                cc: email.cc,
                bcc: email.bcc,
                attachments: email.attachments,
                metadata: email.metadata
            )
            
            return ResendEmailRequest(from: renderedEmail, templateContent: renderedContent)
            
        default:
            // Direct content, no template rendering needed
            return ResendEmailRequest(from: email)
        }
    }
    
    private func validateEmailMessage(_ email: EmailMessage) throws {
        // Validate recipients
        guard !email.to.isEmpty else {
            throw EmailError.invalidRecipient("No recipients specified")
        }
        
        for recipient in email.to {
            guard emailIsValid(recipient) else {
                throw EmailError.invalidRecipient(recipient)
            }
        }
        
        // Validate subject
        guard !email.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmailError.emptySubject
        }
        
        // Validate content
        switch email.content {
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EmailError.emptyContent
            }
        case .html(let html):
            guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EmailError.emptyContent
            }
            try validateHTMLContent(html)
        case .template(let template, _):
            // Template validation handled in template manager
            break
        }
        
        // Validate attachments
        if let attachments = email.attachments {
            for attachment in attachments {
                guard attachment.sizeBytes <= 25000000 else { // 25MB limit
                    throw EmailError.attachmentTooLarge(
                        attachment.filename,
                        sizeBytes: attachment.sizeBytes,
                        maxBytes: 25000000
                    )
                }
                
                // Validate attachment type (basic check)
                let allowedTypes = ["image/jpeg", "image/png", "image/gif", "application/pdf", "text/plain"]
                guard allowedTypes.contains(attachment.contentType) else {
                    throw EmailError.invalidAttachmentType(attachment.filename)
                }
            }
        }
    }
    
    private func validateEmailAddress(_ email: String) -> Bool {
        return email.contains("@") && email.split(separator: "@").count == 2
    }
    
    private func emailIsValid(_ email: String) -> Bool {
        let emailRegex = """
        ^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$
        """.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
        
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    private func validateHTMLContent(_ html: String) throws {
        // Basic HTML validation (ensure no suspicious content)
        let suspiciousPatterns = ["<script", "javascript:", "onload=", "onerror="]
        
        for pattern in suspiciousPatterns {
            if html.lowercased().contains(pattern.lowercased()) {
                throw EmailError.invalidHTMLContent("Content contains potentially unsafe \(pattern) element")
            }
        }
    }
    
    private func validateConfiguration() {
        


        guard configuration.isValid else {
            serviceStatus = .disabled
            logger.error("Resend configuration is invalid", metadata: [
                "apiKey": configuration.maskedApiKey,
                "domain": configuration.domain,
                "fromEmail": configuration.fromEmail
            ])
            return
        }
        
        // Validate configuration on initialization
        Task {
            do {
                let isValid = try await apiClient.validateAPIKey()
                serviceStatus = isValid ? .healthy : .unhealthy
                
                logger.info("Resend service initialized", metadata: [
                    "serviceStatus": serviceStatus.displayValue,
                    "domain": configuration.domain
                ])
            } catch {
                serviceStatus = .unhealthy
                logger.error("Failed to validate Resend API on initialization", metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    private func updateServiceStatusForError(_ error: EmailError) {
        switch error.severity {
        case .critical:
            serviceStatus = .disabled
        case .error:
            if error.shouldTriggerFallback {
                serviceStatus = .degraded
            } else {
                serviceStatus = .healthy // Temporary issue
            }
        case .warning:
            serviceStatus = .healthy // Temporary issue
        case .info:
            serviceStatus = .healthy
        }
    }
    
    private func calculateUpTime() -> TimeInterval {
        // Simplified uptime calculation
        // In a real implementation, this would track service start time
        return Date().timeIntervalSince1970
    }
}

// MARK: - Supporting Types

/// Email service health information
struct EmailServiceHealth {
    let isHealthy: Bool
    let responseTime: TimeInterval?
    let lastChecked: Date
    let error: Error?
    
    var statusText: String {
        if isHealthy {
            let responseText = responseTime.map { String(format: "%.2f ms", $0 * 1000) } ?? "N/A"
            return "Healthy (\(responseText))"
        } else {
            return "Unhealthy"
        }
    }
}

/// Email service status enumeration
enum EmailServiceStatus: String, CaseIterable {
    case unknown = "unknown"
    case healthy = "healthy"
    case degraded = "degrated"
    case unhealthy = "unhealthy"
    case disabled = "disabled"
    
    var displayValue: String {
        switch self {
        case .unknown: return "Unknown"
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        case .disabled: return "Disabled"
        }
    }
    
    var canSendEmails: Bool {
        return self == .healthy || self == .degraded
    }
}

/// Email service metrics container
struct EmailServiceMetrics {
    let emailsSentToday: Int
    let emailsSentTotal: Int
    let lastError: EmailError?
    let serviceStatus: EmailServiceStatus
    let averageResponseTime: TimeInterval
    let uptime: TimeInterval
    let quotaUsage: String?
    
    var metricsSummary: [String: Any] {
        return [
            "emails_sent_today": emailsSentToday,
            "emails_sent_total": emailsSentTotal,
            "service_status": serviceStatus.rawValue,
            "average_response_time": averageResponseTime,
            "last_error": lastError?.localizedDescription ?? "None",
            "quota_usage": quotaUsage ?? "Unknown"
        ]
    }
}

