//
//  EmailError.swift
//  Joanie
//
//  Comprehensive Email Error Handling
//  Provides specialized error handling for email operations with mapping to existing error systems
//

import Foundation

// MARK: - Email Error Definition

/// Comprehensive email error enumeration with severity classification and retry capabilities
enum EmailError: LocalizedError, Equatable {
    // MARK: - Configuration Errors
    case invalidConfiguration(String)
    case missingAPIKey
    case missingDomain
    case invalidFromAddress(String)
    
    // MARK: - Validation Errors
    case invalidRecipient(String)
    case invalidTemplate(String)
    case templateNotFound(String)
    
    // MARK: - Network & API Errors
    case networkError(String)
    case timeoutError
    case serverError(Int, String?)
    case authenticationFailed
    case forbidden
    
    // MARK: - Rate Limiting & Quota
    case rateLimited(TimeInterval)
    case quotaExceeded(Int, String?) // current usage, quota limit
    
    // MARK: - Email Content & Attachment Errors
    case attachmentTooLarge(String, sizeBytes: Int, maxBytes: Int)
    case invalidAttachmentType(String)
    case emptySubject
    case emptyContent
    case invalidHTMLContent(String)
    
    // MARK: - Service & Fallback Errors
    case primaryServiceUnavailable
    case fallbackRequired(Error)
    case allServicesUnavailable
    case serviceHealthCheckFailed(String)
    
    // MARK: - Template & Rendering Errors
    case templateRenderFailed(String)
    case templateVariableMissing(String, String?) // template name, missing variable
    case invalidTemplateData([String: String])
    
    // MARK: - Error Descriptions
    var errorDescription: String? {
        switch self {
        // Configuration Errors
        case .invalidConfiguration(let field):
            return "Invalid email configuration: \(field)"
        case .missingAPIKey:
            return "Email service API key is missing or invalid"
        case .missingDomain:
            return "Email service domain is missing or invalid"
        case .invalidFromAddress(let email):
            return "Invalid sender email address: \(email)"
            
        // Validation Errors
        case .invalidRecipient(let email):
            return "Invalid recipient email address: \(email)"
        case .invalidTemplate(let template):
            return "Invalid email template: \(template)"
        case .templateNotFound(let template):
            return "Email template not found: \(template)"
            
        // Network & API Errors
        case .networkError(let message):
            return "Network error: \(message)"
        case .timeoutError:
            return "Email service request timed out"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown error")"
        case .authenticationFailed:
            return "Email service authentication failed"
        case .forbidden:
            return "Email service access forbidden"
            
        // Rate Limiting & Quota
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(Int(retryAfter)) seconds"
        case .quotaExceeded(let usage, let quota):
            return "Email quota exceeded: \(usage)/\(quota ?? "unknown") emails used"
            
        // Content & Attachment Errors
        case .attachmentTooLarge(let filename, let size, let max):
            return "Attachment '\(filename)' too large: \(size)/\(max) bytes"
        case .invalidAttachmentType(let filename):
            return "Invalid attachment type for file: \(filename)"
        case .emptySubject:
            return "Email subject cannot be empty"
        case .emptyContent:
            return "Email content cannot be empty"
        case .invalidHTMLContent(let reason):
            return "Invalid HTML content: \(reason)"
            
        // Service & Fallback Errors
        case .primaryServiceUnavailable:
            return "Primary email service unavailable, using fallback"
        case .fallbackRequired(let originalError):
            return "Fallback required: \(originalError.localizedDescription)"
        case .allServicesUnavailable:
            return "All email services are currently unavailable"
        case .serviceHealthCheckFailed(let service):
            return "Health check failed for email service: \(service)"
            
        // Template & Rendering Errors
        case .templateRenderFailed(let reason):
            return "Template rendering failed: \(reason)"
        case .templateVariableMissing(let template, let variable):
            return "Missing template variable '\(variable ?? "unknown")' for template '\(template)'"
        case .invalidTemplateData(let data):
            return "Invalid template data provided: \(data.keys.joined(separator: ", "))"
        }
    }
    
    // MARK: - Error Severity Classification
    var severity: EmailErrorSeverity {
        switch self {
        case .missingAPIKey, .missingDomain, .authenticationFailed, .serverError:
            return .critical
        case .allServicesUnavailable, .quotaExceeded:
            return .error
        case .primaryServiceUnavailable, .rateLimited, .timeoutError, .networkError:
            return .warning
        case .fallbackRequired, .invalidRecipient, .invalidTemplate, .templateNotFound:
            return .info
        case .invalidConfiguration, .invalidFromAddress, .invalidAttachmentType, .emptySubject, .emptyContent:
            return .warning
        case .attachmentTooLarge, .invalidHTMLContent:
            return .warning
        case .templateRenderFailed, .templateVariableMissing, .invalidTemplateData:
            return .warning
        case .serviceHealthCheckFailed:
            return .info
        case .forbidden:
            return .error
        }
    }
    
    // MARK: - Retry Capability
    var canRetry: Bool {
        switch self {
        case .missingAPIKey, .missingDomain, .authenticationFailed, .invalidConfiguration:
            return false
        case .invalidRecipient, .invalidTemplate, .templateNotFound, .emptySubject, .emptyContent:
            return false
        case .attachmentTooLarge, .invalidAttachmentType, .quotaExceeded, .invalidHTMLContent:
            return false
        case .rateLimited, .timeoutError, .networkError, .serverError:
            return true
        case .primaryServiceUnavailable, .fallbackRequired:
            return true
        case .allServicesUnavailable, .serviceHealthCheckFailed:
            return true
        case .templateRenderFailed, .templateVariableMissing, .invalidTemplateData:
            return true
        case .forbidden:
            return false
        }
    }
    
