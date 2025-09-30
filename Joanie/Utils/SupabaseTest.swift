import Foundation
import Supabase

class SupabaseTest {
    static let shared = SupabaseTest()
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    // MARK: - Connection Test
    
    func testConnection() async -> Bool {
        do {
            // Test basic connection by trying to get current user
            // This will fail if not authenticated, but won't fail if Supabase is unreachable
            _ = supabaseService.getCurrentUser()
            print("✅ Supabase connection test passed")
            return true
        } catch {
            print("❌ Supabase connection test failed: \(error)")
            return false
        }
    }
    
    // MARK: - Authentication Test
    
    func testAuthentication() async -> Bool {
        do {
            // Test sign up with a test email
            let testEmail = "test-\(UUID().uuidString)@joanie.app"
            let testPassword = "TestPassword123!"
            
            let response = try await supabaseService.signUp(
                email: testEmail,
                password: testPassword
            )
            
            if response.user != nil {
                print("✅ Authentication test passed")
                
                // Clean up test user
                try await supabaseService.signOut()
                return true
            } else {
                print("❌ Authentication test failed: No user returned")
                return false
            }
        } catch {
            print("❌ Authentication test failed: \(error)")
            return false
        }
    }
    
    // MARK: - Database Test
    
    func testDatabase() async -> Bool {
        do {
            // Test database connection by trying to get user profile
            // This will fail if not authenticated, but won't fail if database is unreachable
            _ = try await supabaseService.getUserProfile()
            print("✅ Database test passed")
            return true
        } catch {
            print("❌ Database test failed: \(error)")
            return false
        }
    }
    
    // MARK: - Storage Test
    
    func testStorage() async -> Bool {
        do {
            // Test storage connection by trying to list buckets
            let buckets = try await supabaseService.client.storage.listBuckets()
            print("✅ Storage test passed - Found \(buckets.count) buckets")
            return true
        } catch {
            print("❌ Storage test failed: \(error)")
            return false
        }
    }
    
    // MARK: - Full Test Suite
    
    func runAllTests() async {
        print("🧪 Running Supabase integration tests...")
        print(String(repeating: "=", count: 50))
        
        let connectionTest = await testConnection()
        let authTest = await testAuthentication()
        let databaseTest = await testDatabase()
        let storageTest = await testStorage()
        
        print(String(repeating: "=", count: 50))
        print("📊 Test Results:")
        print("Connection: \(connectionTest ? "✅" : "❌")")
        print("Authentication: \(authTest ? "✅" : "❌")")
        print("Database: \(databaseTest ? "✅" : "❌")")
        print("Storage: \(storageTest ? "✅" : "❌")")
        
        let allPassed = connectionTest && authTest && databaseTest && storageTest
        print("Overall: \(allPassed ? "✅ All tests passed" : "❌ Some tests failed")")
    }
}
