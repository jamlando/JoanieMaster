//
//  EmailTemplateManager.swift
//  Joanie
//
//  Email Template Management System
//  Handles template loading, caching, rendering, and dynamic content injection
//

import Foundation

// MARK: - Email Template Manager

@MainActor
class EmailTemplateManager: ObservableObject {
    // MARK: - Properties
    private var cachedTemplates: [EmailTemplate: EmailTemplateContent] = [:]
    private let logger: Logger
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    private var cacheTimestamps: [EmailTemplate: Date] = [:]
    
    // MARK: - Published Properties
    @Published var cachedTemplateCount: Int = 0
    @Published var lastLoadTime: Date?
    @Published var loadError: String?
    
    // MARK: - Initialization
    init() {
        self.logger = Logger.shared
    }
    
    // MARK: - Public Methods
    
    /// Load template with caching support
    func loadTemplate(_ template: EmailTemplate) async throws -> EmailTemplateContent {
        // Check cache first
        if let cachedContent = getCachedTemplate(template) {
            logger.info("Using cached template", metadata: [
                "template": template.rawValue,
                "isCached": "true"
            ])
            return cachedContent
        }
        
        // Load from source
        let content = try await fetchTemplateFromSource(template)
        
        // Cache the loaded content
        cacheTemplate(template, content: content)
        
        logger.info("Template loaded and cached", metadata: [
            "template": template.rawValue,
            "cachedCount": cachedTemplates.count
        ])
        
        return content
    }
    
    /// Render template with dynamic data injection
    func renderTemplate(_ template: EmailTemplateContent, with data: EmailTemplateData) throws -> RenderedEmailContent {
        let renderedSubject = try injectTemplateVariables(template.subject, data: data)
        let renderedHTML = try injectTemplateVariables(template.htmlBody, data: data)
        let renderedText = try injectTemplateVariables(template.textBody, data: data)
        
        return RenderedEmailContent(
            subject: renderedSubject,
            htmlBody: renderedHTML,
            textBody: renderedText,
            renderTime: Date()
        )
    }
    
    /// Validate template data for specific template
    func validateTemplateData(_ template: EmailTemplate, data: EmailTemplateData) -> TemplateValidationResult {
        let requiredVariables = getRequiredVariables(for: template)
        let providedKeys = Set(data.keys)
        let requiredKeys = Set(requiredVariables.keys)
        
        let missingVariables = requiredKeys.subtracting(providedKeys)
        let unusedVariables = providedKeys.subtracting(requiredKeys)
        
        return TemplateValidationResult(
            isValid: missingVariables.isEmpty,
            missingVariables: Array(missingVariables),
            unusedVariables: Array(unusedVariables),
            requiredVariables: requiredVariables
        )
    }
    
    /// Clear template cache
    func clearCache() {
        cachedTemplates.removeAll()
        cacheTimestamps.removeAll()
        cachedTemplateCount = 0
        
        logger.info("Template cache cleared")
    }
    
    /// Get template cache statistics
    func getCacheStatistics() -> CacheStatistics {
        let now = Date()
        let validCachedTemplates = cachedTemplates.filter { template, _ in
            isValidCacheEntry(for: template)
        }
        
        return CacheStatistics(
            totalCached: cachedTemplates.count,
            validCached: validCachedTemplates.count,
            cacheHitRate: calculateCacheHitRate(),
            oldestCacheEntry: cacheTimestamps.values.min(),
            newestCacheEntry: cacheTimestamps.values.max(),
            totalCacheSize: calculateCacheSize()
        )
    }
    
    // MARK: - Private Methods
    
    private func fetchTemplateFromSource(_ template: EmailTemplate) async throws -> EmailTemplateContent {
        lastLoadTime = Date()
        loadError = nil
        
        do {
            switch template {
            case .passwordReset:
                return try await createPasswordResetTemplate()
            case .welcome:
                return try await createWelcomeTemplate()
            case .accountVerification:
                return try await createAccountVerificationTemplate()
            case .accountNotification:
                return try await createAccountNotificationTemplate()
            case .followUpWelcome:
                return try await createFollowUpWelcomeTemplate()
            }
        } catch {
            loadError = error.localizedDescription
            logger.error("Failed to load template", metadata: [
                "template": template.rawValue,
                "error": error.localizedDescription
            ])
            throw EmailError.templateRenderFailed(error.localizedDescription)
        }
    }
    
