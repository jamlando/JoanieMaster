import Foundation

struct ProgressEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let childId: UUID
    let userId: UUID
    let skill: String
    let level: SkillLevel
    let notes: String?
    let artworkId: UUID?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case userId = "user_id"
        case skill
        case level
        case notes
        case artworkId = "artwork_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed Properties
    
    var skillDisplayName: String {
        return skill.capitalized
    }
    
    var levelDisplayName: String {
        return level.displayName
    }
    
    var levelEmoji: String {
        return level.emoji
    }
    
    var progressPercentage: Double {
        return level.progressPercentage
    }
    
    // MARK: - Initializers
    
    init(id: UUID = UUID(), childId: UUID, userId: UUID, skill: String, level: SkillLevel, notes: String? = nil, artworkId: UUID? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.childId = childId
        self.userId = userId
        self.skill = skill
        self.level = level
        self.notes = notes
        self.artworkId = artworkId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedLevel(_ newLevel: SkillLevel) -> ProgressEntry {
        return ProgressEntry(
            id: id,
            childId: childId,
            userId: userId,
            skill: skill,
            level: newLevel,
            notes: notes,
            artworkId: artworkId,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedNotes(_ newNotes: String) -> ProgressEntry {
        return ProgressEntry(
            id: id,
            childId: childId,
            userId: userId,
            skill: skill,
            level: level,
            notes: newNotes,
            artworkId: artworkId,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

// MARK: - AI Skill Analysis

struct AISkill: Codable {
    let skill: String
    let confidence: Double
    let level: SkillLevel
    let notes: String?
    
    init(skill: String, confidence: Double, level: SkillLevel, notes: String? = nil) {
        self.skill = skill
        self.confidence = confidence
        self.level = level
        self.notes = notes
    }
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case developing = "developing"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .developing:
            return "Developing"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        case .expert:
            return "Expert"
        }
    }
    
    var emoji: String {
        switch self {
        case .beginner:
            return "🌱"
        case .developing:
            return "🌿"
        case .intermediate:
            return "🌳"
        case .advanced:
            return "🏆"
        case .expert:
            return "👑"
        }
    }
    
    var progressPercentage: Double {
        switch self {
        case .beginner:
            return 0.2
        case .developing:
            return 0.4
        case .intermediate:
            return 0.6
        case .advanced:
            return 0.8
        case .expert:
            return 1.0
        }
    }
    
    var description: String {
        switch self {
        case .beginner:
            return "Just starting to explore this skill"
        case .developing:
            return "Making progress and showing improvement"
        case .intermediate:
            return "Comfortable with basic techniques"
        case .advanced:
            return "Skilled and creative with this ability"
        case .expert:
            return "Mastery level with exceptional talent"
        }
    }
}

// MARK: - Common Skills

enum CommonSkill: String, CaseIterable {
    case fineMotor = "fine_motor"
    case creativity = "creativity"
    case colorRecognition = "color_recognition"
    case shapeRecognition = "shape_recognition"
    case storytelling = "storytelling"
    case attentionToDetail = "attention_to_detail"
    case spatialAwareness = "spatial_awareness"
    case emotionalExpression = "emotional_expression"
    case problemSolving = "problem_solving"
    case handEyeCoordination = "hand_eye_coordination"
    
    var displayName: String {
        switch self {
        case .fineMotor:
            return "Fine Motor Skills"
        case .creativity:
            return "Creativity"
        case .colorRecognition:
            return "Color Recognition"
        case .shapeRecognition:
            return "Shape Recognition"
        case .storytelling:
            return "Storytelling"
        case .attentionToDetail:
            return "Attention to Detail"
        case .spatialAwareness:
            return "Spatial Awareness"
        case .emotionalExpression:
            return "Emotional Expression"
        case .problemSolving:
            return "Problem Solving"
        case .handEyeCoordination:
            return "Hand-Eye Coordination"
        }
    }
    
    var emoji: String {
        switch self {
        case .fineMotor:
            return "✋"
        case .creativity:
            return "🎨"
        case .colorRecognition:
            return "🌈"
        case .shapeRecognition:
            return "🔷"
        case .storytelling:
            return "📚"
        case .attentionToDetail:
            return "🔍"
        case .spatialAwareness:
            return "📐"
        case .emotionalExpression:
            return "😊"
        case .problemSolving:
            return "🧩"
        case .handEyeCoordination:
            return "🎯"
        }
    }
    
    var description: String {
        switch self {
        case .fineMotor:
            return "Ability to use small muscles in hands and fingers"
        case .creativity:
            return "Original thinking and artistic expression"
        case .colorRecognition:
            return "Identifying and using different colors"
        case .shapeRecognition:
            return "Recognizing and drawing basic shapes"
        case .storytelling:
            return "Creating and sharing stories"
        case .attentionToDetail:
            return "Focusing on small details and precision"
        case .spatialAwareness:
            return "Understanding space and relationships"
        case .emotionalExpression:
            return "Expressing feelings through art"
        case .problemSolving:
            return "Finding creative solutions"
        case .handEyeCoordination:
            return "Coordinating hand movements with vision"
        }
    }
}
