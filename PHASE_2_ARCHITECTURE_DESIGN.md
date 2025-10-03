# Phase 2: Architecture Design - Resend Email Integration

## Overview

This document outlines the comprehensive architecture design for integrating Resend email service into the Joanie iOS app. The design follows the existing app architecture patterns while introducing email-specific abstractions and fallback mechanisms.

## Current Architecture Analysis

### Existing Structure
- **Service Layer**: `AuthService`, `SupabaseService`, `StorageService`, `AIService`
- **Configuration**: `Secrets.swift` with environment variable support
- **Dependency Injection**: `DependencyContainer` with singleton pattern
- **Error Handling**: Comprehensive error hierarchy with `AuthenticationError`, `AppError`, retry mechanisms
- **State Management**: `@Published` properties with Combine reactive patterns

### Email-Related Current State
- Password reset functionality exists in `AuthService.resetPassword()` but uses Supabase
- No dedicated email service architecture
- No email template management
- No email delivery status tracking

## Architecture Design

### 1. Email Service Abstraction Layer

#### EmailService Protocol
```swift
protocol EmailService: ServiceProtocol {
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult
    func sendWelcomeEmail(to email: String, userName: String) async throws -> EmailResult
    func sendAccountVerification(to email: String, verificationToken: String) async throws -> EmailResult
}
```

#### Email Message Model
```swift
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
    
    enum EmailContent {
        case text(String)
        case html(String)
        case template(EmailTemplate)
    }
}

struct EmailAttachment: Codable, Equatable {
    let filename: String
    let contentType: String
    let data: Data
}

struct EmailMetadata: Codable, Equatable {
    let priority: EmailPriority
    let requiresReceipt: Bool
    let scheduledAt: Date?
    let tags: [String]?
}

enum EmailPriority: String, Codable, CaseIterable {
    case low, normal, high, urgent
}

enum EmailTemplate: String, Codable, CaseIterable {
    case passwordReset = "password_reset"
    case welcome = "welcome"
    case accountVerification = "account_verification"
    case accountNotification = "account_notification"
}
```

### 2. Resend Service Implementation

#### ResendService Class
```swift
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
    
    // MARK: - Initialization
    init(
        apiKey: String,
        configuration: ResendConfiguration = .default,
        dependencies: ResendDependencies = .default
    ) {
        self.apiClient = ResendAPIClient(apiKey: apiKey)
        self.templateManager = EmailTemplateManager()
        self.retryService = dependencies.retryService
        self.logger = dependencies.logger
        self.configuration = configuration
    }
}
```

#### Resend Configuration
```swift
struct ResendConfiguration: Codable, Equatable {
    let apiKey: String
    let domain: String
    let fromEmail: String
    let fromName: String?
    let apiBaseURL: String
    let timeoutSeconds: TimeInterval
    let maxRetries: Int
    let retryDelaySeconds: TimeInterval
    
    static let `default` = ResendConfiguration(
        apiKey: "",
        domain: "",
        fromEmail: "noreply@joanie.app",
        fromName: "Joanie",
        apiBaseURL: "https://api.resend.com",
        timeoutSeconds: 30,
        maxRetries: 3,
        retryDelaySeconds: 2
    )
}

struct ResendDependencies: Equatable {
    let retryService: RetryService
    let logger: Logger
    
    static let `default` = ResendDependencies(
        retryService: RetryService.shared,
        logger: Logger.shared
    )
}
```

#### Resend API Client
```swift
class ResendAPIClient: ObservableObject {
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    init(apiKey: String, baseURL: String = "https://api.resend.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func sendEmail(_ email: ResendEmailRequest) async throws -> ResendEmailResponse {
        // Implementation details
    }
}
```

### 3. Error Handling Integration

#### Email-Specific Errors
```swift
enum EmailError: LocalizedError, Equatable {
    case invalidConfiguration(String)
    case invalidRecipient(String)
    case invalidTemplate(String)
    case rateLimited(TimeInterval)
    case quotaExceeded
    case templateNotFound(String)
    case networkError(String)
    case authenticationFailed
    case serverError(Int, String?)
    case timeoutError
    case invalidResponse
    case attachmentTooLarge(String)
    case fallbackRequired(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let field):
            return "Invalid email configuration: \(field)"
        case .invalidRecipient(let email):
            return "Invalid recipient email: \(email)"
        case .invalidTemplate(let template):
            return "Invalid email template: \(template)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds"
        case .quotaExceeded:
            return "Email quota exceeded"
        case .templateNotFound(let template):
            return "Email template not found: \(template)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Email service authentication failed"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown error")"
        case .timeoutError:
            return "Email service timeout"
        case .invalidResponse:
            return "Invalid response from email service"
        case .attachmentTooLarge(let filename):
            return "Attachment too large: \(filename)"
        case .fallbackRequired(let originalError):
            return "Fallback required: \(originalError.localizedDescription)"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .rateLimited, .quotaExceeded, .timeoutError:
            return .warning
        case .invalidConfiguration, .authenticationFailed, .serverError:
            return .error
        case .networkError, .invalidResponse:
            return .warning
        default:
            return .error
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .rateLimited, .timeoutError, .networkError, .serverError:
            return true
        case .quotaExceeded, .invalidConfiguration, .invalidRecipient, .invalidTemplate:
            return false
        case .authenticationFailed:
            return false
        case .templateNotFound:
            return false
        case .invalidResponse:
            return true
        case .attachmentTooLarge:
            return false
        case .fallbackRequired:
            return true
        }
    }
}
```

