import Foundation
import UIKit

// MARK: - Validation Utils

struct ValidationUtils {
    
    // MARK: - Email Validation
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Password Validation
    
    static func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
    
    static func getPasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // Length check
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // Character type checks
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...2:
            return .weak
        case 3...4:
            return .medium
        case 5...6:
            return .strong
        default:
            return .veryStrong
        }
    }
    
    // MARK: - Name Validation
    
    static func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 2 && trimmedName.count <= 50
    }
    
    static func isValidFullName(_ fullName: String) -> Bool {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedName.components(separatedBy: " ")
        return components.count >= 2 && components.allSatisfy { isValidName($0) }
    }
    
    // MARK: - Child Name Validation
    
    static func isValidChildName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 1 && trimmedName.count <= 30
    }
    
    // MARK: - Age Validation
    
    static func isValidAge(_ age: Int) -> Bool {
        return age >= 0 && age <= 18
    }
    
    static func isValidBirthDate(_ birthDate: Date) -> Bool {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return isValidAge(age)
    }
    
    // MARK: - Artwork Validation
    
    static func isValidArtworkTitle(_ title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.count <= 100
    }
    
    static func isValidArtworkDescription(_ description: String) -> Bool {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDescription.count <= 500
    }
    
    // MARK: - Story Validation
    
    static func isValidStoryTitle(_ title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.count >= 1 && trimmedTitle.count <= 100
    }
    
    static func isValidStoryContent(_ content: String) -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.count >= 10 && trimmedContent.count <= 5000
    }
    
    // MARK: - File Validation
    
    static func isValidImageFile(_ data: Data) -> Bool {
        // Check if data is valid image
        guard UIImage(data: data) != nil else { return false }
        
        // Check file size (max 10MB)
        let maxSize = 10 * 1024 * 1024
        return data.count <= maxSize
    }
    
    static func isValidImageFileSize(_ data: Data) -> Bool {
        let maxSize = 10 * 1024 * 1024 // 10MB
        return data.count <= maxSize
    }
    
    // MARK: - URL Validation
    
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    // MARK: - Phone Number Validation
    
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^[+]?[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    // MARK: - Generic Validation
    
    static func isNotEmpty(_ string: String) -> Bool {
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    static func isValidLength(_ string: String, min: Int, max: Int) -> Bool {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedString.count >= min && trimmedString.count <= max
    }
    
    static func containsOnlyLetters(_ string: String) -> Bool {
        let letterRegex = "^[a-zA-Z\\s]+$"
        let letterPredicate = NSPredicate(format: "SELF MATCHES %@", letterRegex)
        return letterPredicate.evaluate(with: string)
    }
    
    static func containsOnlyNumbers(_ string: String) -> Bool {
        let numberRegex = "^[0-9]+$"
        let numberPredicate = NSPredicate(format: "SELF MATCHES %@", numberRegex)
        return numberPredicate.evaluate(with: string)
    }
    
    static func containsOnlyAlphanumeric(_ string: String) -> Bool {
        let alphanumericRegex = "^[a-zA-Z0-9]+$"
        let alphanumericPredicate = NSPredicate(format: "SELF MATCHES %@", alphanumericRegex)
        return alphanumericPredicate.evaluate(with: string)
    }
}

// MARK: - Password Strength

enum PasswordStrength: String, CaseIterable {
    case weak = "weak"
    case medium = "medium"
    case strong = "strong"
    case veryStrong = "very_strong"
    
    var displayName: String {
        switch self {
        case .weak:
            return "Weak"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        case .veryStrong:
            return "Very Strong"
        }
    }
    
    var color: String {
        switch self {
        case .weak:
            return "red"
        case .medium:
            return "orange"
        case .strong:
            return "yellow"
        case .veryStrong:
            return "green"
        }
    }
    
    var description: String {
        switch self {
        case .weak:
            return "Password is too weak. Use at least 8 characters with uppercase, lowercase, and numbers."
        case .medium:
            return "Password is okay but could be stronger. Add special characters for better security."
        case .strong:
            return "Good password strength. Consider adding special characters for maximum security."
        case .veryStrong:
            return "Excellent password strength. Your password is very secure."
        }
    }
}

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errorMessage: String?
    
    init(isValid: Bool, errorMessage: String? = nil) {
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
    
    static func valid() -> ValidationResult {
        return ValidationResult(isValid: true)
    }
    
    static func invalid(_ message: String) -> ValidationResult {
        return ValidationResult(isValid: false, errorMessage: message)
    }
}

// MARK: - Form Validator

class FormValidator: ObservableObject {
    @Published var errors: [String: String] = [:]
    
    func validate(_ field: String, value: String, rules: [ValidationRule]) -> ValidationResult {
        for rule in rules where !rule.isValid(value) {
            errors[field] = rule.errorMessage
            return ValidationResult.invalid(rule.errorMessage)
        }
        
        errors.removeValue(forKey: field)
        return ValidationResult.valid()
    }
    
    func clearError(for field: String) {
        errors.removeValue(forKey: field)
    }
    
    func clearAllErrors() {
        errors.removeAll()
    }
    
    var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    var errorCount: Int {
        return errors.count
    }
}

// MARK: - Validation Rule

protocol ValidationRule {
    func isValid(_ value: String) -> Bool
    var errorMessage: String { get }
}

struct RequiredRule: ValidationRule {
    let errorMessage: String
    
    init(errorMessage: String = "This field is required") {
        self.errorMessage = errorMessage
    }
    
    func isValid(_ value: String) -> Bool {
        return ValidationUtils.isNotEmpty(value)
    }
}

struct EmailRule: ValidationRule {
    let errorMessage: String
    
    init(errorMessage: String = "Please enter a valid email address") {
        self.errorMessage = errorMessage
    }
    
    func isValid(_ value: String) -> Bool {
        return ValidationUtils.isValidEmail(value)
    }
}

struct PasswordRule: ValidationRule {
    let errorMessage: String
    
    init(errorMessage: String = "Password must be at least 8 characters with uppercase, lowercase, and numbers") {
        self.errorMessage = errorMessage
    }
    
    func isValid(_ value: String) -> Bool {
        return ValidationUtils.isValidPassword(value)
    }
}

struct LengthRule: ValidationRule {
    let min: Int
    let max: Int
    let errorMessage: String
    
    init(min: Int, max: Int, errorMessage: String? = nil) {
        self.min = min
        self.max = max
        self.errorMessage = errorMessage ?? "Must be between \(min) and \(max) characters"
    }
    
    func isValid(_ value: String) -> Bool {
        return ValidationUtils.isValidLength(value, min: min, max: max)
    }
}

struct NameRule: ValidationRule {
    let errorMessage: String
    
    init(errorMessage: String = "Please enter a valid name") {
        self.errorMessage = errorMessage
    }
    
    func isValid(_ value: String) -> Bool {
        return ValidationUtils.isValidName(value)
    }
}
