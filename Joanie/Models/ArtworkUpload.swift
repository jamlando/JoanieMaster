import Foundation

struct ArtworkUpload: Codable, Identifiable {
    let id: UUID
    let childId: UUID
    let userId: UUID
    let title: String?
    let description: String?
    let artworkType: ArtworkType
    let imageURL: String
    let thumbnailURL: String?
    let fileSize: Int?
    let width: Int?
    let height: Int?
    let aiAnalysis: AIAnalysis?
    let tags: [String]?
    let isFavorite: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case userId = "user_id"
        case title
        case description
        case artworkType = "artwork_type"
        case imageURL = "image_url"
        case thumbnailURL = "thumbnail_url"
        case fileSize = "file_size"
        case width
        case height
        case aiAnalysis = "ai_analysis"
        case tags
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ArtworkType: String, Codable, CaseIterable {
    case drawing = "drawing"
    case painting = "painting"
    case sculpture = "sculpture"
    case writing = "writing"
    case craft = "craft"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .drawing:
            return "Drawing"
        case .painting:
            return "Painting"
        case .sculpture:
            return "Sculpture"
        case .writing:
            return "Writing"
        case .craft:
            return "Craft"
        case .other:
            return "Other"
        }
    }
    
    var emoji: String {
        switch self {
        case .drawing:
            return "✏️"
        case .painting:
            return "🎨"
        case .sculpture:
            return "🗿"
        case .writing:
            return "📝"
        case .craft:
            return "🧵"
        case .other:
            return "🎭"
        }
    }
}

struct AIAnalysis: Codable {
    let detectedObjects: [String]?
    let colors: [String]?
    let emotions: [String]?
    let skills: [String]?
    let tips: [String]?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case detectedObjects = "detected_objects"
        case colors
        case emotions
        case skills
        case tips
        case confidence
    }
}
