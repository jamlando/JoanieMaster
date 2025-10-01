import Foundation
// import Supabase // TODO: Add Supabase dependency

struct UserProfile: Codable, Identifiable, Equatable {
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
    
    // MARK: - Computed Properties
    
    var displayName: String {
        return fullName ?? email
    }
    
    var initials: String {
        if let fullName = fullName, !fullName.isEmpty {
            let components = fullName.components(separatedBy: " ")
            let initials = components.compactMap { $0.first?.uppercased() }
            return initials.prefix(2).joined()
        }
        return String(email.prefix(2).uppercased())
    }
    
    // MARK: - Initializers
    
    init(id: UUID, email: String, fullName: String? = nil, avatarURL: String? = nil, role: UserRole = .parent, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedName(_ newName: String) -> UserProfile {
        return UserProfile(
            id: id,
            email: email,
            fullName: newName,
            avatarURL: avatarURL,
            role: role,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedAvatar(_ newAvatarURL: String) -> UserProfile {
        return UserProfile(
            id: id,
            email: email,
            fullName: fullName,
            avatarURL: newAvatarURL,
            role: role,
            createdAt: createdAt,
            updatedAt: Date()
        )
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
