import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: Config.getSupabaseURL(),
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        return try await client.auth.signUp(
            email: email,
            password: password
        )
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        return try await client.auth.signIn(
            email: email,
            password: password
        )
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func getCurrentUser() -> User? {
        return client.auth.currentUser
    }
    
    // MARK: - User Management
    
    func createUserProfile(user: User) async throws {
        let userProfile = UserProfile(
            id: user.id,
            email: user.email ?? "",
            fullName: user.userMetadata["full_name"] as? String,
            role: .parent
        )
        
        try await client.database
            .from("users")
            .insert(userProfile)
            .execute()
    }
    
    func getUserProfile() async throws -> UserProfile? {
        guard let userId = getCurrentUser()?.id else { return nil }
        
        let response: [UserProfile] = try await client.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Children Management
    
    func createChild(name: String, birthDate: Date?) async throws -> Child {
        guard let userId = getCurrentUser()?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let child = Child(
            userId: userId,
            name: name,
            birthDate: birthDate
        )
        
        let response: [Child] = try await client.database
            .from("children")
            .insert(child)
            .select()
            .execute()
            .value
        
        return response.first!
    }
    
    func getChildren() async throws -> [Child] {
        guard let userId = getCurrentUser()?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let response: [Child] = try await client.database
            .from("children")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Artwork Management
    
    func uploadArtwork(
        childId: UUID,
        title: String?,
        description: String?,
        imageData: Data,
        artworkType: ArtworkType
    ) async throws -> ArtworkUpload {
        guard let userId = getCurrentUser()?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        // Upload image to storage
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "\(childId)/\(fileName)"
        
        try await client.storage
            .from("artwork-images")
            .upload(path: filePath, file: imageData)
        
        // Get public URL
        let imageURL = try client.storage
            .from("artwork-images")
            .getPublicURL(path: filePath)
        
        // Create database record
        let artwork = ArtworkUpload(
            childId: childId,
            userId: userId,
            title: title,
            description: description,
            artworkType: artworkType,
            imageURL: imageURL.absoluteString,
            fileSize: imageData.count
        )
        
        let response: [ArtworkUpload] = try await client.database
            .from("artwork_uploads")
            .insert(artwork)
            .select()
            .execute()
            .value
        
        return response.first!
    }
    
    func getArtwork(childId: UUID) async throws -> [ArtworkUpload] {
        let response: [ArtworkUpload] = try await client.database
            .from("artwork_uploads")
            .select()
            .eq("child_id", value: childId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Stories Management
    
    func createStory(
        childId: UUID,
        title: String,
        content: String,
        artworkIds: [UUID]
    ) async throws -> Story {
        guard let userId = getCurrentUser()?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let story = Story(
            userId: userId,
            childId: childId,
            title: title,
            content: content,
            artworkIds: artworkIds
        )
        
        let response: [Story] = try await client.database
            .from("stories")
            .insert(story)
            .select()
            .execute()
            .value
        
        return response.first!
    }
    
    func getStories(childId: UUID) async throws -> [Story] {
        let response: [Story] = try await client.database
            .from("stories")
            .select()
            .eq("child_id", value: childId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
}

// MARK: - Error Types

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case invalidResponse
    case storageError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from server"
        case .storageError:
            return "Storage operation failed"
        }
    }
}
