import Foundation

struct Config {
    // MARK: - Supabase Configuration
    // TODO: Replace with actual Supabase project credentials
    static let supabaseURL = "https://your-project-id.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
    
    // MARK: - App Configuration
    static let appName = "Joanie"
    static let appVersion = "1.0.0"
    
    // MARK: - Storage Configuration
    static let artworkBucketName = "artwork-images"
    static let profileBucketName = "profile-photos"
    
    // MARK: - AI Configuration
    static let openAIAPIKey = "your-openai-api-key" // TODO: Add when implementing AI features
    static let xAIAPIKey = "your-xai-api-key" // TODO: Add when implementing AI features
    
    // MARK: - Development Configuration
    static let isDebugMode = true
    static let enableLogging = true
    
    // MARK: - Helper Methods
    
    static func getSupabaseURL() -> URL {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL: \(supabaseURL)")
        }
        return url
    }
    
    static func validateConfiguration() -> Bool {
        // Check if Supabase credentials are configured
        if supabaseURL.contains("your-project-id") || supabaseAnonKey.contains("your-anon-key") {
            print("⚠️ Warning: Supabase credentials not configured")
            return false
        }
        return true
    }
}
