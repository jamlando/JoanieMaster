import Foundation
import Combine

// MARK: - Progress Tracking Service

class ProgressTrackingService: ObservableObject, ServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var isTracking: Bool = false
    @Published var currentProgress: [String: ProgressEntry] = [:]
    @Published var recentMilestones: [ProgressMilestone] = []
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let supabaseService: SupabaseService
    private let notificationWrapperService: NotificationWrapperService
    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        supabaseService: SupabaseService = SupabaseService.shared,
        notificationWrapperService: NotificationWrapperService = NotificationWrapperService(notificationToggleService: NotificationToggleService())
    ) {
        self.supabaseService = supabaseService
        self.notificationWrapperService = notificationWrapperService
        self.logger = Logger.shared
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Setup any necessary bindings
    }
    
    // MARK: - Public Methods
    
    /// Records progress for a specific skill
    func recordProgress(
        childId: UUID,
        userId: UUID,
        skill: String,
        level: SkillLevel,
        notes: String? = nil,
        artworkId: UUID? = nil
    ) async throws -> ProgressEntry {
        isTracking = true
        errorMessage = nil
        
        do {
            let progressEntry = ProgressEntry(
                childId: childId,
                userId: userId,
                skill: skill,
                level: level,
                notes: notes,
                artworkId: artworkId
            )
            
            // Check if this is a milestone (level advancement)
            let previousLevel = currentProgress[skill]?.level
            let isMilestone = previousLevel != nil && level != previousLevel
            
            // Update current progress
            currentProgress[skill] = progressEntry
            
            // Send notification if milestone reached
            if isMilestone {
                await sendProgressMilestoneNotification(
                    childId: childId,
                    skill: skill,
                    previousLevel: previousLevel!,
                    newLevel: level,
                    artworkId: artworkId
                )
                
                // Record milestone
                let milestone = ProgressMilestone(
                    childId: childId,
                    skill: skill,
                    previousLevel: previousLevel!,
                    newLevel: level,
                    artworkId: artworkId,
                    timestamp: Date()
                )
                recentMilestones.append(milestone)
            }
            
            // TODO: Save to Supabase when implemented
            // try await supabaseService.createProgressEntry(progressEntry)
            
            isTracking = false
            logger.info("Progress recorded for skill: \(skill) at level: \(level.displayName)")
            
            return progressEntry
            
        } catch {
            isTracking = false
            errorMessage = error.localizedDescription
            logger.error("Failed to record progress: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates progress for a specific skill
    func updateProgress(
        _ progressEntry: ProgressEntry,
        newLevel: SkillLevel? = nil,
        newNotes: String? = nil
    ) async throws -> ProgressEntry {
        isTracking = true
        errorMessage = nil
        
        do {
            let updatedEntry: ProgressEntry
            
            if let newLevel = newLevel {
                updatedEntry = progressEntry.withUpdatedLevel(newLevel)
                
                // Check if this is a milestone
                if newLevel != progressEntry.level {
                    await sendProgressMilestoneNotification(
                        childId: progressEntry.childId,
                        skill: progressEntry.skill,
                        previousLevel: progressEntry.level,
                        newLevel: newLevel,
                        artworkId: progressEntry.artworkId
                    )
                }
            } else if let newNotes = newNotes {
                updatedEntry = progressEntry.withUpdatedNotes(newNotes)
            } else {
                updatedEntry = progressEntry
            }
            
            // Update current progress
            currentProgress[progressEntry.skill] = updatedEntry
            
            // TODO: Update in Supabase when implemented
            // try await supabaseService.updateProgressEntry(updatedEntry)
            
            isTracking = false
            logger.info("Progress updated for skill: \(progressEntry.skill)")
            
            return updatedEntry
            
        } catch {
            isTracking = false
            errorMessage = error.localizedDescription
            logger.error("Failed to update progress: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Gets current progress for a child
    func getCurrentProgress(for childId: UUID) async throws -> [ProgressEntry] {
        do {
            // TODO: Implement real Supabase progress retrieval
            // return try await supabaseService.getChildProgress(for: childId)
            
            // For now, return current progress for the child
            return currentProgress.values.filter { $0.childId == childId }
            
        } catch {
            logger.error("Failed to get current progress: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Gets recent milestones for a child
    func getRecentMilestones(for childId: UUID, limit: Int = 5) -> [ProgressMilestone] {
        return recentMilestones
            .filter { $0.childId == childId }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Analyzes artwork and updates progress based on AI analysis
    func analyzeAndUpdateProgress(
        artwork: ArtworkUpload,
        aiAnalysis: AIAnalysis,
        child: Child
    ) async throws {
        guard let detectedSkills = aiAnalysis.skills else { return }
        
        for skill in detectedSkills {
            let currentLevel = currentProgress[skill]?.level ?? .beginner
            let suggestedLevel = determineSkillLevel(from: skill, currentLevel: currentLevel)
            
            if suggestedLevel != currentLevel {
                try await recordProgress(
                    childId: child.id,
                    userId: child.userId,
                    skill: skill,
                    level: suggestedLevel,
                    notes: "Updated based on AI analysis of artwork: \(artwork.title ?? "Untitled")",
                    artworkId: artwork.id
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendProgressMilestoneNotification(
        childId: UUID,
        skill: String,
        previousLevel: SkillLevel,
        newLevel: SkillLevel,
        artworkId: UUID?
    ) async {
        let success = await notificationWrapperService.sendProgressMilestoneNotification(
            childName: "Your child", // TODO: Get actual child name
            skill: skill,
            level: newLevel.displayName,
            identifier: "progress_\(skill)_\(childId.uuidString)"
        )
        
        if success {
            logger.info("Progress milestone notification sent: \(skill) - \(previousLevel.displayName) → \(newLevel.displayName)")
        } else {
            logger.info("Progress milestone notification not sent (toggle disabled or permission denied)")
        }
    }
    
    private func determineSkillLevel(from skill: String, currentLevel: SkillLevel) -> SkillLevel {
        // Simple logic to determine skill level based on AI analysis
        // In a real implementation, this would be more sophisticated
        
        // For now, just return the current level
        // In a real implementation, you would analyze the skill string
        // and determine if the level should be increased
        
        return currentLevel
    }
    
    // MARK: - ServiceProtocol
    
    func reset() {
        isTracking = false
        currentProgress.removeAll()
        recentMilestones.removeAll()
        errorMessage = nil
    }
    
    nonisolated func configureForTesting() {
        Task { @MainActor in
            reset()
        }
    }
}

// MARK: - Progress Milestone

struct ProgressMilestone: Identifiable, Codable, Equatable {
    let id: UUID
    let childId: UUID
    let skill: String
    let previousLevel: SkillLevel
    let newLevel: SkillLevel
    let artworkId: UUID?
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        childId: UUID,
        skill: String,
        previousLevel: SkillLevel,
        newLevel: SkillLevel,
        artworkId: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.skill = skill
        self.previousLevel = previousLevel
        self.newLevel = newLevel
        self.artworkId = artworkId
        self.timestamp = timestamp
    }
    
    var skillDisplayName: String {
        return skill.capitalized
    }
    
    var improvementDescription: String {
        return "\(previousLevel.displayName) → \(newLevel.displayName)"
    }
    
    var emoji: String {
        return newLevel.emoji
    }
}

// MARK: - Progress Analytics

extension ProgressTrackingService {
    func getProgressStatistics(for childId: UUID) -> ProgressStatistics {
        let childProgress = currentProgress.values.filter { $0.childId == childId }
        let childMilestones = recentMilestones.filter { $0.childId == childId }
        
        let skillCount = childProgress.count
        let averageLevel = childProgress.isEmpty ? 0.0 : 
            childProgress.map { $0.level.progressPercentage }.reduce(0, +) / Double(childProgress.count)
        
        let milestoneCount = childMilestones.count
        let recentMilestoneCount = childMilestones.filter { 
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 3600 // Last 7 days
        }.count
        
        return ProgressStatistics(
            totalSkills: skillCount,
            averageLevel: averageLevel,
            totalMilestones: milestoneCount,
            recentMilestones: recentMilestoneCount,
            topSkills: getTopSkills(for: childId),
            improvementRate: calculateImprovementRate(for: childId)
        )
    }
    
    private func getTopSkills(for childId: UUID) -> [String] {
        return currentProgress.values
            .filter { $0.childId == childId }
            .sorted { $0.level.progressPercentage > $1.level.progressPercentage }
            .prefix(3)
            .map { $0.skill }
    }
    
    private func calculateImprovementRate(for childId: UUID) -> Double {
        let recentMilestones = recentMilestones.filter { 
            $0.childId == childId && 
            Date().timeIntervalSince($0.timestamp) < 30 * 24 * 3600 // Last 30 days
        }
        
        return Double(recentMilestones.count) / 30.0 // Milestones per day
    }
}

struct ProgressStatistics {
    let totalSkills: Int
    let averageLevel: Double
    let totalMilestones: Int
    let recentMilestones: Int
    let topSkills: [String]
    let improvementRate: Double
}