#### Error Mapping Integration
```swift
extension EmailError {
    func toAuthenticationError() -> AuthenticationError {
        switch self {
        case .networkError:
            return .networkConnectionFailed
        case .timeoutError:
            return .networkTimeout
        case .rateLimited:
            return .rateLimitExceeded
        case .serverError(let code, _):
            return .serverError(code)
        case .authenticationFailed:
            return .invalidCredentials
        default:
            return .passwordResetFailed
        }
    }
    
    func toAppError() -> AppError {
        switch self {
        case .networkError(let message):
            return .networkError(message)
        case .fallbackRequired(let error):
            return .unknown("Email service unusable, using fallback: \(error.localizedDescription)")
        default:
            return .unknown(self.localizedDescription ?? "Unknown email error")
        }
    }
}
```

### 4. Fallback Mechanism Design

#### Email Service Manager (Orchestrator)
```swift
@MainActor
class EmailServiceManager: ObservableObject, EmailService {
    // Primary service (Resend)
    private let primaryService: EmailService
    
    // Fallback service (Supabase Auth)
    private let fallbackService: EmailService
    
    // Service selection logic
    private let serviceSelector: EmailServiceSelector
    
    // Current active service
    private var activeService: EmailService {
        return serviceSelector.selectedService
    }
    
    init(
        primaryService: EmailService,
        fallbackService: EmailService,
        selector: EmailServiceSelector = EmailServiceSelector()
    ) {
        self.primaryService = primaryService
        self.fallbackService = fallbackService
        self.serviceSelector = selector
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        do {
            let result = try await activeService.sendPasswordReset(to: email, resetToken: resetToken, userId: userId)
            serviceSelector.recordSuccess()
            return result
        } catch {
            serviceSelector.recordFailure(error)
            
            if serviceSelector.shouldFallback {
                Logger.shared.info("Falling back to secondary email service")
                return try await fallbackService.sendPasswordReset(to: email, resetToken: resetToken, userId: userId)
            }
            
            throw error
        }
    }
}
```

#### Service Selection Logic
```swift
class EmailServiceSelector: ObservableObject {
    @Published var selectedService: EmailService
    @Published var serviceHealth: [String: ServiceHealth] = [:]
    
    private var primaryHealthy: Bool = true
    private var consecutiveFailures: Int = 0
    private var lastFailureTime: Date?
    private let maxConsecutiveFailures = 3
    private let recoveryTimeMinutes = 5
    
    func recordSuccess() {
        consecutiveFailures = 0
        primaryHealthy = true
        lastFailureTime = nil
    }
    
    func recordFailure(_ error: Error) {
        consecutiveFailures += 1
        lastFailureTime = Date()
        
        if consecutiveFailures >= maxConsecutiveFailures {
            primaryHealthy = false
        }
    }
    
    var shouldFallback: Bool {
        return !primaryHealthy && hasRecoveryTimeElapsed
    }
    
    private var hasRecoveryTimeElapsed: Bool {
        guard let lastFailure = lastFailureTime else { return true }
        return Date().timeIntervalSince(lastFailure) > recoveryTimeMinutes * 60
    }
}
```

### 5. Configuration Management Integration

