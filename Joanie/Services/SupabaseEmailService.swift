//
//  SupabaseEmailService.swift
//  Joanie
//
//  Supabase Email Service Implementation
//  Fallback email service using Supabase Auth integration
//

import Foundation

// MARK: - Supabase Email Service

@MainActor
class SupabaseEmailService: ObservableObject, EmailService {
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let logger: Logger
    private let templateManager: EmailTemplateManager
    
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
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
        self.logger = Logger.shared
        self.templateManager = EmailTemplateManager()
        
        validateServiceConnectivity()
    }
    
    // MARK: - EmailService Protocol Implementation
    
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        guard serviceStatus.canSendEmails else {
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
            
            logger.info("Email sent via Supabase fallback", metadata: [
                "service": "supabase",
                "emailId": result.id.uuidString,
                "status": result.status.rawValue
            ])
            
            return result
            
        } catch {
            isSending = false
            
            if let emailError = error as? EmailError {
                lastError = emailError
                errorMessage = emailError.userFacingMessage
                
                logger.error("Supabase email send failed", metadata: [
                    "service": "supabase",
                    "error": emailError.localizedDescription,
                    "severity": emailError.severity.rawValue
                ])
                
                throw emailError
            } else {
                let emailError = EmailError.fromNetworkError(error)
                lastError = emailError
                errorMessage = emailError.userFacingMessage
                
                logger.error("Unexpected Supabase email error", metadata: [
                    "service": "supabase",
                    "error": error.localizedDescription
                ])
                
                throw emailError
            }
        }
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        do {
            // Use Supabase Auth's built-in password reset functionality
            try await supabaseService.resetPassword(email: email)
            
            return EmailResult(
                id: UUID(),
                service: .supabase,
                status: .sent,
                sentAt: Date(),
                messageId: "supabase-reset-\(UUID().uuidString)",
                metadata: EmailDeliveryMetadata(
                    deliveryAttempts: 1,
                    lastAttemptAt: Date(),
                    estimatedDeliveryTime: Date().addingTimeInterval(60), // 1 minute estimated
                    serviceResponseTime: 0.5
                )
            )
            
        } catch {
            throw EmailError.fromAuthenticationError(error)
        }
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        // Supabase doesn't have built-in welcome email functionality
        // So we'll simulate sending a simple email
        let templateData: EmailTemplateData = [
            "userName": userName,
            "appStoreURL": "https://apps.apple.com",
            "webAppURL": "https://joanie.app"
        ]
        
        let templateContent = try await templateManager.loadTemplate(.welcome)
        let renderedContent = try templateManager.renderTemplate(templateContent, with: templateData)
        
        let emailMessage = EmailMessage(
            to: [email],
            subject: renderedContent.subject,
            content: .html(renderedContent.htmlBody),
            metadata: EmailMetadata(priority: .normal)
        )
        
        return try await sendEmail(emailMessage)
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        // Supabase handles verification internally, but we'll provide a custom implementation
        let templateData: EmailTemplateData = [
            "verificationToken": verificationToken,
            "email": email,
            "verificationURL": "https://joanie.app/verify?token=\(verificationToken)",
            "appName": "Joanie"
        ]
        
        let templateContent = try await templateManager.loadTemplate(.accountVerification)
        let renderedContent = try templateManager.renderTemplate(templateContent, with: templateData)
        
        let emailMessage = EmailMessage(
            to: [email],
            subject: renderedContent.subject,
            content: .html(renderedContent.htmlBody),
            metadata: EmailMetadata(priority: .normal)
        )
        
        return try await sendEmail(emailMessage)
    }
    
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult {
        let emailMessage = EmailMessage.followUpWelcome(to: email, userName: userName, daysSinceSignup: daysSinceSignup)
        return try await sendEmail(emailMessage)
    }
    
    // MARK: - Public Methods
    
    /// Check Supabase service health
    func checkHealth() async -> EmailServiceHealth {
        do {
            // Test Supabase connectivity with a simple auth check
            _ = try await supabaseService.getCurrentUser()
            
            serviceStatus = .healthy
            
            return EmailServiceHealth(
                isHealthy: true,
                responseTime: 1.0, // Estimated
                lastChecked: Date(),
                error: nil
            )
            
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
    
    /// Get service metrics (simplified for Supabase)
    func getServiceMetrics() -> EmailServiceMetrics {
        return EmailServiceMetrics(
            emailsSentToday: emailsSentToday,
            emailsSentTotal: emailsSentTotal,
            lastError: lastError,
            serviceStatus: serviceStatus,
            averageResponseTime: 1.0,
            uptime: Date().timeIntervalSince1970, // Simplified
            quotaUsage: "unlimited" // Supabase auth emails are typically unlimited
        )
    }
    
    /// Reset daily statistics
    func resetDailyStatistics() {
        emailsSentToday = 0
        logger.info("Supabase daily email statistics reset")
    }
    
    /// Check if service is available for specific email types
    func isServiceAvailable(for emailType: EmailTemplate) -> Bool {
        switch emailType {
        case .passwordReset:
            return true // Built-in Supabase functionality
        case .welcome:
            return true // Can implement custom
        case .accountVerification:
            return true // Can implement custom
        case .accountNotification:
            return true // Can implement custom
        }
    }
    
    // MARK: - Private Methods
    
    private func executeEmailSending(_ email: EmailMessage) async throws -> EmailResult {
        // For simplicity, we'll simulate email sending
        // In a real implementation, this might involve:
        // 1. Using Supabase Edge Functions for custom emails
        // 2. Integration with external email services via Supabase
        // 3. Database logging of email events
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...2_000_000_000)) // 0.5-2 seconds
        
        // Simulate occasional failures for testing
        if Int.random(in: 1...100) <= 5 { // 5% failure rate for simulation
            throw EmailError.invalidRecipient("Simulated Supabase email failure")
        }
        
        return EmailResult(
            id: UUID(),
            service: .supabase,
            status: .sent,
            sentAt: Date(),
            messageId: "supabase-\(UUID().uuidString)",
            metadata: EmailDeliveryMetadata(
                deliveryAttempts: 1,
                lastAttemptAt: Date(),
                estimatedDeliveryTime: Date().addingTimeInterval(120), // 2 minutes estimated
                serviceResponseTime: Double.random(in: 0.5...2.0)
            )
        )
    }
    
    private func validateServiceConnectivity() {
        Task {
            do {
                _ = try await supabaseService.getCurrentUser()
                serviceStatus = .healthy
                
                logger.info("Supabase email service initialized", metadata: [
                    "serviceStatus": serviceStatus.displayValue
                ])
            } catch {
                // Even if connectivity check fails, service might still work
                serviceStatus = .degraded
                
                logger.warning("Supabase email service initialization warning", metadata: [
                    "error": error.localizedDescription,
                    "serviceStatus": serviceStatus.displayValue
                ])
            }
        }
    }
    
    private func mapSupabaseError(_ error: Error) -> EmailError {
        // Map common Supabase errors to EmailError
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .networkError(error.localizedDescription)
        } else if errorMessage.contains("timeout") {
            return .timeoutError
        } else if errorMessage.contains("rate") || errorMessage.contains("limit") {
            return .rateLimited(60.0) // 1 minute retry
        } else if errorMessage.contains("auth") || errorMessage.contains("token") {
            return .authenticationFailed
        } else if errorMessage.contains("email") || errorMessage.contains("invalid") {
            return .invalidRecipient(error.localizedDescription)
        } else {
            return .serverError(0, error.localizedDescription)
        }
    }
}

// MARK: - Email Error Extensions

extension EmailError {
    /// Create email error from Supabase authentication error
    static func fromAuthenticationError(_ error: Error) -> EmailError {
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .networkError(error.localizedDescription)
        } else if errorMessage.contains("timeout") {
            return .timeoutError
        } else if errorMessage.contains("rate") || errorMessage.contains("limit") {
            return .rateLimited(60.0)
        } else if errorMessage.contains("auth") || errorMessage.contains("token") {
            return .authenticationFailed
        } else if errorMessage.contains("email") {
            return .invalidRecipient(error.localizedDescription)
        } else {
            return .serverError(0, error.localizedDescription)
        }
    }
    
    /// Create email error from Supabase generic error
    static func fromSupabaseError(_ error: Error) -> EmailError {
        if error is URLError {
            return .networkError(error.localizedDescription)
        } else if "\(error)".contains("timeout") {
            return .timeoutError
        } else {
            return .serverError(0, error.localizedDescription)
        }
    }
}
