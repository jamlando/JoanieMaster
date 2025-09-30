import Foundation

struct Child: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let name: String
    let birthDate: Date?
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case birthDate = "birth_date"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed Properties
    
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    var ageDisplay: String {
        guard let age = age else { return "Age unknown" }
        return "\(age) years old"
    }
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first?.uppercased() }
        return String(initials.prefix(2))
    }
    
    var ageGroup: AgeGroup {
        guard let age = age else { return .unknown }
        switch age {
        case 0...2:
            return .toddler
        case 3...5:
            return .preschool
        case 6...8:
            return .earlyElementary
        case 9...12:
            return .elementary
        default:
            return .unknown
        }
    }
    
    // MARK: - Initializers
    
    init(id: UUID = UUID(), userId: UUID, name: String, birthDate: Date? = nil, avatarURL: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        self.birthDate = birthDate
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedName(_ newName: String) -> Child {
        return Child(
            id: id,
            userId: userId,
            name: newName,
            birthDate: birthDate,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedBirthDate(_ newBirthDate: Date) -> Child {
        return Child(
            id: id,
            userId: userId,
            name: name,
            birthDate: newBirthDate,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    func withUpdatedAvatar(_ newAvatarURL: String) -> Child {
        return Child(
            id: id,
            userId: userId,
            name: name,
            birthDate: birthDate,
            avatarURL: newAvatarURL,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

enum AgeGroup: String, CaseIterable {
    case toddler = "toddler"
    case preschool = "preschool"
    case earlyElementary = "early_elementary"
    case elementary = "elementary"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .toddler:
            return "Toddler (0-2)"
        case .preschool:
            return "Preschool (3-5)"
        case .earlyElementary:
            return "Early Elementary (6-8)"
        case .elementary:
            return "Elementary (9-12)"
        case .unknown:
            return "Unknown Age"
        }
    }
    
    var emoji: String {
        switch self {
        case .toddler:
            return "👶"
        case .preschool:
            return "🧒"
        case .earlyElementary:
            return "👦"
        case .elementary:
            return "👧"
        case .unknown:
            return "❓"
        }
    }
}
