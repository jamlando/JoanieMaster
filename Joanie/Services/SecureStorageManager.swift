import Foundation
import CoreData
import Security

// MARK: - Secure Storage Manager

/// Manages secure storage for feature toggles and sensitive data
@MainActor
class SecureStorageManager: ObservableObject {
    
    // MARK: - Dependencies
    
    private let keychainService: KeychainService
    private let coreDataManager: CoreDataManager
    private let logger: Logger
    
    // MARK: - Configuration
    
    private let encryptionKeyTag = "com.joanie.featuretoggles.encryption"
    private let featureToggleKeyPrefix = "feature_toggle_"
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainService = KeychainService.shared,
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        logger: Logger = Logger.shared
    ) {
        self.keychainService = keychainService
        self.coreDataManager = coreDataManager
        self.logger = logger
        
        setupEncryption()
    }
    
    // MARK: - Public Methods
    
    /// Stores a feature toggle securely
    func storeFeatureToggle<T: FeatureToggle>(_ toggle: T) async throws {
        // Store in encrypted Core Data
        try await storeInEncryptedCoreData(toggle)
        
        // Store sensitive metadata in Keychain if needed
        if let metadata = toggle.metadata {
            try await storeMetadataInKeychain(toggleId: toggle.id, metadata: metadata)
        }
        
        logger.info("Feature toggle stored securely: \(toggle.id)")
    }
    
    /// Retrieves a feature toggle securely
    func retrieveFeatureToggle(id: String) async throws -> (any FeatureToggle)? {
        // Retrieve from encrypted Core Data
        let toggle = try await retrieveFromEncryptedCoreData(id: id)
        
        // Retrieve sensitive metadata from Keychain if needed
        if let metadata = try? await retrieveMetadataFromKeychain(toggleId: id) {
            // Merge metadata with toggle
            // This would require updating the toggle with the retrieved metadata
        }
        
        return toggle
    }
    
    /// Removes a feature toggle securely
    func removeFeatureToggle(id: String) async throws {
        // Remove from encrypted Core Data
        try await removeFromEncryptedCoreData(id: id)
        
        // Remove sensitive metadata from Keychain
        try await removeMetadataFromKeychain(toggleId: id)
        
        logger.info("Feature toggle removed securely: \(id)")
    }
    
    /// Stores user targeting data securely
    func storeUserTargetingData(userId: String, data: [String: Any]) async throws {
        let key = "user_targeting_\(userId)"
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let encryptedData = try encryptData(jsonData)
        
        try keychainService.store(key: key, value: encryptedData.base64EncodedString())
        logger.info("User targeting data stored securely for user: \(userId)")
    }
    
    /// Retrieves user targeting data securely
    func retrieveUserTargetingData(userId: String) async throws -> [String: Any]? {
        let key = "user_targeting_\(userId)"
        
        guard let encryptedString = try keychainService.retrieve(key: key),
              let encryptedData = Data(base64Encoded: encryptedString) else {
            return nil
        }
        
        let decryptedData = try decryptData(encryptedData)
        return try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any]
    }
    
    /// Clears all secure data for a user
    func clearUserData(userId: String) async throws {
        // Clear user targeting data
        try keychainService.delete(key: "user_targeting_\(userId)")
        
        // Clear user-specific toggles from Core Data
        try await clearUserTogglesFromCoreData(userId: userId)
        
        logger.info("User data cleared securely for user: \(userId)")
    }
    
    /// Generates a secure encryption key
    func generateEncryptionKey() throws -> Data {
        var keyData = Data(count: 32) // 256-bit key
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw SecureStorageError.keyGenerationFailed
        }
        
        return keyData
    }
    
    // MARK: - Private Methods
    
    private func setupEncryption() {
        // Ensure encryption key exists in Keychain
        do {
            _ = try getEncryptionKey()
        } catch {
            do {
                let newKey = try generateEncryptionKey()
                try storeEncryptionKey(newKey)
                logger.info("New encryption key generated and stored")
            } catch {
                logger.error("Failed to generate encryption key: \(error.localizedDescription)")
            }
        }
    }
    
    private func getEncryptionKey() throws -> Data {
        guard let keyString = try keychainService.retrieve(key: encryptionKeyTag),
              let keyData = Data(base64Encoded: keyString) else {
            throw SecureStorageError.keyNotFound
        }
        return keyData
    }
    
    private func storeEncryptionKey(_ keyData: Data) throws {
        try keychainService.store(key: encryptionKeyTag, value: keyData.base64EncodedString())
    }
    
    private func encryptData(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        
        // Use AES encryption
        let cryptedData = NSMutableData(length: data.count + kCCBlockSizeAES128)!
        let keyLength = size_t(kCCKeySizeAES256)
        let operation: CCOperation = UInt32(kCCEncrypt)
        let algorithm: CCAlgorithm = UInt32(kCCAlgorithmAES128)
        let options: CCOptions = UInt32(kCCOptionPKCS7Padding)
        
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = CCCrypt(
            operation,
            algorithm,
            options,
            key.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress },
            keyLength,
            nil,
            data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress },
            data.count,
            cryptedData.mutableBytes,
            cryptedData.length,
            &numBytesEncrypted
        )
        
        guard cryptStatus == kCCSuccess else {
            throw SecureStorageError.encryptionFailed
        }
        
        cryptedData.length = numBytesEncrypted
        return cryptedData as Data
    }
    
    private func decryptData(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        
        let cryptedData = NSMutableData(length: data.count)!
        let keyLength = size_t(kCCKeySizeAES256)
        let operation: CCOperation = UInt32(kCCDecrypt)
        let algorithm: CCAlgorithm = UInt32(kCCAlgorithmAES128)
        let options: CCOptions = UInt32(kCCOptionPKCS7Padding)
        
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = CCCrypt(
            operation,
            algorithm,
            options,
            key.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress },
            keyLength,
            nil,
            data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress },
            data.count,
            cryptedData.mutableBytes,
            cryptedData.length,
            &numBytesDecrypted
        )
        
        guard cryptStatus == kCCSuccess else {
            throw SecureStorageError.decryptionFailed
        }
        
        cryptedData.length = numBytesDecrypted
        return cryptedData as Data
    }
    
    // MARK: - Core Data Methods
    
    private func storeInEncryptedCoreData<T: FeatureToggle>(_ toggle: T) async throws {
        let context = coreDataManager.viewContext
        
        // Check if entity already exists
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", toggle.id)
        
        let existingEntities = try context.fetch(request)
        let entity = existingEntities.first ?? FeatureToggleEntity(context: context)
        
        // Update entity with encrypted data
        entity.id = toggle.id
        entity.name = toggle.name
        entity.toggleDescription = toggle.description
        entity.isEnabled = toggle.isEnabled
        entity.scope = toggle.scope.rawValue
        entity.experimentId = toggle.experimentId
        entity.variant = toggle.variant
        entity.createdAt = toggle.createdAt
        entity.updatedAt = toggle.updatedAt
        entity.expiresAt = toggle.expiresAt
        entity.toggleType = String(describing: T.self)
        entity.needsSync = true
        
        // Encrypt metadata if present
        if let metadata = toggle.metadata {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            entity.metadata = try encryptData(metadataData)
        } else {
            entity.metadata = nil
        }
        
        try context.save()
    }
    
    private func retrieveFromEncryptedCoreData(id: String) async throws -> (any FeatureToggle)? {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        let entities = try context.fetch(request)
        guard let entity = entities.first else { return nil }
        
        return try entity.toFeatureToggle(decryptMetadata: { [weak self] data in
            guard let self = self else { return data }
            return try self.decryptData(data)
        })
    }
    
    private func removeFromEncryptedCoreData(id: String) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        let entities = try context.fetch(request)
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
    }
    
    private func clearUserTogglesFromCoreData(userId: String) async throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "scope == %@ AND (metadata CONTAINS %@)", "user", userId)
        
        let entities = try context.fetch(request)
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
    }
    
    // MARK: - Keychain Methods
    
    private func storeMetadataInKeychain(toggleId: String, metadata: [String: Any]) async throws {
        let key = "\(featureToggleKeyPrefix)\(toggleId)"
        let jsonData = try JSONSerialization.data(withJSONObject: metadata)
        let encryptedData = try encryptData(jsonData)
        
        try keychainService.store(key: key, value: encryptedData.base64EncodedString())
    }
    
    private func retrieveMetadataFromKeychain(toggleId: String) async throws -> [String: Any]? {
        let key = "\(featureToggleKeyPrefix)\(toggleId)"
        
        guard let encryptedString = try keychainService.retrieve(key: key),
              let encryptedData = Data(base64Encoded: encryptedString) else {
            return nil
        }
        
        let decryptedData = try decryptData(encryptedData)
        return try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any]
    }
    
    private func removeMetadataFromKeychain(toggleId: String) async throws {
        let key = "\(featureToggleKeyPrefix)\(toggleId)"
        try keychainService.delete(key: key)
    }
}

