import Foundation

struct Config {
    // MARK: - Supabase Configuration
    static let supabaseURL = Secrets.supabaseURL
    static let supabaseAnonKey = Secrets.supabaseAnonKey
    
    // MARK: - App Configuration
    static let appName = "Joanie"
    static let appVersion = "1.0.0"
    
    // MARK: - Storage Configuration
    static let artworkBucketName = "artwork-images"
    static let profileBucketName = "profile-photos"
    
    // MARK: - AI Configuration
    static let openAIAPIKey = Secrets.openAIAPIKey
    static let xAIAPIKey = Secrets.xAIAPIKey
    
    // MARK: - Development Configuration
    static let isDebugMode = Secrets.debugMode
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
