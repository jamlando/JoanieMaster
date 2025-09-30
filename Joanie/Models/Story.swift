import Foundation

struct Story: Codable, Identifiable {
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
