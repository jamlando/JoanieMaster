import Foundation
import Supabase

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let fullName: String?
    let avatarURL: String?
    let role: UserRole
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum UserRole: String, Codable, CaseIterable {
    case parent = "parent"
    case guardian = "guardian"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .parent:
            return "Parent"
        case .guardian:
            return "Guardian"
        case .viewer:
            return "Viewer"
        }
    }
}
