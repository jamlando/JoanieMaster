#!/usr/bin/env swift

import Foundation

// MARK: - Resend Configuration Test Script
// Run this script to test your Resend configuration

print("🧪 Testing Resend Configuration...")

// Test configuration validation
func testConfiguration() {
    print("\n📋 Configuration Validation:")
    
    // Check if we have required environment variables
    let requiredVars = [
        "RESEND_API_KEY": ProcessInfo.processInfo.environment["RESEND_API_KEY"] ?? "NOT_SET",
        "RESEND_DOMAIN": ProcessInfo.processInfo.environment["RESEND_DOMAIN"] ?? "NOT_SET",
        "APP_ENVIRONMENT": ProcessInfo.processInfo.environment["APP_ENVIRONMENT"] ?? "NOT_SET"
    ]
    
    var hasIssues = false
    for (key, value) in requiredVars {
        if value == "NOT_SET" || (key == "RESEND_API_KEY" && value.contains("your-resend-api-key")) {
            print("❌ \(key): NOT CONFIGURED")
            hasIssues = true
        } else if key == "RESEND_API_KEY" {
            print("✅ \(key): \(String(value.prefix(8)))...")
        } else {
            print("✅ \(key): \(value)")
        }
    }
    
    if !hasIssues {
        print("✅ All configuration variables set!")
    } else {
        print("\n⚠️  Configuration issues found. Please set missing environment variables.")
    }
}

// Test API connection
func testAPIConnection() async {
    guard let apiKey = ProcessInfo.processInfo.environment["RESEND_API_KEY"],
          apiKey != "your-resend-api-key-here",
          !apiKey.isEmpty else {
        print("❌ RESEND_API_KEY not configured")
        return
    }
    
    print("\n🔗 Testing API Connection...")
    
    let url = URL(string: "https://api.resend.com/domains")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                print("✅ API connection successful!")
                
                // Parse and display domain info
                if let domainsResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let domains = domainsResponse["data"] as? [[String: Any]] {
                    
                    print("\n📧 Configured Domains:")
                    for domain in domains {
                        let name = domain["name"] as? String ?? "Unknown"
                        let status = domain["status"] as? String ?? "Unknown"
                        let statusIcon = status == "verified" ? "✅" : "⚠️"
                        print("\(statusIcon) \(name): \(status)")
                    }
                }
            } else {
                print("❌ API connection failed: HTTP \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("   Error: \(errorData)")
                }
            }
        }
    } catch {
        print("❌ Connection error: \(error.localizedDescription)")
    }
}

// Test email sending
func testEmailSending() async {
    guard let apiKey = ProcessInfo.processInfo.environment["RESEND_API_KEY"],
          apiKey != "your-resend-api-key-here",
          !apiKey.isEmpty else {
        print("❌ Cannot test email - RESEND_API_KEY not configured")
        return
    }
    
    print("\n📨 Testing Email Sending...")
    print("Enter test email address:")
    
    // For automation, you can set TEST_EMAIL environment variable
    let testEmail = ProcessInfo.processInfo.environment["TEST_EMAIL"] ?? ""
    let recipient: String
    
    if !testEmail.isEmpty {
        recipient = testEmail
        print("Using TEST_EMAIL: \(recipient)")
    } else {
        // For interactive testing
        recipient = "your-email@example.com"  // Replace with actual test email
        print("Please update the script with a valid test email address")
        return
    }
    
    let emailData = [
        "from": "noreply@joanie.app",
        "to": [recipient],
        "subject": "🧪 Joanie Resend Test Email",
        "html": """
        <html>
        <body>
            <h1>🎉 Resend Configuration Test</h1>
            <p>Your Resend email service is working correctly!</p>
            <ul>
                <li>✅ API Connection: Working</li>
                <li>✅ Domain: Configured</li>
                <li>✅ Email Delivery: Successful</li>
            </ul>
            <p><small>Sent on \(Date())</small></p>
        </body>
        </html>
        """
    ]
    
    let url = URL(string: "https://api.resend.com/emails")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                print("✅ Test email sent successfully!")
                
                if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let emailId = responseData["id"] as? String {
                    print("📧 Email ID: \(emailId)")
                    print("📬 Check your email inbox for the test message")
                }
            } else {
                print("❌ Email sending failed: HTTP \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("   Error: \(errorData)")
                }
            }
        }
    } catch {
        print("❌ Email sending error: \(error.localizedDescription)")
    }
}

// Run the tests
await MainActor.run {
    testConfiguration()
    
    Task {
        await testAPIConnection()
        await testEmailSending()
        print("\n🎯 Configuration test complete!")
        print("\nNext steps:")
        print("1. ✅ Domain verification: Check Resend dashboard")
        print("2. 📧 Send test emails to verify delivery")
        print("3. 🚀 Deploy to production environment")
    }
}

