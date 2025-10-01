import Foundation
import UIKit

// MARK: - Upload Retry Manager

class UploadRetryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var retryAttempts: [UUID: Int] = [:]
    @Published var retryDelays: [UUID: TimeInterval] = [:]
    @Published var isRetrying: Bool = false
    
    // MARK: - Constants
    private let maxRetryAttempts = 3
    private let baseDelay: TimeInterval = 1.0 // 1 second
    private let maxDelay: TimeInterval = 60.0 // 60 seconds
    private let backoffMultiplier: Double = 2.0
    
    // MARK: - Retry Logic
    
    func shouldRetry(uploadId: UUID, error: Error) -> Bool {
        let attempts = retryAttempts[uploadId] ?? 0
        
        // Don't retry if we've exceeded max attempts
        guard attempts < maxRetryAttempts else { return false }
        
        // Don't retry for certain types of errors
        guard isRetryableError(error) else { return false }
        
        return true
    }
    
    func getRetryDelay(for uploadId: UUID) -> TimeInterval {
        let attempts = retryAttempts[uploadId] ?? 0
        let delay = min(baseDelay * pow(backoffMultiplier, Double(attempts)), maxDelay)
        retryDelays[uploadId] = delay
        return delay
    }
    
    func incrementRetryAttempt(for uploadId: UUID) {
        retryAttempts[uploadId] = (retryAttempts[uploadId] ?? 0) + 1
    }
    
    func resetRetryAttempts(for uploadId: UUID) {
        retryAttempts.removeValue(forKey: uploadId)
        retryDelays.removeValue(forKey: uploadId)
    }
    
    func clearAllRetryAttempts() {
        retryAttempts.removeAll()
        retryDelays.removeAll()
    }
    
    // MARK: - Retry Execution
    
    func retryUpload(
        _ uploadTask: UploadTask,
        with storageService: StorageService,
        delay: TimeInterval? = nil
    ) async -> Bool {
        guard shouldRetry(uploadId: uploadTask.id, error: uploadTask.error ?? UploadError.unknown) else {
            return false
        }
        
        let retryDelay = delay ?? getRetryDelay(for: uploadTask.id)
        incrementRetryAttempt(for: uploadTask.id)
        
        // Wait for the delay
        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        
        isRetrying = true
        
        do {
            // Attempt the upload
            let artwork = try await storageService.supabaseService.uploadArtwork(
                childId: uploadTask.childId,
                title: uploadTask.title,
                description: uploadTask.description,
                imageData: uploadTask.image.jpegData(compressionQuality: 0.8) ?? Data(),
                artworkType: uploadTask.artworkType
            )
            
            // Success - reset retry attempts
            resetRetryAttempts(for: uploadTask.id)
            uploadTask.status = .completed
            uploadTask.artwork = artwork
            isRetrying = false
            
            return true
            
        } catch {
            // Failed again
            uploadTask.error = error
            isRetrying = false
            
            if shouldRetry(uploadId: uploadTask.id, error: error) {
                // Schedule another retry
                return await retryUpload(uploadTask, with: storageService)
            } else {
                // Max retries exceeded
                uploadTask.status = .failed
                return false
            }
        }
    }
    
    // MARK: - Error Classification
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost,
                 .notConnectedToInternet,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        // HTTP errors
        if let httpError = error as? HTTPError {
            switch httpError.statusCode {
            case 408, // Request Timeout
                 429, // Too Many Requests
                 500, // Internal Server Error
                 502, // Bad Gateway
                 503, // Service Unavailable
                 504: // Gateway Timeout
                return true
            default:
                return false
            }
        }
        
        // Supabase errors
        if let supabaseError = error as? SupabaseError {
            switch supabaseError {
            case .networkError,
                 .timeout,
                 .serviceUnavailable,
                 .rateLimitExceeded:
                return true
            default:
                return false
            }
        }
        
        // Authentication errors are not retryable
        if error is AuthenticationError {
            return false
        }
        
        // Validation errors are not retryable
        if error is ValidationError {
            return false
        }
        
        // Default to not retryable for unknown errors
        return false
    }
    
    // MARK: - Retry Statistics
    
    func getRetryStatistics() -> RetryStatistics {
        let totalAttempts = retryAttempts.values.reduce(0, +)
        let successfulRetries = retryAttempts.count
        let failedRetries = retryAttempts.values.filter { $0 >= maxRetryAttempts }.count
        
        return RetryStatistics(
            totalRetryAttempts: totalAttempts,
            successfulRetries: successfulRetries,
            failedRetries: failedRetries,
            averageRetryDelay: retryDelays.values.isEmpty ? 0 : retryDelays.values.reduce(0, +) / Double(retryDelays.count)
        )
    }
}

// MARK: - Supporting Types

struct RetryStatistics {
    let totalRetryAttempts: Int
    let successfulRetries: Int
    let failedRetries: Int
    let averageRetryDelay: TimeInterval
    
    var successRate: Double {
        guard totalRetryAttempts > 0 else { return 0 }
        return Double(successfulRetries) / Double(totalRetryAttempts)
    }
    
    var failureRate: Double {
        guard totalRetryAttempts > 0 else { return 0 }
        return Double(failedRetries) / Double(totalRetryAttempts)
    }
}

// MARK: - Upload Error

enum UploadError: LocalizedError {
    case networkUnavailable
    case timeout
    case serverError(Int)
    case invalidImage
    case compressionFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .timeout:
            return "Upload timed out"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidImage:
            return "Invalid image data"
        case .compressionFailed:
            return "Image compression failed"
        case .unknown:
            return "Unknown upload error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .timeout:
            return "Try again when you have a better connection"
        case .serverError:
            return "Please try again later"
        case .invalidImage:
            return "Try selecting a different image"
        case .compressionFailed:
            return "Try with a smaller image"
        case .unknown:
            return "Please try again"
        }
    }
}

// MARK: - HTTP Error

struct HTTPError: Error {
    let statusCode: Int
    let message: String?
    
    init(statusCode: Int, message: String? = nil) {
        self.statusCode = statusCode
        self.message = message
    }
}

// MARK: - Validation Error

enum ValidationError: LocalizedError {
    case invalidImageFormat
    case imageTooLarge
    case missingRequiredField(String)
    case invalidChildId
    
    var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Invalid image format"
        case .imageTooLarge:
            return "Image is too large"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidChildId:
            return "Invalid child ID"
        }
    }
}

// MARK: - Retry UI Components

struct RetryButton: View {
    let uploadTask: UploadTask
    let onRetry: () -> Void
    
    @StateObject private var retryManager = UploadRetryManager()
    
    var body: some View {
        Button(action: onRetry) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Retry")
            }
        }
        .disabled(retryManager.isRetrying)
    }
}

struct RetryStatusView: View {
    let uploadTask: UploadTask
    @StateObject private var retryManager = UploadRetryManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = uploadTask.error {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let attempts = retryManager.retryAttempts[uploadTask.id], attempts > 0 {
                Text("Retry attempts: \(attempts)/\(retryManager.maxRetryAttempts)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if retryManager.isRetrying {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Retrying...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - SwiftUI Import

import SwiftUI