    private func createPasswordResetTemplate() async throws -> EmailTemplateContent {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Reset Your Password</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; }
                .content { padding: 30px 20px; }
                .button { display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
                .warning { background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; color: #856404; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Joanie</h1>
                    <p>Reset Your Password</p>
                </div>
                <div class="content">
                    <h2>Password Reset Request</h2>
                    {% if userName %}
                    <p>Hello {{ userName }},</p>
                    {% endif %}
                    <p>We received a request to reset your password for your Joanie account. If you made this request, click the button below to reset your password:</p>
                    
                    <div style="text-align: center;">
                        <a href="{{ resetURL }}" class="button">Reset Password</a>
                    </div>
                    
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="background: #f8f9fa; padding: 10px; border-radius: 5px; word-break: break-all; font-family: monospace;">{{ resetURL }}</p>
                    
                    <div class="warning">
                        <strong>🔒 Security Notice:</strong> This link will expire in 24 hours for your security. If you didn't request this password reset, please ignore this email.
                    </div>
                    
                    <p>Best regards,<br>The Joanie Team</p>
                </div>
                <div class="footer">
                    <p>This email was sent from Joanie. If you have any questions, please contact support.</p>
                    <p>Joanie - Capturing precious moments, one story at a time</p>
                </div>
                <div style="display:none;">{{ resetToken }}</div>
            </div>
        </body>
        </html>
        """
        
        let textTemplate = """
        Joanie - Password Reset
        
        Hello{{ userName ? ' ' + userName : '' }},
        
        We received a request to reset your password for your Joanie account. If you made this request, please click the link below to reset your password:
        
        {{ resetURL }}
        
        This link will expire in 24 hours for your security.
        
        If you didn't request this password reset, please ignore this email.
        
        Best regards,
        The Joanie Team
        
        ---
        Joanie - Capturing precious moments, one story at a time
        """
        
        return EmailTemplateContent(
            subject: "🔒 Reset Your Joanie Password",
            htmlBody: htmlTemplate,
            textBody: textTemplate
        )
    }
    
    private func createWelcomeTemplate() async throws -> EmailTemplateContent {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Welcome to Joanie</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 20px; text-align: center; }
                .content { padding: 30px 20px; }
                .feature { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; border-left: 4px solid #667eea; }
                .button { display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 5px; margin: 20px 5px; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Welcome to Joanie!</h1>
                    <p>Let's start capturing precious moments together</p>
                </div>
                <div class="content">
                    <h2>Hi {{ userName }},</h2>
                    <p>Welcome to Joanie! We're thrilled to have you join our community of families capturing precious moments and creating beautiful stories.</p>
                    
                    <div class="feature">
                        <h3>📸 What you can do with Joanie:</h3>
                        <ul>
                            <li><strong>Capture moments:</strong> Take photos and videos of your children's special moments</li>
                            <li><strong>AI Storytelling:</strong> Get AI-powered captions and story suggestions</li>
                            <li><strong>Timeline & Gallery:</strong> Organize memories chronologically</li>
                            <li><strong>Growth Tracking:</strong> Watch your child's journey unfold over time</li>
                        </ul>
                    </div>
                    
                    <div class="feature">
                        <h3>🚀 Get started:</h3>
                        <p>Download our mobile app and start creating beautiful memories today!</p>
                    </div>
                    
                    <div style="text-align: center;">
                        <a href="{{ appStoreURL }}" class="button">Download App</a>
                        <a href="{{ webAppURL }}" class="button">Web Version</a>
                    </div>
                    
                    <p>If you have any questions, our support team is here to help. Just reach out to us anytime!</p>
                    
                    <p>Best regards,<br>The Joanie Team</p>
                </div>
                <div class="footer">
                    <p>This email was sent from Joanie. If you have any questions, please contact support.</p>
                    <p>Joanie - Capturing precious moments, one story at a time</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        let textTemplate = """
        Welcome to Joanie!
        
        Hi {{ userName }},
        
        Welcome to Joanie! We're thrilled to have you join our community of families capturing precious moments and creating beautiful stories.
        
        What you can do with Joanie:
        - Capture moments: Take photos and videos of your children's special moments
        - AI Storytelling: Get AI-powered captions and story suggestions
        - Timeline & Gallery: Organize memories chronologically
        - Growth Tracking: Watch your child's journey unfold over time
        
        Get started:
        Download our mobile app and start creating beautiful memories today!
        
        App Store: {{ appStoreURL }}
        Web Version: {{ webAppURL }}
        
        If you have any questions, our support team is here to help. Just reach out to us anytime!
        
        Best regards,
        The Joanie Team
        
        ---
        Joanie - Capturing precious moments, one story at a time
        """
        
        return EmailTemplateContent(
            subject: "🎉 Welcome to Joanie, {{ userName }}!",
            htmlBody: htmlTemplate,
            textBody: textTemplate
        )
    }
    
    private func createAccountVerificationTemplate() async throws -> EmailTemplateContent {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Verify Your Account</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segue UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; }
                .content { padding: 30px 20px; }
                .verification-code { background: #f8f9fa; border: 2px dashed #667eea; border-radius: 5px; padding: 20px; text-align: center; margin: 20px 0; }
                .code { font-family: monospace; font-size: 24px; font-weight: bold; color: #667eea; letter-spacing: 2px; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔐 Joanie</h1>
                    <p>Verify Your Account</p>
                </div>
                <div class="content">
                    <h2>Email Verification</h2>
                    <p>Thank you for signing up with Joanie! To complete your account setup and start capturing precious moments, please verify your email address.</p>
                    
                    <div class="verification-code">
                        <p>Your verification token:</p>
                        <div class="code">{{ verificationToken }}</div>
                        <p><small>Enter this code in the app to verify your email</small></p>
                    </div>
                    
                    <p>Or click the link below to verify automatically:</p>
                    <p><a href="{{ verificationURL }}" style="color: #667eea;">Verify Email Address</a></p>
                    
                    <div style="background: #e7f3ff; border: 1px solid #cce7ff; border-radius: 5px; padding: 15px; margin: 20px 0;">
                        💡 <strong>Tip:</strong> This verification link will expire in 24 hours for your security.
                    </div>
                    
                    <p>Best regards,<br>The Joanie Team</p>
                </div>
                <div class="footer">
                    <p>This email was sent from Joanie. If you have any questions, please contact support.</p>
                    <p>Joanie - Capturing precious moments, one story at a time</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        let textTemplate = """
        Joanie - Email Verification
        
        Thank you for signing up with Joanie! To complete your account setup and start capturing precious moments, please verify your email address.
        
        Your verification token:
        {{ verificationToken }}
        
        Or click this link to verify automatically:
        {{ verificationURL }}
        
        This verification link will expire in 24 hours for your security.
        
        Best regards,
        The Joanie Team
        
        ---
        Joanie - Capturing precious moments, one story at a time
        """
        
        return EmailTemplateContent(
            subject: "🔐 Verify Your Joanie Account",
            htmlBody: htmlTemplate,
            textBody: textTemplate
        )
    }
    
    private func createAccountNotificationTemplate() async throws -> EmailTemplateContent {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Account Notification</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segue UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; }
                .content { padding: 30px 20px; }
                .notification { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; border-left: 4px solid #667eea; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📧 Joanie</h1>
                    <p>Account Notification</p>
                </div>
                <div class="content">
                    <h2>{{ notificationTitle }}</h2>
                    
                    <div class="notification">
                        <p>{{ notificationMessage }}</p>
                    </div>
                    
                    <p>If you have any questions about this notification, please don't hesitate to contact our support team.</p>
                    
                    <p>Best regards,<br>The Joanie Team</p>
                </div>
                <div class="footer">
                    <p>This email was sent from Joanie. If you have any questions, please contact support.</p>
                    <p>Joanie - Capturing precious moments, one story at a time</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        let textTemplate = """
        Joanie - Account Notification
        
        {{ notificationTitle }}
        
        {{ notificationMessage }}
        
        If you have any questions about this notification, please don't hesitate to contact our support team.
        
        Best regards,
        The Joanie Team
        
        ---
        Joanie - Capturing precious moments, one story at a time
        """
        
        return EmailTemplateContent(
            subject: "📧 {{ notificationTitle }}",
            htmlBody: htmlTemplate,
            textBody: textTemplate
        )
    }
    
    private func createFollowUpWelcomeTemplate() async throws -> EmailTemplateContent {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Getting Started with Joanie</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f5f5f5; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 20px; text-align: center; }
                .content { padding: 30px 20px; }
                .step { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; border-left: 4px solid #667eea; }
                .step-number { background: #667eea; color: white; border-radius: 50%; width: 30px; height: 30px; display: inline-flex; align-items: center; justify-content: center; font-weight: bold; margin-right: 15px; }
                .button { display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 5px; margin: 20px 5px; }
                .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
                .highlight { background: #e7f3ff; border: 1px solid #cce7ff; border-radius: 5px; padding: 15px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚀 Getting Started with Joanie</h1>
                    <p>Your next steps to capturing precious moments</p>
                </div>
                <div class="content">
                    <h2>Hi {{ userName }},</h2>
                    <p>It's been {{ daysSinceSignup }} days since you joined Joanie! We hope you're enjoying the app, but we wanted to make sure you're getting the most out of your experience.</p>
                    
                    <div class="highlight">
                        <h3>💡 Quick Start Checklist:</h3>
                        <p>Complete these steps to unlock the full power of Joanie:</p>
                    </div>
                    
                    <div class="step">
                        <div class="step-number">1</div>
                        <strong>Complete Your Profile</strong>
                        <p>Add your child's information and preferences to get personalized AI insights and story suggestions.</p>
                    </div>
                    
                    <div class="step">
                        <div class="step-number">2</div>
                        <strong>Upload Your First Memory</strong>
                        <p>Capture a special moment - whether it's artwork, a photo, or a milestone. Our AI will help create a beautiful story.</p>
                    </div>
                    
                    <div class="step">
                        <div class="step-number">3</div>
                        <strong>Explore the Timeline</strong>
                        <p>Watch your child's journey unfold chronologically. See how they've grown and developed over time.</p>
                    </div>
                    
                    <div class="step">
                        <div class="step-number">4</div>
                        <strong>Share with Family</strong>
                        <p>Invite family members to join your child's journey and create collaborative memories together.</p>
                    </div>
                    
                    <div style="text-align: center;">
                        <a href="{{ appStoreURL }}" class="button">Open Joanie App</a>
                        <a href="{{ webAppURL }}" class="button">Web Version</a>
                    </div>
                    
                    <div class="highlight">
                        <h3>🎯 Pro Tips:</h3>
                        <ul>
                            <li><strong>Daily Moments:</strong> Try to capture at least one moment each day</li>
                            <li><strong>AI Stories:</strong> Let our AI help you write captions and stories</li>
                            <li><strong>Growth Tracking:</strong> Use the timeline to see developmental milestones</li>
                            <li><strong>Family Sharing:</strong> Invite grandparents and relatives to join the journey</li>
                        </ul>
                    </div>
                    
                    <p>If you have any questions or need help getting started, our support team is here for you. Just reply to this email or reach out through the app!</p>
                    
                    <p>Happy memory making!<br>The Joanie Team</p>
                </div>
                <div class="footer">
                    <p>This email was sent from Joanie. If you have any questions, please contact support.</p>
                    <p>Joanie - Capturing precious moments, one story at a time</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        let textTemplate = """
        Getting Started with Joanie - Your Next Steps
        
        Hi {{ userName }},
        
        It's been {{ daysSinceSignup }} days since you joined Joanie! We hope you're enjoying the app, but we wanted to make sure you're getting the most out of your experience.
        
        Quick Start Checklist:
        Complete these steps to unlock the full power of Joanie:
        
        1. Complete Your Profile
        Add your child's information and preferences to get personalized AI insights and story suggestions.
        
        2. Upload Your First Memory
        Capture a special moment - whether it's artwork, a photo, or a milestone. Our AI will help create a beautiful story.
        
        3. Explore the Timeline
        Watch your child's journey unfold chronologically. See how they've grown and developed over time.
        
        4. Share with Family
        Invite family members to join your child's journey and create collaborative memories together.
        
        Open Joanie App: {{ appStoreURL }}
        Web Version: {{ webAppURL }}
        
        Pro Tips:
        - Daily Moments: Try to capture at least one moment each day
        - AI Stories: Let our AI help you write captions and stories
        - Growth Tracking: Use the timeline to see developmental milestones
        - Family Sharing: Invite grandparents and relatives to join the journey
        
        If you have any questions or need help getting started, our support team is here for you. Just reply to this email or reach out through the app!
        
        Happy memory making!
        The Joanie Team
        
        ---
        Joanie - Capturing precious moments, one story at a time
        """
        
        return EmailTemplateContent(
            subject: "🚀 Getting Started with Joanie – Your Next Steps",
            htmlBody: htmlTemplate,
            textBody: textTemplate
        )
    }
    
    private func injectTemplateVariables(_ templateContent: String, data: EmailTemplateData) throws -> String {
        var rendered = templateContent
        
        // Replace variables in double curly braces
        for (key, value) in data {
            let placeholder = "{{ " + key + " }}"
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
            
            // Also handle variables without spaces
            let placeholderNoSpaces = "{{" + key + "}}"
            rendered = rendered.replacingOccurrences(of: placeholderNoSpaces, with: value)
        }
        
        // Check for unresolved variables
        let unresolvedPattern = #"\{\{[^}]*\}\}"#
        let regex = try NSRegularExpression(pattern: unresolvedPattern)
        let range = NSRange(location: 0, length: rendered.count)
        
        if let match = regex.firstMatch(in: rendered, range: range) {
            let unresolvedVariable = (rendered as NSString).substring(with: match.range)
            throw EmailError.templateVariableMissing("unknown", unresolvedVariable)
        }
        
        return rendered
    }
    
    private func getCachedTemplate(_ template: EmailTemplate) -> EmailTemplateContent? {
        guard isValidCacheEntry(for: template) else {
            // Remove expired cache entry
            cachedTemplates.removeValue(forKey: template)
            cacheTimestamps.removeValue(forKey: template)
            return nil
        }
        
        return cachedTemplates[template]
    }
    
    private func cacheTemplate(_ template: EmailTemplate, content: EmailTemplateContent) {
        cachedTemplates[template] = content
        cacheTimestamps[template] = Date()
        cachedTemplateCount = cachedTemplates.count
    }
    
    private func isValidCacheEntry(for template: EmailTemplate) -> Bool {
        guard let timestamp = cacheTimestamps[template] else {
            return false
        }
        
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
    
    private func getRequiredVariables(for template: EmailTemplate) -> [String] {
        switch template {
        case .passwordReset:
            return ["resetToken", "resetUrl"]
        case .welcome:
            return ["userName"]
        case .accountVerification:
            return ["verificationToken", "verificationUrl"]
        case .accountNotification:
            return ["notificationTitle", "notificationMessage"]
        case .followUpWelcome:
            return ["userName", "daysSinceSignup", "appStoreURL", "webAppURL"]
        }
    }
    
    private func calculateCacheSize() -> String {
        // Simplified cache size calculation
        let totalSize = cachedTemplates.reduce(0) { size, template in
            size + template.value.htmlBody.count + template.value.textBody.count + template.value.subject.count
        }
        
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    private func calculateCacheHitRate() -> Double {
        // Simplified cache hit rate calculation
        // In a real implementation, this would track actual cache hits vs misses
        return cachedTemplates.count > 0 ? 0.85 : 0.0 // Placeholder 85% hit rate
    }
}

// MARK: - Supporting Types

/// Rendered email content with timing information
struct RenderedEmailContent {
    let subject: String
    let htmlBody: String
    let textBody: String
    let renderTime: Date
    
    var contentLength: Int {
        return htmlBody.count + textBody.count + subject.count
    }
}

/// Template validation result
struct TemplateValidationResult {
    let isValid: Bool
    let missingVariables: [String]
    let unusedVariables: [String]
    let requiredVariables: [String]
    
    var validationSummary: String {
        if isValid {
            return "Template validation passed"
        } else {
            return "Missing variables: \(missingVariables.joined(separator: ", "))"
        }
    }
}

/// Cache statistics container
struct CacheStatistics {
    let totalCached: Int
    let validCached: Int
    let cacheHitRate: Double
    let oldestCacheEntry: Date?
    let newestCacheEntry: Date?
    let totalCacheSize: String
    
    var summary: [String: Any] {
        return [
            "total_cached": totalCached,
            "valid_cached": validCached,
            "hit_rate": cacheHitRate,
            "oldest_entry": oldestCacheEntry?.timeIntervalSince1970 ?? 0,
            "newest_entry": newestCacheEntry?.timeIntervalSince1970 ?? 0,
            "total_size": totalCacheSize
        ]
    }
}