    // MARK: - Suggested Retry Delay
    var suggestedRetryDelay: TimeInterval {
        switch self {
        case .rateLimited(let delay):
            return delay
        case .timeoutError:
            return 5.0
        case .networkError:
            return 10.0
        case .serverError(let code, _):
            if code >= 500 {
                return 30.0 // Server errors, longer delay
            } else {
                return 5.0 // Client errors, shorter delay
            }
        case .primaryServiceUnavailable:
            return 60.0 // Service unavailable, check again in a minute
        case .allServicesUnavailable:
            return 300.0 // All services down, check again in 5 minutes
        default:
            return 0.0 // No retry
        }
    }
    
    // MARK: - User-Facing Error Messages
    var userFacingMessage: String {
        switch self {
        case .missingAPIKey, .missingDomain, .authenticationFailed:
            return "Email service is temporarily unavailable. Please try again later."
        case .invalidRecipient(let email):
            return "The email address '\(email)' is not valid."
        case .rateLimited:
            return "Too many emails sent. Please wait a moment and try again."
        case .quotaExceeded:
            return "Daily email limit reached. Please try again tomorrow."
        case .networkError, .timeoutError:
            return "Network issue. Please check your connection and try again."
        case .allServicesUnavailable:
            return "Email service is temporarily down. Please try again in a few minutes."
        case .primaryServiceUnavailable, .fallbackRequired:
            return "Email was sent using backup service. Delivery may be delayed."
        default:
            return self.localizedDescription
        }
    }
}

// MARK: - Error Severity Classification

enum EmailErrorSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var displayValue: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
    
    var systemLogLevel: LogLevel? {
        switch self {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .error
        }
    }
}

// MARK: - Error Mapping Extensions

extension EmailError {
    /// Map EmailError to existing AuthenticationError for seamless integration
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
        case .authenticationFailed, .forbidden:
            return .invalidCredentials
        case .quotaExceeded:
            return .rateLimitExceeded
        case .invalidRecipient:
            return .invalidEmail
        case .missingAPIKey, .missingDomain, .allServicesUnavailable:
            return .passwordResetFailed
        default:
            return .passwordResetFailed
        }
    }
    
    /// Map EmailError to AppError for general error handling
    func toAppError() -> AppError {
        switch self {
        case .networkError(let message):
            return .networkError(message)
        case .timeoutError:
            return .networkError("Request timed out")
        case .serverError(let code, let message):
            return .networkError("Server error \(code): \(message ?? "Unknown error")")
        case .fallbackRequired(let error):
            return .unknown("Email service degraded, using fallback: \(error.localizedDescription)")
        case .allServicesUnavailable:
            return .unknown(messages: ["Email service is temporarily unavailable"])
        case .quotaExceeded(_, _):
            return .unknown(messages: ["Daily email limit reached"])
        default:
            return .unknown(messages: [self.localizedDescription ?? "Unknown email error"])
        }
    }
    
    /// Check if error indicates a fallback should be triggered
    var shouldTriggerFallback: Bool {
        switch self {
        case .primaryServiceUnavailable:
            return true
        case .serverError(let code, _):
            return code >= 500 // Server errors indicate service issues
        case .authenticationFailed, .forbidden, .quotaExceeded:
            return true
        case .allServicesUnavailable:
            return false // No fallback available
        case .rateLimited, .timeoutError, .networkError:
            return true // Temporary issues, try fallback
        default:
            return false
        }
    }
    
    /// Check if error should be reported to analytics
    var shouldReportToAnalytics: Bool {
        switch self.severity {
        case .critical, .error:
            return true
        case .warning:
            // Only report certain warning types
            return [.primaryServiceUnavailable, .quotaExceeded].contains(self)
        case .info:
            return false
        }
    }
}

// MARK: - Convenience Initializers

extension EmailError {
    /// Create a network error from URL error
    static func fromNetworkError(_ error: Error) -> EmailError {
        return .networkError(error.localizedDescription)
    }
    
    /// Create a server error from HTTP response
    static func fromHTTPResponse(statusCode: Int, message: String?) -> EmailError {
        switch statusCode {
        case 400...499:
            if statusCode == 401 {
                return .authenticationFailed
            } else if statusCode == 403 {
                return .forbidden
            } else if statusCode == 429 {
                return .rateLimited(60.0) // Default 1 minute retry
            } else {
                return .serverError(statusCode, message)
            }
        case 500...599:
            return .serverError(statusCode, message)
        default:
            return .unknownError(message ?? "Unknown HTTP error")
        }
    }
    
    /// Create validation error from template validation failure
    static func templateValidationFailed(_ template: String, missingVariables: [String]) -> EmailError {
        if missingVariables.count == 1 {
            return .templateVariableMissing(template, missingVariables.first!)
        } else {
            return .invalidTemplateData([:]) // Will be enhanced with specific template data info
        }
    }
}

// MARK: - Error Analytics Event

struct EmailErrorAnalyticsEvent {
    let error: EmailError
    let service: EmailServiceType
    let timestamp: Date
    let context: [String: String]
    
    init(error: EmailError, service: EmailServiceType, context: [String: String] = [:]) {
        self.error = error
        self.service = service
        self.timestamp = Date()
        self.context = context
    }
    
    var analyticsPayload: [String: Any] {
        return [
            "error_type": String(describing: error),
            "error_severity": error.severity.rawValue,
            "service_type": service.rawValue,
            "can_retry": error.canRetry,
            "should_fallback": error.shouldTriggerFallback,
            "suggested_delay": error.suggestedRetryDelay,
            "timestamp": timestamp.timeIntervalSince1970,
            "context": context
        ]
    }
}