#### Updated Secrets.swift Structure
```swift
struct Secrets {
    // MARK: - Supabase Configuration
    static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? 
                           "https://mcucbltfqwrrfrvewtxk.supabase.co"
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? 
                                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    static let supabaseServiceRoleKey = ProcessInfo.processInfo.environment["SUPABASE_SERVICE_ROLE_KEY"] ?? 
                                       "your-service-role-key-here"
    
    // MARK: - Email Service Configuration
    static let resendAPIKey = ProcessInfo.processInfo.environment["RESEND_API_KEY"] ?? 
                             "your-resend-api-key-here"
    static let resendDomain = ProcessInfo.processInfo.environment["RESEND_DOMAIN"] ?? 
                             "joanie.app"
    static let emailServiceProvider = ProcessInfo.processInfo.environment["EMAIL_SERVICE_PROVIDER"] ?? 
                                     "resend"
    static let emailFromAddress = ProcessInfo.processInfo.environment["EMAIL_FROM_ADDRESS"] ?? 
                                 "noreply@joanie.app"
    static let emailFromName = ProcessInfo.processInfo.environment["EMAIL_FROM_NAME"] ?? 
                              "Joanie"
    
    // MARK: - Feature Flags
    static let resendEmailEnabled = ProcessInfo.processInfo.environment["RESEND_EMAIL_ENABLED"] == "true"
    static let emailFallbackEnabled = ProcessInfo.processInfo.environment["EMAIL_FALLBACK_ENABLED"] == "true"
}

// MARK: - Email Configuration Helper
struct EmailConfiguration {
    static var resendConfig: ResendConfiguration {
        return ResendConfiguration(
            apiKey: Secrets.resendAPIKey,
            domain: Secrets.resendDomain,
            fromEmail: Secrets.emailFromAddress,
            fromName: Secrets.emailFromName,
            apiBaseURL: "https://api.resend.com",
            timeoutSeconds: 30,
            maxRetries: 3,
            retryDelaySeconds: 2
        )
    }
    
    static var isResendEnabled: Bool {
        return Secrets.resendEmailEnabled && !Secrets.resendAPIKey.isEmpty
    }
    
    static var isFallbackEnabled: Bool {
        return Secrets.emailFallbackEnabled
    }
}
```

### 6. Dependency Injection Integration

#### Updated DependencyContainer
```swift
@MainActor
class DependencyContainer: ObservableObject {
    // Existing services...
    private(set) var emailServiceManager: EmailServiceManager
    
    private init() {
        // Existing initialization...
        
        // Initialize email services
        let emailServices = createEmailServices()
        self.emailServiceManager = emailServices.manager
    }
    
    private func createEmailServices() -> (manager: EmailServiceManager, resend: ResendService?, fallback: EmailService?) {
        let fallbackService = SupabaseEmailService(supabaseService: supabaseService)
        
        if EmailConfiguration.isResendEnabled {
            let resendService = ResendService(
                apiKey: Secrets.resendAPIKey,
                configuration: EmailConfiguration.resendConfig
            )
            
            let manager = EmailServiceManager(
                primaryService: resendService,
                fallbackService: fallbackService
            )
            
            return (manager, resendService, fallbackService)
        } else {
            // Only fallback service
            return (EmailServiceManager(
                primaryService: fallbackService,
                fallbackService: fallbackService,
                selector: AlwaysFallbackSelector()
            ), nil, fallbackService)
        }
    }
}
```

#### Supabase Email Service Implementation
```swift
class SupabaseEmailService: EmailService {
    private let supabaseService: SupabaseService
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    func sendPasswordReset(to email: String, resetToken: String, userId: UUID) async throws -> EmailResult {
        try await supabaseService.resetPassword(email: email)
        return EmailResult(
            id: UUID(),
            service: .supabase,
            status: .sent,
            sentAt: Date(),
            messageId: "supabase-\(UUID().uuidString)"
        )
    }
}
```

### 7. Authentication Integration

#### Updated AuthService
```swift
@MainActor
class AuthService: ObservableObject, ServiceProtocol {
    // Existing properties...
    private let emailServiceManager: EmailServiceManager
    
    init(supabaseService: SupabaseService, emailServiceManager: EmailServiceManager) {
        self.supabaseService = supabaseService
        self.emailServiceManager = emailServiceManager
        setupBindings()
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Generate reset token (mock for now)
            let resetToken = generatePasswordResetToken()
            let userId = UUID() // In real implementation, get from Supabase
            
            // Use email service manager for sending
            _ = try await emailServiceManager.sendPasswordReset(
                to: email, 
                resetToken: resetToken, 
                userId: userId
            )
            
            isLoading = false
        } catch {
            isLoading = false
            let mappedError = SupabaseErrorMapper.shared.mapSupabaseError(error)
            errorMessage = mappedError.localizedDescription
            throw mappedError
        }
    }
    
    private func generatePasswordResetToken() -> String {
        // Implementation for token generation
        return "reset-token-\(UUID().uuidString)"
    }
}
```

### 8. Template Management

