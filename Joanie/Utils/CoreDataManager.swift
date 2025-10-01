import Foundation
import CoreData
import Combine

// MARK: - Core Data Manager

@MainActor
class CoreDataManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Published Properties
    @Published var isOfflineMode: Bool = false
    @Published var pendingSyncCount: Int = 0
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "JoanieDataModel")
        
        // Configure for offline support
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                logError("Core Data error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleContextDidSave(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRemoteChange(notification)
        }
    }
    
    // MARK: - Public Methods
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                logInfo("Core Data context saved successfully")
            } catch {
                logError("Core Data save error: \(error.localizedDescription)")
            }
        }
    }
    
    func saveContext() {
        save()
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Offline Support
    
    func enableOfflineMode() {
        isOfflineMode = true
        logInfo("Offline mode enabled")
    }
    
    func disableOfflineMode() {
        isOfflineMode = false
        logInfo("Offline mode disabled")
    }
    
    func syncPendingChanges() async {
        guard !isOfflineMode else { return }
        
        logInfo("Starting sync of pending changes")
        
        do {
            // Sync artwork
            await syncPendingArtwork()
            
            // Sync children
            await syncPendingChildren()
            
            // Sync stories
            await syncPendingStories()
            
            // Sync progress entries
            await syncPendingProgress()
            
            logInfo("Sync completed successfully")
        } catch {
            logError("Sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleContextDidSave(_ notification: Notification) {
        // Handle local context saves
        logInfo("Core Data context did save")
    }
    
    private func handleRemoteChange(_ notification: Notification) {
        // Handle remote changes from other devices
        logInfo("Core Data remote change detected")
        
        Task {
            await syncPendingChanges()
        }
    }
    
    private func syncPendingArtwork() async {
        // Sync pending artwork changes
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<ArtworkEntity> = ArtworkEntity.fetchRequest() as! NSFetchRequest<ArtworkEntity>
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let pendingArtwork = try context.fetch(request)
            for artwork in pendingArtwork {
                // Sync with Supabase
                await syncArtworkEntity(artwork)
            }
        } catch {
            logError("Failed to fetch pending artwork: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingChildren() async {
        // Sync pending children changes
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<ChildEntity> = ChildEntity.fetchRequest() as! NSFetchRequest<ChildEntity>
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let pendingChildren = try context.fetch(request)
            for child in pendingChildren {
                // Sync with Supabase
                await syncChildEntity(child)
            }
        } catch {
            logError("Failed to fetch pending children: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingStories() async {
        // Sync pending stories changes
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest() as! NSFetchRequest<StoryEntity>
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let pendingStories = try context.fetch(request)
            for story in pendingStories {
                // Sync with Supabase
                await syncStoryEntity(story)
            }
        } catch {
            logError("Failed to fetch pending stories: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingProgress() async {
        // Sync pending progress changes
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<ProgressEntity> = ProgressEntity.fetchRequest() as! NSFetchRequest<ProgressEntity>
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let pendingProgress = try context.fetch(request)
            for progress in pendingProgress {
                // Sync with Supabase
                await syncProgressEntity(progress)
            }
        } catch {
            logError("Failed to fetch pending progress: \(error.localizedDescription)")
        }
    }
    
    private func syncArtworkEntity(_ entity: ArtworkEntity) async {
        // Implement artwork sync logic
        logInfo("Syncing artwork entity: \(entity.id?.uuidString ?? "unknown")")
    }
    
    private func syncChildEntity(_ entity: ChildEntity) async {
        // Implement child sync logic
        logInfo("Syncing child entity: \(entity.id?.uuidString ?? "unknown")")
    }
    
    private func syncStoryEntity(_ entity: StoryEntity) async {
        // Implement story sync logic
        logInfo("Syncing story entity: \(entity.id?.uuidString ?? "unknown")")
    }
    
    private func syncProgressEntity(_ entity: ProgressEntity) async {
        // Implement progress sync logic
        logInfo("Syncing progress entity: \(entity.id?.uuidString ?? "unknown")")
    }
    
    // MARK: - Helper Methods
    
    func getPendingSyncCount() -> Int {
        let context = persistentContainer.viewContext
        
        let artworkRequest: NSFetchRequest<ArtworkEntity> = ArtworkEntity.fetchRequest() as! NSFetchRequest<ArtworkEntity>
        artworkRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let childRequest: NSFetchRequest<ChildEntity> = ChildEntity.fetchRequest() as! NSFetchRequest<ChildEntity>
        childRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let storyRequest: NSFetchRequest<StoryEntity> = StoryEntity.fetchRequest() as! NSFetchRequest<StoryEntity>
        storyRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let progressRequest: NSFetchRequest<ProgressEntity> = ProgressEntity.fetchRequest() as! NSFetchRequest<ProgressEntity>
        progressRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let artworkCount = try context.count(for: artworkRequest)
            let childCount = try context.count(for: childRequest)
            let storyCount = try context.count(for: storyRequest)
            let progressCount = try context.count(for: progressRequest)
            
            return artworkCount + childCount + storyCount + progressCount
        } catch {
            logError("Failed to count pending sync items: \(error.localizedDescription)")
            return 0
        }
    }
    
    func updatePendingSyncCount() {
        pendingSyncCount = getPendingSyncCount()
    }
}

// MARK: - Core Data Extensions

extension NSManagedObjectContext {
    func saveIfNeeded() {
        if hasChanges {
            do {
                try save()
            } catch {
                logError("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Core Data Entities

// These would be generated by Core Data model editor
// For now, we'll define them as placeholders

@objc(ArtworkEntity)
class ArtworkEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var childId: UUID?
    @NSManaged var userId: UUID?
    @NSManaged var title: String?
    @NSManaged var artworkDescription: String?
    @NSManaged var artworkType: String?
    @NSManaged var imageURL: String?
    @NSManaged var thumbnailURL: String?
    @NSManaged var fileSize: Int32
    @NSManaged var width: Int32
    @NSManaged var height: Int32
    @NSManaged var isFavorite: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var needsSync: Bool
}

@objc(ChildEntity)
class ChildEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var userId: UUID?
    @NSManaged var name: String?
    @NSManaged var birthDate: Date?
    @NSManaged var avatarURL: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var needsSync: Bool
}

@objc(StoryEntity)
class StoryEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var userId: UUID?
    @NSManaged var childId: UUID?
    @NSManaged var title: String?
    @NSManaged var content: String?
    @NSManaged var artworkIds: [UUID]?
    @NSManaged var status: String?
    @NSManaged var voiceURL: String?
    @NSManaged var pdfURL: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var needsSync: Bool
}

@objc(ProgressEntity)
class ProgressEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var childId: UUID?
    @NSManaged var userId: UUID?
    @NSManaged var skill: String?
    @NSManaged var level: String?
    @NSManaged var notes: String?
    @NSManaged var artworkId: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var needsSync: Bool
}

// MARK: - Core Data Model

// This would be created in the Core Data model editor
// For now, we'll provide a basic structure

/*
 Core Data Model: JoanieDataModel.xcdatamodeld

 Entities:
 - ArtworkEntity
 - ChildEntity
 - StoryEntity
 - ProgressEntity

 Relationships:
 - ChildEntity has many ArtworkEntity
 - ChildEntity has many StoryEntity
 - ChildEntity has many ProgressEntity
 - ArtworkEntity belongs to ChildEntity
 - StoryEntity belongs to ChildEntity
 - ProgressEntity belongs to ChildEntity

 Attributes:
 - All entities have: id (UUID), createdAt (Date), updatedAt (Date), needsSync (Boolean)
 - ArtworkEntity: title, description, type, imageURL, thumbnailURL, fileSize, width, height, isFavorite
 - ChildEntity: name, birthDate, avatarURL
 - StoryEntity: title, content, artworkIds, status, voiceURL, pdfURL
 - ProgressEntity: skill, level, notes, artworkId
 */
