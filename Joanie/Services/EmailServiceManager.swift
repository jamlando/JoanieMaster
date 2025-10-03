//
//  EmailServiceManager.swift
//  Joanie
//
//  Email Service Management & Orchestration
//  Manages primary/fallback services, health monitoring, and automatic failover
//

import Foundation

// MARK: - Email Service Manager

@MainActor
class EmailServiceManager: ObservableObject, EmailService {
    // MARK: - Dependencies
    private let primaryService: EmailService
    private let fallbackService: EmailService
    private let serviceSelector: EmailServiceSelector
    private let logger: Logger
    
    // MARK: - Published Properties
    @Published var isSending: Bool = false
    @Published var lastSentEmail: EmailResult?
    @Published var errorMessage: String?
    @Published var currentService: EmailServiceType = .resend
    @Published var serviceHealthStatus: ServiceHealthStatus = .unknown
    
    // MARK: - Statistics
    @Published var emailsSentViaResend: Int = 0
    @Published var emailsSentViaSupabase: Int = 0
    @Published var fallbackActivations: Int = 0
    @Published var totalFailures: Int = 0
    
    // MARK: - Initialization
    init(
        primaryService: EmailService,
        fallbackService: EmailService,
        selector: EmailServiceSelector = EmailServiceSelector()
    ) {
        self.primaryService = primaryService
        self.fallbackService = fallbackService
        self.serviceSelector = selector
        self.logger = Logger.shared
        
        setupServiceSelector()
        
        if EmailConfiguration.isResendEnabled && EmailConfiguration.isValidConfiguration {
            serviceSelector.selectPrimaryService()
            currentService = .resend
        } else {
            serviceSelector.selectFallbackService()
            currentService = .supabase
        }
        
        logger.info("EmailServiceManager initialized", metadata: [
            "currentService": currentService.rawValue,
            "resendEnabled": EmailConfiguration.isResendEnabled,
            "fallbackEnabled": EmailConfiguration.isFallbackEnabled
        ])
    }
    
    // MARK: - EmailService Protocol Implementation
    
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        isSending = true
        errorMessage = nil
        
