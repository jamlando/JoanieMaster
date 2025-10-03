//
//  ResendAPIClient.swift
//  Joanie
//
//  Resend API Client
//  Handles all HTTP communication with Resend email service API
//

import Foundation

// MARK: - Configuration Utilities

private struct ConfigUtils {
    static func getTimeout() -> Int {
        return Secrets.resendTimeoutSeconds
    }
    
    static func isProduction() -> Bool {
        return Secrets.isProduction
    }
    
    static func getMaxRetries() -> Int {
        return Secrets.resendMaxRetries
    }
}

// MARK: - Resend API Client

@MainActor
class ResendAPIClient: ObservableObject {
    // MARK: - Configuration
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var lastResponseTime: TimeInterval = 0
    @Published var connectionStatus: APIConnectionStatus = .unknown
    
    // MARK: - Initialization
    init(apiKey: String, baseURL: String = "https://api.resend.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        // Use production-specific timeouts
        config.timeoutIntervalForRequest = TimeInterval(ConfigUtils.getTimeout())
        config.timeoutIntervalForResource = TimeInterval(ConfigUtils.getTimeout() * 2)
        config.httpMaximumConnectionsPerHost = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        // Production security configurations
        if ConfigUtils.isProduction() {
            config.tlsMinimumSupportedProtocol = .TLSv12
            config.waitsForConnectivity = true
        }
        
        self.session = URLSession(configuration: config)
        
        validateConnection()
    }
    
    // MARK: - Public Methods
    
