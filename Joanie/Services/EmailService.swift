//
//  EmailService.swift
//  Joanie
//
//  Email Service Protocol and Core Models
//  Provides abstract interface for email operations with comprehensive data structures
//

import Foundation

// MARK: - Email Service Protocol

/// Abstract interface for email operations in the Joanie app
/// Supports sending various types of emails with template management and error handling
protocol EmailService: ServiceProtocol {
    /// Send a general email message
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult
    
    /// Send a password reset email with reset token
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult
    
    /// Send a welcome email to new users
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult
    
    /// Send an account verification email
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult
    
    /// Send a follow-up welcome email after X days
    func sendFollowUpWelcomeEmail(to email: String, userName: String, daysSinceSignup: Int) async throws -> EmailResult
}

// MARK: - Email Message Models

/// Comprehensive email message structure supporting various content types and metadata
struct EmailMessage: Codable, Equatable {
    let id: UUID
    let to: [String]
    let cc: [String]?
    let bcc: [String]?
    let subject: String
    let content: EmailContent
    let attachments: [EmailAttachment]?
    let metadata: EmailMetadata
    let createdAt: Date
    
    init(
        to: [String], 
        subject: String, 
        content: EmailContent,
        cc: [String]? = nil,
        bcc: [String]? = nil,
        attachments: [EmailAttachment]? = nil,
        metadata: EmailMetadata = EmailMetadata()
    ) {
        self.id = UUID()
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.content = content
        self.attachments = attachments
        self.metadata = metadata
        self.createdAt = Date()
    }
}

/// Email content types supporting both static content and templates
enum EmailContent: Codable, Equatable {
    case text(String)
    case html(String)
    case template(EmailTemplate, templateData: EmailTemplateData = [:])
}

/// Email attachment structure for file attachments
struct EmailAttachment: Codable, Equatable {
    let filename: String
    let contentType: String
    let data: Data
    let sizeBytes: Int
    
    init(filename: String, contentType: String, data: Data) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
        self.sizeBytes = data.count
    }
}

/// Email metadata for priority, scheduling, and tracking
struct EmailMetadata: Codable, Equatable {
    let priority: EmailPriority
    let requiresReceipt: Bool
    let scheduledAt: Date?
    let tags: [String]?
    let trackOpens: Bool
    let trackClicks: Bool
    
    init(
        priority: EmailPriority = .normal,
        requiresReceipt: Bool = false,
        scheduledAt: Date? = nil,
        tags: [String]? = nil,
        trackOpens: Bool = true,
        trackClicks: Bool = true
    ) {
        self.priority = priority
        self.requiresReceipt = requiresReceipt
        self.scheduledAt = scheduledAt
        self.tags = tags
        self.trackOpens = trackOpens
        self.trackClicks = trackClicks
    }
}