        do {
            let result = try await executeEmailWithFallback(email)
            
            isSending = false
            lastSentEmail = result
            
            // Update statistics
            updateStatistics(for: result.service)
            
            logger.info("Email sent successfully", metadata: [
                "serviceUsed": result.service.rawValue,
                "emailId": result.id.uuidString,
                "messageId": result.messageId ?? "",
                "serviceSwitch": currentService != result.service
            ])
            
            return result
            
        } catch {
            isSending = false
            totalFailures += 1
            
            if let emailError = error as? EmailError {
                errorMessage = emailError.userFacingMessage
                
                logger.error("Email send failed", metadata: [
                    "error": emailError.localizedDescription,
                    "canRetry": emailError.canRetry,
                    "shouldFallback": emailError.shouldTriggerFallback,
                    "severity": emailError.severity.rawValue,
                    "totalFailures": totalFailures
                ])
                
                throw emailError
            } else {
                let mappedError = EmailError.fromNetworkError(error)
                errorMessage = mappedError.userFacingMessage
                
                logger.error("Unexpected email error", metadata: [
                    "error": error.localizedDescription,
                    "mappedError": mappedError.localizedDescription
                ])
                
                throw mappedError
            }
        }
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        do {
            let result = try await executeServiceMethod { service in
                try await service.sendPasswordReset(to: email, resetToken: resetToken, userId: userId)
            }
            
            return result
            
        } catch {
            throw mapErrorForContext(error, emailType: .passwordReset)
        }
    }
    
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult {
        do {
            let result = try await executeServiceMethod { service in
                try await service.sendWelcomeEmail(to: email, userName: userName)
            }
            
            return result
            
        } catch {
            throw mapErrorForContext(error, emailType: .welcome)
        }
    }
    
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult {
        do {
            let result = try await executeServiceMethod { service in
                try await service.sendAccountVerification(to: email, verificationToken: verificationToken)
            }
            
            return result
            
        } catch {
            throw mapErrorForContext(error, emailType: .accountVerification)
        }
    }
    
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult {
        do {
            let result = try await executeServiceMethod { service in
                try await service.sendFollowUpWelcomeEmail(to: email, userName: userName, daysSinceSignup: daysSinceSignup)
            }
            
            return result
            
        } catch {
            throw mapErrorForContext(error, emailType: .followUpWelcome)
        }
    }
    
    // MARK: - Public Methods
    
    /// Manually switch to primary service
    func switchToPrimaryService() {
        guard EmailConfiguration.isResendEnabled else {
            logger.warning("Cannot switch to primary service - Resend disabled")
            return
        }
        
        serviceSelector.selectPrimaryService()
        currentService = .resend
        
        logger.info("Switched to primary email service", metadata: [
            "service": currentService.rawValue
        ])
    }
    
    /// Manually switch to fallback service
    func switchToFallbackService() {
        serviceSelector.selectFallbackService()
        currentService = .supabase
        
        logger.info("Switched to fallback email service", metadata: [
            "service": currentService.rawValue
        ])
    }
    
    /// Perform health check on all services
    func performHealthCheck() async -> ServiceHealthReport {
        var report = ServiceHealthReport()
        
        // Check primary service health
        if let resendService = primaryService as? ResendService {
            report.primaryHealth = await resendService.checkHealth()
        }
        
        // Check fallback service health
        if let supabaseService = fallbackService as? SupabaseEmailService {
            report.fallbackHealth = await supabaseService.checkHealth()
        }
        
        // Update overall health status
        updateOverallHealthStatus(report: report)
        
        // Log health check results
        logger.info("Health check completed", metadata: [
            "primaryHealthy": report.primaryHealth.isHealthy,
            "fallbackHealthy": report.fallbackHealth.isHealthy,
            "overallHealthy": report.overallHealthy
        ])
        
        return report
    }
    
    /// Get comprehensive service metrics
    func getServiceMetrics() -> EmailServiceManagerMetrics {
        return EmailServiceManagerMetrics(
            emailsSentViaResend: emailsSentViaResend,
            emailsSentViaSupabase: emailsSentViaSupabase,
            fallbackActivations: fallbackActivations,
            totalFailures: totalFailures,
            currentService: currentService,
            serviceHealthStatus: serviceHealthStatus,
            primaryServiceMetrics: getPrimaryServiceMetrics(),
            fallbackServiceMetrics: getFallbackServiceMetrics(),
            uptime: Date().timeIntervalSince1970, // Simplified
            averageResponseTime: calculateAverageResponseTime()
        )
    }
    
    /// Reset all statistics
    func resetStatistics() {
        emailsSentViaResend = 0
        emailsSentViaSupabase = 0
        fallbackActivations = 0
        totalFailures = 0
        
        logger.info("Email service statistics reset")
    }
    
    /// Force fallback activation (for testing)
    func forceFallback() {
        switchToFallbackService()
        fallbackActivations += 1
        
        logger.info("Forced fallback activation", metadata: [
            "activationCount": fallbackActivations
        ])
    }
    
    // MARK: - Private Methods
    
    private func executeEmailWithFallback(_ email: EmailMessage) async throws -> EmailResult {
        guard let activeService = serviceSelector.activeService else {
            throw EmailError.allServicesUnavailable
        }
        
        do {
            let result = try await activeService.sendEmail(email)
            serviceSelector.recordSuccess()
            
            return result
            
        } catch {
            serviceSelector.recordFailure(error)
            
            // Check if we should trigger fallback
            if serviceSelector.shouldFallback {
                logger.info("Primary service failed, attempting fallback", metadata: [
                    "error": error.localizedDescription,
                    "fallbackTriggered": "true"
                ])
                
                fallbackActivations += 1
                currentService = .supabase
                
                return try await fallbackService.sendEmail(email)
            }
            
            // No fallback available or error doesn't qualify for fallback
            throw error
        }
    }
    
    private func executeServiceMethod<T>(_ method: (EmailService) async throws -> T) async throws -> T {
        guard let activeService = serviceSelector.activeService else {
            throw EmailError.allServicesUnavailable
        }
        
        do {
            let result = try await method(activeService)
            serviceSelector.recordSuccess()
            return result
            
        } catch {
            serviceSelector.recordFailure(error)
            
            if serviceSelector.shouldFallback {
                logger.info("Primary service failed, attempting fallback")
                fallbackActivations += 1
                currentService = .supabase
                
                return try await method(fallbackService)
            }
            
            throw error
        }
    }
    
    private func mapErrorForContext(_ error: Error, emailType: EmailTemplate) -> EmailError {
        if let emailError = error as? EmailError {
            return emailError
        }
        
        // Map based on context
        let contextError = EmailError.fromNetworkError(error)
        
        logger.warning("Mapped error for email context", metadata: [
            "originalError": error.localizedDescription,
            "emailType": emailType.rawValue,
            "mappedError": contextError.localizedDescription
        ])
        
        return contextError
    }
    
    private func updateStatistics(for service: EmailServiceType) {
        switch service {
        case .resend:
            emailsSentViaResend += 1
        case .supabase:
            emailsSentViaSupabase += 1
        case .mock:
            break // Don't count mock emails
        }
    }
    
    private func setupServiceSelector() {
        serviceSelector.onPrimaryServiceSelected = { [weak self] in
            self?.currentService = .resend
        }
        
        serviceSelector.onFallbackServiceSelected = { [weak self] in
            self?.currentService = .supabase
        }
    }
    
    private func updateOverallHealthStatus(report: ServiceHealthReport) {
        if report.primaryHealth.isHealthy {
            serviceHealthStatus = .healthy
        } else if report.fallbackHealth.isHealthy {
            serviceHealthStatus = .degraded
        } else {
            serviceHealthStatus = .unhealthy
        }
    }
    
    private func getPrimaryServiceMetrics() -> EmailServiceMetrics? {
        if let resendService = primaryService as? ResendService {
            return resendService.getServiceMetrics()
        }
        return nil
    }
    
    private func getFallbackServiceMetrics() -> EmailServiceMetrics? {
        if let supabaseService = fallbackService as? SupabaseEmailService {
            return supabaseService.getServiceMetrics()
        }
        return nil
    }
    
    private func calculateAverageResponseTime() -> TimeInterval {
        // Simplified calculation
        return 1.5 // Placeholder
    }
}

