import Foundation
import Combine

// MARK: - App State Management

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var selectedChild: Child?
    @Published var children: [Child] = []
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    var selectedChildName: String {
        return selectedChild?.name ?? "No child selected"
    }
    
    // MARK: - Methods
    
    func setCurrentUser(_ user: UserProfile?) {
        currentUser = user
        isAuthenticated = user != nil
    }
    
    func setSelectedChild(_ child: Child?) {
        selectedChild = child
    }
    
    func addChild(_ child: Child) {
        children.append(child)
        if selectedChild == nil {
            selectedChild = child
        }
    }
    
    func removeChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
        if selectedChild?.id == child.id {
            selectedChild = children.first
        }
    }
    
    func updateChild(_ child: Child) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        }
        if selectedChild?.id == child.id {
            selectedChild = child
        }
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ message: String?) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func logout() {
        currentUser = nil
        selectedChild = nil
        children = []
        isAuthenticated = false
        isLoading = false
        errorMessage = nil
    }
}

// MARK: - Loading State
// LoadingState enum is defined in ErrorHandler.swift to avoid duplication

// MARK: - App Error

enum AppError: LocalizedError, Equatable {
    case networkError(String)
    case authenticationError(String)
    case validationError(String)
    case storageError(String)
    case aiServiceError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        case .storageError(let message):
            return "Storage Error: \(message)"
        case .aiServiceError(let message):
            return "AI Service Error: \(message)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .authenticationError:
            return "Please sign in again or contact support."
        case .validationError:
            return "Please check your input and try again."
        case .storageError:
            return "Please try again or contact support if the problem persists."
        case .aiServiceError:
            return "AI service is temporarily unavailable. Please try again later."
        case .unknown:
            return "An unexpected error occurred. Please try again or contact support."
        }
    }
}