#### Email Template Manager
```swift
class EmailTemplateManager: ObservableObject {
    private var cachedTemplates: [EmailTemplate: EmailTemplateContent] = [:]
    
    func loadTemplate(_ template: EmailTemplate) async throws -> EmailTemplateContent {
        if let cached = cachedTemplates[template] {
            return cached
        }
        
        let content = try await fetchTemplateFromStorage(template)
        cachedTemplates[template] = content
        return content
    }
    
    private func fetchTemplateFromStorage(_ template: EmailTemplate) async throws -> EmailTemplateContent {
        switch template {
        case .passwordReset:
            return EmailTemplateContent(
                subject: "Reset Your Joanie Password",
                htmlBody: loadPasswordResetHTML(),
                textBody: loadPasswordResetText()
            )
        case .welcome:
            return EmailTemplateContent(
                subject: "Welcome to Joanie!",
                htmlBody: loadWelcomeHTML(),
                textBody: loadWelcomeText()
            )
        case .accountVerification:
            return EmailTemplateContent(
                subject: "Verify Your Joanie Account",
                htmlBody: loadVerificationHTML(),
                textBody: loadVerificationText()
            )
        case .accountNotification:
            return EmailTemplateContent(
                subject: "Account Notification",
                htmlBody: loadNotificationHTML(),
                textBody: loadNotificationText()
            )
        }
    }
}

struct EmailTemplateContent {
    let subject: String
    let htmlBody: String
    let textBody: String
}
```

### 9. Analytics and Monitoring

#### Email Analytics Service
```swift
class EmailAnalyticsService: ObservableObject {
    private let logger: Logger
    
    init(logger: Logger = Logger.shared) {
        self.logger = logger
    }
    
    func trackEmailSent(_ result: EmailResult, template: EmailTemplate) {
        let event = EmailAnalyticsEvent(
            type: .emailSent,
            service: result.service,
            template: template,
            success: result.status == .sent,
            timestamp: Date()
        )
        
        logger.info("Email Analytics: \(event)")
    }
    
    func trackEmailFailure(_ error: EmailError, template: EmailTemplate) {
        let event = EmailAnalyticsEvent(
            type: .emailFailed,
            service: nil,
            template: template,
            success: false,
            timestamp: Date(),
            error: error.errorDescription
        )
        
        logger.error("Email Analytics: \(event)")
    }
}

struct EmailAnalyticsEvent: Codable {
    let type: AnalyticsEventType
    let service: EmailServiceType?
    let template: EmailTemplate
    let success: Bool
    let timestamp: Date
    let error: String?
    
    enum AnalyticsEventType: String, Codable {
        case emailSent
        case emailFailed
        case serviceSwitched
        case templateLoaded
    }
    
    enum EmailServiceType: String, Codable {
        case resend
        case supabase
    }
}
```

### 10. Testing Strategy

#### MockEmailService for Testing
```swift
class MockEmailService: EmailService {
    @Published var sentEmails: [EmailMessage] = []
    @Published var shouldFail: Bool = false
    @Published var failureError: EmailError = .networkError("Mock failure")
    
    func sendEmail(_ email: EmailMessage) async throws -> EmailResult {
        guard !shouldFail else {
            throw failureError
        }
        
        sentEmails.append(email)
        
        return EmailResult(
            id: UUID(),
            service: .mock,
            status: .sent,
            sentAt: Date(),
            messageId: "mock-\(UUID().uuidString)"
        )
    }
    
    func reset() {
        sentEmails.removeAll()
        shouldFail = false
    }
}
```

#### Test Configuration
```swift
#if DEBUG
extension DependencyContainer {
    func configureForTesting() {
        // Configure email services for testing
        let mockService = MockEmailService()
        emailServiceManager = EmailServiceManager(
            primaryService: mockService,
            fallbackService: mockService,
            selector: TestEmailServiceSelector()
        )
    }
}

class TestEmailServiceSelector: EmailServiceSelector {
    override var shouldFallback: Bool {
        return false // Force primary service for testing
    }
}
#endif
```

## Integration Points

### 1. Database Schema Updates
- Email delivery tracking table
- Email template storage
- Service health monitoring

### 2. Environment Configuration
- Resend API key management
- Service routing configuration
- Feature flags for email services

### 3. UI Integration Points
- Error message mapping
- Email status indicators
- Fallback service notifications

## Security Considerations

1. **API Key Management**: Store Resend API key securely using existing KeychainService
2. **Email Content Sanitization**: Validate and sanitize all email inputs
3. **Rate Limiting**: Implement email sender rate limiting
4. **Audit Logging**: Track all email sending activities
5. **Data Privacy**: Ensure GDPR compliance for email content

## Performance Considerations

1. **Template Caching**: Cache email templates for faster rendering
2. **Async Processing**: Use background queues for email sending
3. **Connection Pooling**: Reuse HTTP connections for API calls
4. **Resource Management**: Monitor memory usage for large email attachments

## Migration Strategy

1. **Phase 1**: Implement Resend service alongside existing Supabase
2. **Phase 2**: Deploy with feature flag disabled (supabase only)
3. **Phase 3**: Enable Resend for internal testing
4. **Phase 4**: Gradual rollout to users with fallback
5. **Phase 5**: Full Resend deployment with Supabase fallback

This architecture provides a robust, scalable foundation for email services that integrates seamlessly with your existing app architecture while providing comprehensive error handling, monitoring, and fallback capabilities.