// MARK: - Secure Storage Error

enum SecureStorageError: LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyNotFound:
            return "Encryption key not found in keychain"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .dataCorrupted:
            return "Data is corrupted or invalid"
        }
    }
}

// MARK: - Core Data Entity Extension

extension FeatureToggleEntity {
    func toFeatureToggle(decryptMetadata: @escaping (Data) throws -> Data) throws -> (any FeatureToggle)? {
        guard let id = id,
              let name = name,
              let description = toggleDescription,
              let scope = scope,
              let createdAt = createdAt,
              let updatedAt = updatedAt else {
            return nil
        }
        
        let scopeEnum = ToggleScope(rawValue: scope) ?? .global
        
        // Decrypt metadata if present
        var decryptedMetadata: [String: Any]? = nil
        if let metadata = metadata {
            let decryptedData = try decryptMetadata(metadata)
            decryptedMetadata = try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any]
        }
        
        switch toggleType {
        case "NotificationToggle":
            return NotificationToggle(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                scope: scopeEnum,
                experimentId: experimentId,
                variant: variant,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                metadata: decryptedMetadata
            )
        default:
            return BaseFeatureToggle(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                scope: scopeEnum,
                experimentId: experimentId,
                variant: variant,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                metadata: decryptedMetadata
            )
        }
    }
}