    /// Send email via Resend API
    func sendEmail(_ email: ResendEmailRequest) async throws -> ResendEmailResponse {
        let startTime = Date()
        
        do {
            let request = try createEmailRequest(email)
            let (data, response) = try await session.data(for: request)
            
            lastResponseTime = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.invalidResponse
            }
            
            handleHTTPResponse(httpResponse, data: data)
            
            let emailResponse = try JSONDecoder().decode(ResendEmailResponse.self, from: data)
            
            Logger.shared.info("Email sent successfully via Resend", metadata: [
                "messageId": emailResponse.id ?? "",
                "responseTime": String(lastResponseTime)
            ])
            
            return emailResponse
            
        } catch let error as EmailError {
            throw error
        } catch {
            throw EmailError.fromNetworkError(error)
        }
    }
    
    /// Validate API key and connection
    func validateAPIKey() async throws -> Bool {
        do {
            let request = try createValidationRequest()
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.invalidResponse
            }
            
            isConnected = httpResponse.statusCode == 200
            connectionStatus = isConnected ? .connected : .error(httpResponse.statusCode)
            
            return isConnected
            
        } catch {
            isConnected = false
            connectionStatus = .error(0)
            throw EmailError.fromNetworkError(error)
        }
    }
    
    /// Get email status/delivery information
    func getEmailStatus(messageId: String) async throws -> ResendEmailStatus {
        let request = try createStatusRequest(messageId: messageId)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw EmailError.fromHTTPResponse(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try JSONDecoder().decode(ResendEmailStatus.self, from: data)
    }
    
    /// Check API quota and limits
    func getAPILimits() async throws -> ResendAPILimits {
        let request = try createLimitsRequest()
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw EmailError.fromHTTPResponse(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }
        
        return try JSONDecoder().decode(ResendAPILimits.self, from: data)
    }
    
    // MARK: - Private Methods
    
    private func validateConnection() {
        Task {
            do {
                _ = try await validateAPIKey()
            } catch {
                Logger.shared.error("Failed to validate Resend API connection: \(error)")
            }
        }
    }
    
    private func createEmailRequest(_ email: ResendEmailRequest) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/emails") else {
            throw EmailError.invalidConfiguration("Invalid API base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Production-specific headers
        let appVersion = ConfigUtils.isProduction() ? "1.0.0" : "1.0.0-dev"
        request.setValue("Joanie-iOS/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        // Add request tracking headers for production monitoring
        if ConfigUtils.isProduction() {
            let requestId = UUID().uuidString
            request.setValue(requestId, forHTTPHeaderField: "X-Request-ID")
            request.setValue("production", forHTTPHeaderField: "X-Environment")
        } else {
            request.setValue("development", forHTTPHeaderField: "X-Environment")
        }
        
        let encodedEmail = try JSONEncoder().encode(email)
        request.httpBody = encodedEmail
        
        // Set timeout explicitly
        request.timeoutInterval = TimeInterval(ConfigUtils.getTimeout())
        
        return request
    }
    
    private func createValidationRequest() throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/domains") else {
            throw EmailError.invalidConfiguration("Invalid API base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func createStatusRequest(messageId: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/emails/\(messageId)") else {
            throw EmailError.invalidConfiguration("Invalid API base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func createLimitsRequest() throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/limits") else {
            throw EmailError.invalidConfiguration("Invalid API base URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        
        // Log response for monitoring
        Logger.shared.info("Resend API Response", metadata: [
            "statusCode": "\(response.statusCode)",
            "responseSize": "\(data.count)",
            "environment": ConfigUtils.isProduction() ? "production" : "development"
        ])
        
        guard response.statusCode == 200 else {
            // Enhanced production error handling
            switch response.statusCode {
            case 400:
                Logger.shared.error("Resend API Bad Request", metadata: [
                    "status": "\(response.statusCode)",
                    "message": errorMessage
                ])
                throw EmailError.invalidConfiguration(errorMessage)
                
            case 401:
                Logger.shared.error("Authentication Failed - Invalid Resend API Key", metadata: [
                    "status": "\(response.statusCode)"
                ])
                throw EmailError.authenticationFailed
                
            case 403:
                Logger.shared.error("Resend API Forbidden", metadata: [
                    "status": "\(response.statusCode)",
                    "message": errorMessage
                ])
                throw EmailError.serviceUnavailable("API access forbidden")
                
            case 429:
                Logger.shared.warning("Rate Limit Exceeded", metadata: [
                    "status": "\(response.statusCode)",
                    "message": errorMessage
                ])
                throw EmailError.rateLimited
                
            case 500...599:
                Logger.shared.error("Resend Server Error", metadata: [
                    "status": "\(response.statusCode)",
                    "message": errorMessage
                ])
                throw EmailError.serverError(response.statusCode, errorMessage)
                
            default:
                Logger.shared.error("Unknown Resend API Error", metadata: [
                    "status": "\(response.statusCode)",
                    "message": errorMessage
                ])
                throw EmailError.unknownError(errorMessage)
            }
        }
        
        // Success logging for production monitoring
        if ConfigUtils.isProduction() {
            Logger.shared.info("Email sent successfully via Resend", metadata: [
                "responseTime": String(lastResponseTime),
                "statusCode": "\(response.statusCode)"
            ])
        }
    }
}

// MARK: - Supporting Types

/// API connection status tracking
enum APIConnectionStatus: Equatable {
    case unknown
    case connected
    case error(Int)
    case disconnected
    
    var isHealthy: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    var displayValue: String {
        switch self {
        case .unknown: return "Unknown"
        case .connected: return "Connected"
        case .error(let code): return "Error (\(code))"
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - Resend API Models

/// Resend email request structure
struct ResendEmailRequest: Codable {
    let from: String
    let to: [String]
    let cc: [String]?
    let bcc: [String]?
    let subject: String
    let html: String?
    let text: String?
    let attachments: [ResendAttachment]?
    let tags: [ResendTag]?
    let react: ResendReactTemplate?
    
    init(from email: EmailMessage, templateContent: EmailTemplateContent? = nil) {
        self.from = email.metadata.priority.rawValue == "urgent" ? "urgent@\(Secrets.resendDomain)" : Secrets.emailFromAddress
        self.to = email.to
        self.cc = email.cc
        self.bcc = email.bcc
        self.subject = email.subject
        
        // Set content based on email content type
        switch email.content {
        case .text(let text):
            self.text = text
            self.html = nil
        case .html(let html):
            self.html = html
            self.text = nil
        case .template(_, let data):
            // Template content should be pre-rendered
            if let templateContent = templateContent {
                self.html = templateContent.htmlBody
                self.text = templateContent.textBody
            } else {
                self.html = nil
                self.text = nil
            }
        }
        
        // Convert attachments
        self.attachments = email.attachments?.map { attachment in
            ResendAttachment(
                content: attachment.data.base64EncodedString(),
                filename: attachment.filename,
                contentType: attachment.contentType
            )
        }
        
        // Convert tags
        self.tags = email.metadata.tags?.map { tag in
            ResendTag(name: tag, value: email.metadata.priority.rawValue)
        }
        
        self.react = nil
    }
}

/// Resend email response structure
struct ResendEmailResponse: Codable {
    let id: String?
    let from: String?
    let to: [String]?
    let createdAt: String?
    let subject: String?
    let html: String?
    let text: String?
    let bcc: [String]?
    let cc: [String]?
    let replyTo: [String]?
    let lastEvent: String?
}

/// Resend email status structure
struct ResendEmailStatus: Codable {
    let id: String
    let status: String
    let from: String
    let to: String
    let subject: String
    let createdAt: Date
    let lastEvent: String?
    let deliveredAt: Date?
    let failedAt: Date?
    let error: String?
}

/// Resend attachment structure
struct ResendAttachment: Codable {
    let content: String // Base64 encoded
    let filename: String
    let contentType: String?
}

/// Resend tag structure
struct ResendTag: Codable {
    let name: String
    let value: String
}

/// Resend React template structure (for template-based emails)
struct ResendReactTemplate: Codable {
    let component: String
    let props: [String: String]
}

/// Resend API limits structure
struct ResendAPILimits: Codable {
    let monthlyLimit: Int?
    let dailyLimit: Int?
    let hourlyLimit: Int?
    let currentUsage: Int?
    let resetDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case monthlyLimit = "monthly_limit"
        case dailyLimit = "daily_limit"
        case hourlyLimit = "hourly_limit"
        case currentUsage = "current_usage"
        case resetDate = "reset_date"
    }
}

// MARK: - Error Extensions

extension EmailError {
    /// Create unknown error for HTTP responses
    static func unknownError(_ message: String? = nil) -> EmailError {
        return .serverError(0, message)
    }
}
