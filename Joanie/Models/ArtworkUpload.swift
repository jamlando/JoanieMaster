import Foundation

struct ArtworkUpload: Codable, Identifiable, Equatable {
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
    
    // MARK: - Computed Properties
    
    var displayTitle: String {
        return title ?? "Untitled Artwork"
    }
    
    var aspectRatio: Double? {
        guard let width = width, let height = height, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
    
    var fileSizeDisplay: String {
        guard let fileSize = fileSize else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var dimensionsDisplay: String {
        guard let width = width, let height = height else { return "Unknown dimensions" }
        return "\(width) × \(height)"
    }
    
    var hasAIAnalysis: Bool {
        return aiAnalysis != nil
    }
    
    var primaryColors: [String] {
        return aiAnalysis?.colors ?? []
    }
    
    var detectedSkills: [String] {
        return aiAnalysis?.skills ?? []
    }
    
    var tips: [String] {
        return aiAnalysis?.tips ?? []
    }
    
    // MARK: - Initializers
    
    init(id: UUID = UUID(), childId: UUID, userId: UUID, title: String? = nil, description: String? = nil, artworkType: ArtworkType, imageURL: String, thumbnailURL: String? = nil, fileSize: Int? = nil, width: Int? = nil, height: Int? = nil, aiAnalysis: AIAnalysis? = nil, tags: [String]? = nil, isFavorite: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.childId = childId
        self.userId = userId
        self.title = title
        self.description = description
        self.artworkType = artworkType
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.aiAnalysis = aiAnalysis
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedTitle(_ newTitle: String) -> ArtworkUpload {
        return ArtworkUpload(
            id: id,
            childId: childId,
            userId: userId,
            title: newTitle,
            description: description,
            artworkType: artworkType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            fileSize: fileSize,
            width: width,
            height: height,
            aiAnalysis: aiAnalysis,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedDescription(_ newDescription: String) -> ArtworkUpload {
        return ArtworkUpload(
            id: id,
            childId: childId,
            userId: userId,
            title: title,
            description: newDescription,
            artworkType: artworkType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            fileSize: fileSize,
            width: width,
            height: height,
            aiAnalysis: aiAnalysis,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedFavoriteStatus(_ isFavorite: Bool) -> ArtworkUpload {
        return ArtworkUpload(
            id: id,
            childId: childId,
            userId: userId,
            title: title,
            description: description,
            artworkType: artworkType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            fileSize: fileSize,
            width: width,
            height: height,
            aiAnalysis: aiAnalysis,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedAIAnalysis(_ newAnalysis: AIAnalysis) -> ArtworkUpload {
        return ArtworkUpload(
            id: id,
            childId: childId,
            userId: userId,
            title: title,
            description: description,
            artworkType: artworkType,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            fileSize: fileSize,
            width: width,
            height: height,
            aiAnalysis: newAnalysis,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: Date()
        )
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

struct AIAnalysis: Codable, Equatable {
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