// MARK: - Security Configuration

extension SecureStorageManager {
    /// Validates the security configuration
    func validateSecurityConfiguration() -> Bool {
        do {
            // Check if encryption key exists
            _ = try getEncryptionKey()
            
            // Check if keychain is accessible
            _ = try keychainService.retrieve(key: "test_key")
            
            // Check if Core Data is properly configured
            let context = coreDataManager.viewContext
            _ = try context.existingObject(with: NSManagedObjectID())
            
            return true
        } catch {
            logger.error("Security configuration validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Performs security audit
    func performSecurityAudit() async -> SecurityAuditResult {
        var issues: [SecurityIssue] = []
        
        // Check encryption key strength
        do {
            let key = try getEncryptionKey()
            if key.count < 32 {
                issues.append(SecurityIssue(
                    type: .weakEncryption,
                    severity: .high,
                    description: "Encryption key is too short"
                ))
            }
        } catch {
            issues.append(SecurityIssue(
                type: .missingEncryptionKey,
                severity: .critical,
                description: "Encryption key not found"
            ))
        }
        
        // Check for unencrypted sensitive data
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                if entity.scope == "user" && entity.metadata == nil {
                    issues.append(SecurityIssue(
                        type: .unencryptedSensitiveData,
                        severity: .medium,
                        description: "User-specific toggle without encrypted metadata"
                    ))
                }
            }
        } catch {
            issues.append(SecurityIssue(
                type: .dataAccessError,
                severity: .high,
                description: "Failed to access Core Data"
            ))
        }
        
        return SecurityAuditResult(
            timestamp: Date(),
            issues: issues,
            isSecure: issues.isEmpty
        )
    }
}

// MARK: - Security Audit Types

struct SecurityAuditResult {
    let timestamp: Date
    let issues: [SecurityIssue]
    let isSecure: Bool
}

struct SecurityIssue {
    let type: SecurityIssueType
    let severity: SecuritySeverity
    let description: String
}

enum SecurityIssueType {
    case weakEncryption
    case missingEncryptionKey
    case unencryptedSensitiveData
    case dataAccessError
    case keychainAccessError
}

enum SecuritySeverity {
    case low
    case medium
    case high
    case critical
}
