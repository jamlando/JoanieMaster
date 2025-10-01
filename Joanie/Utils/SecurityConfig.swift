import Foundation

// MARK: - Security Configuration

struct SecurityConfig {
    // MARK: - File Upload Security
    
    static let maxFileSize = 10 * 1024 * 1024 // 10MB
    static let maxImageDimension = 4096 // pixels
    static let maxImagePixels = 50_000_000 // 50 megapixels
    
    // MARK: - Session Security
    
    static let sessionTimeout: TimeInterval = 3600 // 1 hour
    static let refreshTokenBuffer: TimeInterval = 300 // 5 minutes before expiry
    static let maxLoginAttempts = 5
    static let lockoutDuration: TimeInterval = 900 // 15 minutes
    
    // MARK: - COPPA Compliance
    
    static let defaultDataRetentionPeriod = 365 // days
    static let minConsentAge = 13 // years
    static let maxConsentAge = 18 // years
    
    // MARK: - API Security
    
    static let maxRequestSize = 50 * 1024 * 1024 // 50MB
    static let requestTimeout: TimeInterval = 30 // seconds
    static let maxConcurrentRequests = 10
    
    // MARK: - Content Security
    
    static let allowedImageTypes = ["jpeg", "jpg", "png", "heic", "heif"]
    static let blockedFileExtensions = [
        "exe", "bat", "cmd", "com", "pif", "scr", "vbs", "js", "jar",
        "php", "asp", "jsp", "py", "rb", "pl", "sh", "ps1"
    ]
    
    // MARK: - Malicious Pattern Detection
    
    static let maliciousSignatures: [[UInt8]] = [
        [0x4D, 0x5A], // PE executable
        [0x7F, 0x45, 0x4C, 0x46], // ELF executable
        [0xCA, 0xFE, 0xBA, 0xBE], // Mach-O executable
        [0xFE, 0xED, 0xFA, 0xCE], // Mach-O executable (reverse)
        [0xFE, 0xED, 0xFA, 0xCF], // Mach-O executable (reverse)
        [0xCE, 0xFA, 0xED, 0xFE], // Mach-O executable
        [0xCF, 0xFA, 0xED, 0xFE]  // Mach-O executable
    ]
    
    static let suspiciousPatterns = [
        "<script", "javascript:", "vbscript:", "onload=", "onerror=",
        "eval(", "document.cookie", "window.location", "alert(",
        "<?php", "<?=", "#!/bin/", "#!/usr/bin/"
    ]
    
    // MARK: - Validation Methods
    
    static func isValidImageType(_ filename: String) -> Bool {
        let lowercaseFilename = filename.lowercased()
        return allowedImageTypes.contains { lowercaseFilename.hasSuffix(".\($0)") }
    }
    
    static func isBlockedFileType(_ filename: String) -> Bool {
        let lowercaseFilename = filename.lowercased()
        return blockedFileExtensions.contains { lowercaseFilename.hasSuffix(".\($0)") }
    }
    
    static func isValidFileSize(_ size: Int) -> Bool {
        return size <= maxFileSize
    }
    
    static func isValidImageDimension(_ width: Int, _ height: Int) -> Bool {
        return width <= maxImageDimension && height <= maxImageDimension
    }
    
    static func isValidImagePixelCount(_ pixelCount: Int) -> Bool {
        return pixelCount <= maxImagePixels
    }
    
    // MARK: - Security Headers
    
    static let securityHeaders = [
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Content-Security-Policy": "default-src 'self'; img-src 'self' data: https:; script-src 'self'"
    ]
    
    // MARK: - Rate Limiting
    
    static let rateLimitConfig = [
        "upload": (requests: 10, window: 60), // 10 uploads per minute
        "login": (requests: 5, window: 300),   // 5 login attempts per 5 minutes
        "api": (requests: 100, window: 60)     // 100 API calls per minute
    ]
    
    // MARK: - Audit Logging
    
    static let auditEvents = [
        "user_login",
        "user_logout", 
        "file_upload",
        "file_download",
        "consent_given",
        "consent_revoked",
        "data_deleted",
        "security_violation"
    ]
    
    // MARK: - Environment Checks
    
    static var isProduction: Bool {
        return ProcessInfo.processInfo.environment["APP_ENVIRONMENT"] == "production"
    }
    
    static var isDebugMode: Bool {
        return ProcessInfo.processInfo.environment["DEBUG_MODE"] == "true"
    }
    
    // MARK: - Security Validation
    
    static func validateSecurityRequirements() -> [String] {
        var issues: [String] = []
        
        // Check if running in production with debug mode
        if isProduction && isDebugMode {
            issues.append("Debug mode enabled in production")
        }
        
        // Check for hardcoded secrets
        if Secrets.supabaseURL.contains("your-project-id") {
            issues.append("Supabase URL not configured")
        }
        
        if Secrets.supabaseAnonKey.contains("your-anon-key") {
            issues.append("Supabase API key not configured")
        }
        
        return issues
    }
}

// MARK: - Security Event Logger

class SecurityEventLogger {
    static let shared = SecurityEventLogger()
    
    private init() {}
    
    func logSecurityEvent(_ event: String, details: [String: Any] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = [
            "timestamp": timestamp,
            "event": event,
            "details": details,
            "environment": SecurityConfig.isProduction ? "production" : "development"
        ]
        
        // In production, this would send to a security monitoring service
        if SecurityConfig.isProduction {
            // NOTE: Security monitoring service integration planned for production
            logInfo("SECURITY EVENT: \(event) - \(details)")
        } else {
            logInfo("SECURITY EVENT: \(event) - \(details)")
        }
    }
    
    func logSecurityViolation(_ violation: String, severity: SecurityViolationSeverity, details: [String: Any] = [:]) {
        let eventDetails = details.merging([
            "severity": severity.rawValue,
            "violation_type": violation
        ]) { _, new in new }
        
        logSecurityEvent("security_violation", details: eventDetails)
        
        // For critical violations, take immediate action
        if severity == .critical {
            // NOTE: Immediate security response system planned for production
            logError("CRITICAL SECURITY VIOLATION: \(violation)")
        }
    }
}

// MARK: - Security Violation Severity

enum SecurityViolationSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var shouldBlock: Bool {
        return self == .high || self == .critical
    }
    
    var shouldAlert: Bool {
        return self == .critical
    }
}
