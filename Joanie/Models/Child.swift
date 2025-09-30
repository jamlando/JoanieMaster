import Foundation

struct Child: Codable, Identifiable {
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
}
