import Foundation
import CoreData
import Combine

// MARK: - Feature Toggle Service

/// Service responsible for managing feature toggles with local storage and remote sync capabilities
class FeatureToggleService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var toggles: [String: any FeatureToggle] = [:]
    @Published var isLoading: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    private let keychainService: KeychainService
    private let logger: Logger
    
    // MARK: - Configuration
    
    private let userDefaults = UserDefaults.standard
    private let togglesKey = "feature_toggles"
    private let lastSyncKey = "last_toggle_sync"
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        keychainService: KeychainService = KeychainService.shared,
        logger: Logger = Logger.shared
    ) {
        self.coreDataManager = coreDataManager
        self.keychainService = keychainService
        self.logger = logger
        
        Task {
            await loadTogglesFromStorage()
        }
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Retrieves a feature toggle by ID
    func getToggle<T: FeatureToggle>(id: String, as type: T.Type) -> T? {
        return toggles[id] as? T
    }
    
    /// Checks if a feature toggle is enabled
    func isToggleEnabled(id: String) -> Bool {
        guard let toggle = toggles[id] else { return false }
        return toggle.isEnabled && toggle.isActive
    }
    
    /// Sets the enabled state of a feature toggle
    func setToggleEnabled(id: String, enabled: Bool) async {
        guard var toggle = toggles[id] else {
            logger.error("Toggle not found: \(id)")
            return
        }
        
        toggle.isEnabled = enabled
        toggle = toggle.withUpdatedTimestamp()
        
        toggles[id] = toggle
        
        // Save to both UserDefaults and Core Data
        await saveToggleToStorage(toggle)
        await saveToggleToCoreData(toggle)
        
        logger.info("Toggle \(id) set to \(enabled)")
    }
    
    /// Adds or updates a feature toggle
    func setToggle<T: FeatureToggle>(_ toggle: T) async {
        toggles[toggle.id] = toggle
        
        // Save to both UserDefaults and Core Data
        await saveToggleToStorage(toggle)
        await saveToggleToCoreData(toggle)
        
        logger.info("Toggle \(toggle.id) saved")
    }
    
    /// Removes a feature toggle
    func removeToggle(id: String) async {
        toggles.removeValue(forKey: id)
        
        // Remove from both UserDefaults and Core Data
        await removeToggleFromStorage(id: id)
        await removeToggleFromCoreData(id: id)
        
        logger.info("Toggle \(id) removed")
    }
    
    /// Syncs toggles with remote server
    func syncToggles() async {
        isLoading = true
        syncError = nil
        
        do {
            // TODO: Implement remote sync with Supabase
            // For now, we'll simulate a successful sync
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            lastSyncDate = Date()
            userDefaults.set(lastSyncDate, forKey: lastSyncKey)
            
            logger.info("Toggles synced successfully")
        } catch {
            syncError = error.localizedDescription
            logger.error("Toggle sync failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Loads all toggles from local storage
    func loadTogglesFromStorage() async {
        // Load from UserDefaults first (fastest)
        loadTogglesFromUserDefaults()
        
        // Then load from Core Data (more comprehensive)
        await loadTogglesFromCoreData()
        
        logger.info("Loaded \(toggles.count) toggles from storage")
    }
    
    /// Clears all toggles (for testing or reset)
    func clearAllToggles() async {
        toggles.removeAll()
        
        // Clear from both storage systems
        await clearTogglesFromStorage()
        await clearTogglesFromCoreData()
        
        logger.info("All toggles cleared")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleCoreDataSave()
            }
        }
    }
    
    private func handleCoreDataSave() async {
        // Reload toggles from Core Data when changes occur
        await loadTogglesFromCoreData()
    }
    
    // MARK: - UserDefaults Storage
    
    private func loadTogglesFromUserDefaults() {
        guard let data = userDefaults.data(forKey: togglesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            let toggleData = try decoder.decode([String: ToggleData].self, from: data)
            
            for (id, data) in toggleData {
                if let toggle = data.toFeatureToggle() {
                    toggles[id] = toggle
                }
            }
        } catch {
            logger.error("Failed to load toggles from UserDefaults: \(error.localizedDescription)")
        }
    }
    
    private func saveToggleToStorage<T: FeatureToggle>(_ toggle: T) async {
        do {
            let encoder = JSONEncoder()
            let toggleData = ToggleData(from: toggle)
            let data = try encoder.encode(toggleData)
            
            // Load existing toggles
            var allToggles: [String: ToggleData] = [:]
            if let existingData = userDefaults.data(forKey: togglesKey) {
                let decoder = JSONDecoder()
                allToggles = try decoder.decode([String: ToggleData].self, from: existingData)
            }
            
            // Update with new toggle
            allToggles[toggle.id] = toggleData
            
            // Save back to UserDefaults
            let updatedData = try encoder.encode(allToggles)
            userDefaults.set(updatedData, forKey: togglesKey)
            
        } catch {
            logger.error("Failed to save toggle to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    private func removeToggleFromStorage(id: String) async {
        guard let data = userDefaults.data(forKey: togglesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            var allToggles = try decoder.decode([String: ToggleData].self, from: data)
            
            allToggles.removeValue(forKey: id)
            
            let encoder = JSONEncoder()
            let updatedData = try encoder.encode(allToggles)
            userDefaults.set(updatedData, forKey: togglesKey)
            
        } catch {
            logger.error("Failed to remove toggle from UserDefaults: \(error.localizedDescription)")
        }
    }
    
    private func clearTogglesFromStorage() async {
        userDefaults.removeObject(forKey: togglesKey)
        userDefaults.removeObject(forKey: lastSyncKey)
    }
    
    // MARK: - Core Data Storage
    
    private func loadTogglesFromCoreData() async {
        let context = await coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest() as! NSFetchRequest<FeatureToggleEntity>
        
        do {
            let entities = try context.fetch(request)
            
            for entity in entities {
                if let toggle = entity.toFeatureToggle() {
                    toggles[toggle.id] = toggle
                }
            }
        } catch {
            logger.error("Failed to load toggles from Core Data: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func saveToggleToCoreData<T: FeatureToggle>(_ toggle: T) async {
        let context = await coreDataManager.viewContext
        
        // Check if entity already exists
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest() as! NSFetchRequest<FeatureToggleEntity>
        request.predicate = NSPredicate(format: "id == %@", toggle.id)
        
        do {
            let existingEntities = try context.fetch(request)
            let entity = existingEntities.first ?? FeatureToggleEntity(context: context)
            
            entity.updateFrom(toggle)
            
            try context.save()
        } catch {
            logger.error("Failed to save toggle to Core Data: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func removeToggleFromCoreData(id: String) async {
        let context = await coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest() as! NSFetchRequest<FeatureToggleEntity>
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        } catch {
            logger.error("Failed to remove toggle from Core Data: \(error.localizedDescription)")
        }
    }
    
    private func clearTogglesFromCoreData() async {
        let context = await coreDataManager.viewContext
        let request: NSFetchRequest<FeatureToggleEntity> = FeatureToggleEntity.fetchRequest() as! NSFetchRequest<FeatureToggleEntity>
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        } catch {
            logger.error("Failed to clear toggles from Core Data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// Data structure for serializing feature toggles
private struct ToggleData: Codable {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let scope: String
    let experimentId: String?
    let variant: String?
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let metadata: Data?
    let toggleType: String
    
    init<T: FeatureToggle>(from toggle: T) {
        self.id = toggle.id
        self.name = toggle.name
        self.description = toggle.description
        self.isEnabled = toggle.isEnabled
        self.scope = toggle.scope.rawValue
        self.experimentId = toggle.experimentId
        self.variant = toggle.variant
        self.createdAt = toggle.createdAt
        self.updatedAt = toggle.updatedAt
        self.expiresAt = toggle.expiresAt
        self.toggleType = String(describing: T.self)
        
        if let metadata = toggle.metadata {
            self.metadata = try? JSONSerialization.data(withJSONObject: metadata)
        } else {
            self.metadata = nil
        }
    }
    
    func toFeatureToggle() -> (any FeatureToggle)? {
        switch toggleType {
        case "NotificationToggle":
            return NotificationToggle(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                scope: ToggleScope(rawValue: scope) ?? .global,
                experimentId: experimentId,
                variant: variant,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                metadata: metadata != nil ? try? JSONSerialization.jsonObject(with: metadata!) as? [String: String] : nil
            )
        default:
            return BaseFeatureToggle(
                id: id,
                name: name,
                description: description,
                isEnabled: isEnabled,
                scope: ToggleScope(rawValue: scope) ?? .global,
                experimentId: experimentId,
                variant: variant,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                metadata: metadata != nil ? try? JSONSerialization.jsonObject(with: metadata!) as? [String: String] : nil
            )
        }
    }
}

// MARK: - Core Data Entity

@objc(FeatureToggleEntity)
class FeatureToggleEntity: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var name: String?
    @NSManaged var toggleDescription: String?
    @NSManaged var isEnabled: Bool
    @NSManaged var scope: String?
    @NSManaged var experimentId: String?
    @NSManaged var variant: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var expiresAt: Date?
    @NSManaged var metadata: Data?
    @NSManaged var toggleType: String?
    @NSManaged var needsSync: Bool
    
    func updateFrom<T: FeatureToggle>(_ toggle: T) {
        self.id = toggle.id
        self.name = toggle.name
        self.toggleDescription = toggle.description
        self.isEnabled = toggle.isEnabled
        self.scope = toggle.scope.rawValue
        self.experimentId = toggle.experimentId
        self.variant = toggle.variant
        self.createdAt = toggle.createdAt
        self.updatedAt = toggle.updatedAt
        self.expiresAt = toggle.expiresAt
        self.toggleType = String(describing: T.self)
        self.needsSync = true
        
        if let metadata = toggle.metadata {
            self.metadata = try? JSONSerialization.data(withJSONObject: metadata)
        } else {
            self.metadata = nil
        }
    }
    
    func toFeatureToggle() -> (any FeatureToggle)? {
        guard let id = id,
              let name = name,
              let description = toggleDescription,
              let scope = scope,
              let createdAt = createdAt,
              let updatedAt = updatedAt else {
            return nil
        }
        
        let scopeEnum = ToggleScope(rawValue: scope) ?? .global
        
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
                metadata: metadata != nil ? try? JSONSerialization.jsonObject(with: metadata!) as? [String: String] : nil
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
                metadata: metadata != nil ? try? JSONSerialization.jsonObject(with: metadata!) as? [String: String] : nil
            )
        }
    }
}