// MARK: - Service Health Classes

enum ServiceHealthStatus: String, CaseIterable {
    case unknown = "unknown"
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    
    var displayValue: String {
        switch self {
        case .unknown: return "Unknown"
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .unhealthy: return "Unhealthy"
        }
    }
    
    var canSendEmails: Bool {
        return self == .healthy || self == .degraded
    }
}

struct ServiceHealthReport {
    var primaryHealth = EmailServiceHealth(
        isHealthy: false,
        responseTime: nil,
        lastChecked: Date(),
        error: EmailError.serviceHealthCheckFailed("primary")
    )
    var fallbackHealth = EmailServiceHealth(
        isHealthy: false,
        responseTime: nil,
        lastChecked: Date(),
        error: EmailError.serviceHealthCheckFailed("fallback")
    )
    
    var overallHealthy: Bool {
        return primaryHealth.isHealthy || fallbackHealth.isHealthy
    }
    
    var summary: [String: Any] {
        return [
            "primary_healthy": primaryHealth.isHealthy,
            "fallback_healthy": fallbackHealth.isHealthy,
            "overall_healthy": overallHealthy,
            "last_checked": Date().timeIntervalSince1970
        ]
    }
}

struct EmailServiceManagerMetrics {
    let emailsSentViaResend: Int
    let emailsSentViaSupabase: Int
    let fallbackActivations: Int
    let totalFailures: Int
    let currentService: EmailServiceType
    let serviceHealthStatus: ServiceHealthStatus
    let primaryServiceMetrics: EmailServiceMetrics?
    let fallbackServiceMetrics: EmailServiceMetrics?
    let uptime: TimeInterval
    let averageResponseTime: TimeInterval
    
    var summary: [String: Any] {
        return [
            "emails_resend": emailsSentViaResend,
            "emails_supabase": emailsSentViaSupabase,
            "fallback_activations": fallbackActivations,
            "total_failures": totalFailures,
            "current_service": currentService.rawValue,
            "health_status": serviceHealthStatus.rawValue,
            "uptime": uptime,
            "avg_response_time": averageResponseTime
        ]
    }
}