/// Email priority levels for delivery queue management
enum EmailPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayValue: String {
        switch self {
        case .low: return "Low Priority"
        case .normal: return "Normal Priority"
        case .high: return "High Priority"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Email Templates

/// Predefined email templates for consistent branding and formatting
enum EmailTemplate: String, Codable, CaseIterable {
    case passwordReset = "password_reset"
    case welcome = "welcome"
    case followUpWelcome = "follow_up_welcome"
    case accountVerification = "account_verification"
    case accountNotification = "account_notification"
    
    var displayName: String {
        switch self {
        case .passwordReset: return "Password Reset"
        case .welcome: return "Welcome Email"
        case .followUpWelcome: return "Follow-Up Welcome"
        case .accountVerification: return "Account Verification"
        case .accountNotification: return "Account Notification"
        }
    }
}

/// Template data dictionary for dynamic content injection
typealias EmailTemplateData = [String: String]

// MARK: - Email Result

/// Comprehensive result structure tracking email delivery status and service information
struct EmailResult: Codable, Equatable {
    let id: UUID
    let service: EmailServiceType
    let status: EmailStatus
    let sentAt: Date?
    let messageId: String?
    let error: String?
    let metadata: EmailDeliveryMetadata?
    
    init(
        id: UUID = UUID(),
        service: EmailServiceType,
        status: EmailStatus,
        sentAt: Date? = nil,
        messageId: String? = nil,
        error: String? = nil,
        metadata: EmailDeliveryMetadata? = nil
    ) {
        self.id = id
        self.service = service
        self.status = status
        self.sentAt = sentAt
        self.messageId = messageId
        self.error = error
        self.metadata = metadata
    }
    
    var isSuccessful: Bool {
        return status == .sent
    }
}

/// Email service provider types
enum EmailServiceType: String, Codable, Equatable, CaseIterable {
    case resend = "resend"
    case supabase = "supabase"
    case mock = "mock"
    
    var displayName: String {
        switch self {
        case .resend: return "Resend"
        case .supabase: return "Supabase"
        case .mock: return "Mock Service"
        }
    }
}

/// Email delivery status tracking
enum EmailStatus: String, Codable, Equatable, CaseIterable {
    case pending = "pending"
    case sent = "sent"
    case delivered = "delivered"
    case failed = "failed"
    case bounced = "bounced"
    case rejected = "rejected"
    
    var displayValue: String {
        switch self {
        case .pending: return "Pending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .failed: return "Failed"
        case .bounced: return "Bounced"
        case .rejected: return "Rejected"
        }
    }
    
    var isSuccessful: Bool {
        return [.sent, .delivered].contains(self)
    }
}

/// Additional delivery tracking metadata
struct EmailDeliveryMetadata: Codable, Equatable {
    let deliveryAttempts: Int
    let lastAttemptAt: Date?
    let estimatedDeliveryTime: Date?
    let serviceResponseTime: TimeInterval?
    let retryCount: Int
    
    init(
        deliveryAttempts: Int = 1,
        lastAttemptAt: Date? = nil,
        estimatedDeliveryTime: Date? = nil,
        serviceResponseTime: TimeInterval? = nil,
        retryCount: Int = 0
    ) {
        self.deliveryAttempts = deliveryAttempts
        self.lastAttemptAt = lastAttemptAt
        self.estimatedDeliveryTime = estimatedDeliveryTime
        self.serviceResponseTime = serviceResponseTime
        self.retryCount = retryCount
    }
}

// MARK: - Configuration Models

/// Resend API client configuration
struct ResendConfiguration: Codable, Equatable {
    let apiKey: String
    let domain: String
    let fromEmail: String
    let fromName: String?
    let apiBaseURL: String
    let timeoutSeconds: TimeInterval
    let maxRetries: Int

    static let `default` = ResendConfiguration(
        apiKey: "",
        domain: "",
        fromEmail: "noreply@joanie.app",
        fromName: "Joanie",
        apiBaseURL: "https://api.resend.com",
        timeoutSeconds: 30,
        maxRetries: 3
    )
    
    var isValid: Bool {
        return !apiKey.isEmpty && !domain.isEmpty && !fromEmail.isEmpty
    }
    
    var maskedApiKey: String {
        guard apiKey.count > 8 else { return "****" }
        return String(apiKey.prefix(4)) + "..." + String(apiKey.suffix(4))
    }
}

/// Service dependencies for email services
struct EmailServiceDependencies: Equatable {
    let retryService: RetryService
    let logger: Logger
    let keychainService: KeychainService?
    
    static let `default` = EmailServiceDependencies(
        retryService: RetryService.shared,
        logger: Logger.shared,
        keychainService: KeychainService.shared
    )
}

// MARK: - Extensions for Convenience

extension EmailMessage {
    /// Create a simple text email message
    static func text(
        to: [String], 
        subject: String, 
        text: String,
        priority: EmailPriority = .normal
    ) -> EmailMessage {
        return EmailMessage(
            to: to,
            subject: subject,
            content: .text(text),
            metadata: EmailMetadata(priority: priority)
        )
    }
    
    /// Create a password reset email message
    static func passwordReset(
        to email: String,
        resetToken: String,
        userName: String? = nil
    ) -> EmailMessage {
        let templateData = ["resetToken": resetToken, "userName": userName ?? ""]
        return EmailMessage(
            to: [email],
            subject: "Reset Your Joanie Password",
            content: .template(.passwordReset, templateData: templateData),
            metadata: EmailMetadata(priority: .high)
        )
    }
    
    /// Create a welcome email message
    static func welcome(
        to email: String,
        userName: String
    ) -> EmailMessage {
        let templateData = ["userName": userName]
        return EmailMessage(
            to: [email],
            subject: "Welcome to Joanie!",
            content: .template(.welcome, templateData: templateData),
            metadata: EmailMetadata(priority: .normal)
        )
    }
    
    /// Create a follow-up welcome email message
    static func followUpWelcome(
        to email: String,
        userName: String,
        daysSinceSignup: Int
    ) -> EmailMessage {
        let templateData: EmailTemplateData = [
            "userName": userName,
            "daysSinceSignup": "\(daysSinceSignup)",
            "appStoreURL": "https://apps.apple.com/app/joanie",
            "webAppURL": "https://joanie.app"
        ]
        return EmailMessage(
            to: [email],
            subject: "Getting Started with Joanie – Your Next Steps",
            content: .template(.followUpWelcome, templateData: templateData),
            metadata: EmailMetadata(priority: .normal)
        )
    }
}

