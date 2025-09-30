import Foundation

struct Story: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let childId: UUID
    let title: String
    let content: String
    let artworkIds: [UUID]
    let status: StoryStatus
    let voiceURL: String?
    let pdfURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case childId = "child_id"
        case title
        case content
        case artworkIds = "artwork_ids"
        case status
        case voiceURL = "voice_url"
        case pdfURL = "pdf_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed Properties
    
    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    var estimatedReadingTime: Int {
        // Average reading speed: 200 words per minute
        return max(1, wordCount / 200)
    }
    
    var hasVoice: Bool {
        return voiceURL != nil
    }
    
    var hasPDF: Bool {
        return pdfURL != nil
    }
    
    var artworkCount: Int {
        return artworkIds.count
    }
    
    var isPublished: Bool {
        return status == .published
    }
    
    var isDraft: Bool {
        return status == .draft
    }
    
    // MARK: - Initializers
    
    init(id: UUID = UUID(), userId: UUID, childId: UUID, title: String, content: String, artworkIds: [UUID] = [], status: StoryStatus = .draft, voiceURL: String? = nil, pdfURL: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.childId = childId
        self.title = title
        self.content = content
        self.artworkIds = artworkIds
        self.status = status
        self.voiceURL = voiceURL
        self.pdfURL = pdfURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedTitle(_ newTitle: String) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: newTitle,
            content: content,
            artworkIds: artworkIds,
            status: status,
            voiceURL: voiceURL,
            pdfURL: pdfURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedContent(_ newContent: String) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: title,
            content: newContent,
            artworkIds: artworkIds,
            status: status,
            voiceURL: voiceURL,
            pdfURL: pdfURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedStatus(_ newStatus: StoryStatus) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: title,
            content: content,
            artworkIds: artworkIds,
            status: newStatus,
            voiceURL: voiceURL,
            pdfURL: pdfURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedArtworkIds(_ newArtworkIds: [UUID]) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: title,
            content: content,
            artworkIds: newArtworkIds,
            status: status,
            voiceURL: voiceURL,
            pdfURL: pdfURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedVoiceURL(_ newVoiceURL: String) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: title,
            content: content,
            artworkIds: artworkIds,
            status: status,
            voiceURL: newVoiceURL,
            pdfURL: pdfURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedPDFURL(_ newPDFURL: String) -> Story {
        return Story(
            id: id,
            userId: userId,
            childId: childId,
            title: title,
            content: content,
            artworkIds: artworkIds,
            status: status,
            voiceURL: voiceURL,
            pdfURL: newPDFURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

enum StoryStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case generated = "generated"
    case published = "published"
    
    var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .generated:
            return "Generated"
        case .published:
            return "Published"
        }
    }
}
