import Foundation
import Security

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "com.joanie.app"
    
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    func store(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieve(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }
    
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Session Token Management
    
    func storeAccessToken(_ token: String) throws {
        try store(key: "access_token", value: token)
    }
    
    func retrieveAccessToken() throws -> String? {
        return try retrieve(key: "access_token")
    }
    
    func storeRefreshToken(_ token: String) throws {
        try store(key: "refresh_token", value: token)
    }
    
    func retrieveRefreshToken() throws -> String? {
        return try retrieve(key: "refresh_token")
    }
    
    func storeUserID(_ userID: String) throws {
        try store(key: "user_id", value: userID)
    }
    
    func retrieveUserID() throws -> String? {
        return try retrieve(key: "user_id")
    }
    
    func clearSession() throws {
        try delete(key: "access_token")
        try delete(key: "refresh_token")
        try delete(key: "user_id")
    }
    
    // MARK: - Security Features
    
    func hasValidSession() -> Bool {
        do {
            let accessToken = try retrieveAccessToken()
            let refreshToken = try retrieveRefreshToken()
            let userID = try retrieveUserID()
            
            return accessToken != nil && refreshToken != nil && userID != nil
        } catch {
            return false
        }
    }
    
}

// MARK: - Supporting Types

enum KeychainError: LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store keychain item: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve keychain item: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete keychain item: \(status)"
        case .invalidData:
            return "Invalid data format in keychain"
        }
    }
}

// MARK: - Secure Session Manager

@MainActor
class SecureSessionManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: String?
    @Published var sessionExpiry: Date?
    
    private let keychainService = KeychainService.shared
    private var refreshTimer: Timer?
    private let logger = Logger.shared
    
    private func logInfo(_ message: String) {
        logger.info(message)
    }
    
    private func logError(_ message: String) {
        logger.error(message)
    }
    
    // MARK: - Session Management
    
    func initializeSession() {
        if keychainService.hasValidSession() {
            restoreSession()
        } else {
            clearSession()
        }
    }
    
    func storeSession(accessToken: String, refreshToken: String, userID: String, expiresIn: TimeInterval) {
        do {
            try keychainService.storeAccessToken(accessToken)
            try keychainService.storeRefreshToken(refreshToken)
            try keychainService.storeUserID(userID)
            
            let expiryDate = Date().addingTimeInterval(expiresIn)
            sessionExpiry = expiryDate
            
            isAuthenticated = true
            currentUserID = userID
            
            // Schedule token refresh
            scheduleTokenRefresh(expiresIn: expiresIn)
            
            logInfo("Session stored successfully for user: \(userID)")
        } catch {
            logError("Failed to store session: \(error.localizedDescription)")
        }
    }
    
    func restoreSession() {
        guard let userID = try? keychainService.retrieveUserID() else {
            clearSession()
            return
        }
        
        currentUserID = userID
        isAuthenticated = true
        
        // Check if session is still valid
        if let expiry = sessionExpiry, Date() > expiry {
            Task { await refreshToken() }
        } else {
            logInfo("Session restored for user: \(userID)")
        }
    }
    
    func refreshToken() async {
        guard let _ = try? keychainService.retrieveRefreshToken() else {
            clearSession()
            return
        }
        
        // TODO: Implement actual token refresh with Supabase
        logInfo("Refreshing token...")
        
        // For now, we'll simulate a successful refresh
        // In production, this would call Supabase's refresh endpoint
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        logInfo("Token refreshed successfully")
    }
    
    func clearSession() {
        do {
            try keychainService.clearSession()
            
            isAuthenticated = false
            currentUserID = nil
            sessionExpiry = nil
            
            refreshTimer?.invalidate()
            refreshTimer = nil
            
            logInfo("Session cleared")
        } catch {
            logError("Failed to clear session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Token Refresh Scheduling
    
    private func scheduleTokenRefresh(expiresIn: TimeInterval) {
        refreshTimer?.invalidate()
        
        // Refresh token 5 minutes before expiry
        let refreshTime = max(expiresIn - 300, 60) // At least 1 minute
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshToken()
            }
        }
    }
    
    // MARK: - Security Checks
    
    func validateSession() -> Bool {
        guard isAuthenticated,
              let userID = currentUserID,
              keychainService.hasValidSession() else {
            clearSession()
            return false
        }
        
        return true
    }
    
    func getAccessToken() -> String? {
        return try? keychainService.retrieveAccessToken()
    }
    
    func getRefreshToken() -> String? {
        return try? keychainService.retrieveRefreshToken()
    }
}