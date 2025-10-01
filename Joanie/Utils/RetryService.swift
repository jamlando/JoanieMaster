import Foundation
import Combine

// MARK: - Retry Service

class RetryService {
    static let shared = RetryService()
    
    private init() {}
    
    // MARK: - Retry Configuration
    
    struct RetryConfig {
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double
        let jitter: Bool
        
        static let `default` = RetryConfig(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0,
            jitter: true
        )
        
        static let network = RetryConfig(
            maxAttempts: 5,
            baseDelay: 0.5,
            maxDelay: 60.0,
            backoffMultiplier: 2.0,
            jitter: true
        )
        
        static let quick = RetryConfig(
            maxAttempts: 2,
            baseDelay: 0.1,
            maxDelay: 5.0,
            backoffMultiplier: 2.0,
            jitter: false
        )
    }
    
    // MARK: - Retry Result
    
    enum RetryResult<T> {
        case success(T)
        case failure(Error)
        case maxAttemptsReached(Error)
    }
    
    // MARK: - Public Methods
    
    /// Retry an async operation with exponential backoff
    func retry<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = .default,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async -> RetryResult<T> {
        
        var lastError: Error?
        
        for attempt in 1...config.maxAttempts {
            do {
                let result = try await operation()
                Logger.shared.logInfo("RetryService: Operation succeeded on attempt \(attempt)")
                return .success(result)
            } catch {
                lastError = error
                Logger.shared.logError("RetryService: Attempt \(attempt) failed with error: \(error)")
                
                // Check if we should retry this error
                guard shouldRetry(error) else {
                    Logger.shared.logInfo("RetryService: Error is not retryable, stopping")
                    return .failure(error)
                }
                
                // Check if this is the last attempt
                guard attempt < config.maxAttempts else {
                    Logger.shared.logError("RetryService: Max attempts (\(config.maxAttempts)) reached")
                    return .maxAttemptsReached(error)
                }
                
                // Calculate delay for next attempt
                let delay = calculateDelay(for: attempt, config: config)
                Logger.shared.logInfo("RetryService: Waiting \(delay) seconds before retry \(attempt + 1)")
                
                // Wait before next attempt
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        return .maxAttemptsReached(lastError ?? RetryError.maxAttemptsReached)
    }
    
    /// Retry an async operation with custom retry logic
    func retryWithCustomLogic<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = .default,
        retryLogic: @escaping (Error, Int) -> Bool
    ) async -> RetryResult<T> {
        
        var lastError: Error?
        
        for attempt in 1...config.maxAttempts {
            do {
                let result = try await operation()
                Logger.shared.logInfo("RetryService: Operation succeeded on attempt \(attempt)")
                return .success(result)
            } catch {
                lastError = error
                Logger.shared.logError("RetryService: Attempt \(attempt) failed with error: \(error)")
                
                // Use custom retry logic
                guard retryLogic(error, attempt) else {
                    Logger.shared.logInfo("RetryService: Custom retry logic says not to retry")
                    return .failure(error)
                }
                
                // Check if this is the last attempt
                guard attempt < config.maxAttempts else {
                    Logger.shared.logError("RetryService: Max attempts (\(config.maxAttempts)) reached")
                    return .maxAttemptsReached(error)
                }
                
                // Calculate delay for next attempt
                let delay = calculateDelay(for: attempt, config: config)
                Logger.shared.logInfo("RetryService: Waiting \(delay) seconds before retry \(attempt + 1)")
                
                // Wait before next attempt
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        return .maxAttemptsReached(lastError ?? RetryError.maxAttemptsReached)
    }
    
    /// Retry with authentication error handling
    func retryWithAuthErrorHandling<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = .default
    ) async -> RetryResult<T> {
        
        return await retryWithCustomLogic(
            operation: operation,
            config: config
        ) { error, attempt in
            // Check if error is retryable
            if let authError = error as? AuthenticationError {
                return authError.canRetry
            }
            
            // Check for network errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
                    return true
                default:
                    return false
                }
            }
            
            // Check for server errors (5xx)
            if let httpError = error as? HTTPError {
                return httpError.statusCode >= 500
            }
            
            // Default retry logic
            return attempt < 2 // Only retry once for unknown errors
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateDelay(for attempt: Int, config: RetryConfig) -> TimeInterval {
        // Calculate exponential backoff
        let exponentialDelay = config.baseDelay * pow(config.backoffMultiplier, Double(attempt - 1))
        
        // Apply maximum delay limit
        let cappedDelay = min(exponentialDelay, config.maxDelay)
        
        // Add jitter if enabled
        if config.jitter {
            let jitterRange = cappedDelay * 0.1 // 10% jitter
            let jitter = Double.random(in: -jitterRange...jitterRange)
            return max(0, cappedDelay + jitter)
        }
        
        return cappedDelay
    }
}

// MARK: - Retry Error

enum RetryError: Error, LocalizedError {
    case maxAttemptsReached
    case operationCancelled
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .maxAttemptsReached:
            return "Maximum retry attempts reached"
        case .operationCancelled:
            return "Operation was cancelled"
        case .invalidConfiguration:
            return "Invalid retry configuration"
        }
    }
}

// MARK: - Retryable Protocol

protocol Retryable {
    func shouldRetry(error: Error, attempt: Int) -> Bool
}

// MARK: - Authentication Retry Handler

class AuthenticationRetryHandler: Retryable {
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Don't retry authentication errors that are not retryable
        if let authError = error as? AuthenticationError {
            return authError.canRetry
        }
        
        // Retry network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        
        // Retry server errors (5xx)
        if let httpError = error as? HTTPError {
            return httpError.statusCode >= 500
        }
        
        // Don't retry other errors
        return false
    }
}

// MARK: - Network Retry Handler

class NetworkRetryHandler: Retryable {
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Always retry network-related errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .slowServerResponse:
                return true
            default:
                return false
            }
        }
        
        // Retry server errors
        if let httpError = error as? HTTPError {
            return httpError.statusCode >= 500
        }
        
        // Check error message for network-related keywords
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("connection") || message.contains("timeout") {
            return true
        }
        
        return false
    }
}

// MARK: - Retry Statistics

struct RetryStatistics {
    let totalAttempts: Int
    let successfulAttempt: Int?
    let totalDuration: TimeInterval
    let errors: [Error]
    
    var isSuccessful: Bool {
        return successfulAttempt != nil
    }
    
    var averageDelay: TimeInterval {
        guard totalAttempts > 1 else { return 0 }
        return totalDuration / Double(totalAttempts - 1)
    }
}

// MARK: - Retry Service with Statistics

extension RetryService {
    /// Retry with detailed statistics
    func retryWithStatistics<T>(
        operation: @escaping () async throws -> T,
        config: RetryConfig = .default,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async -> (result: RetryResult<T>, statistics: RetryStatistics) {
        
        let startTime = Date()
        var errors: [Error] = []
        var successfulAttempt: Int?
        
        let result = await retry(
            operation: {
                do {
                    let result = try await operation()
                    if successfulAttempt == nil {
                        successfulAttempt = errors.count + 1
                    }
                    return result
                } catch {
                    errors.append(error)
                    throw error
                }
            },
            config: config,
            shouldRetry: shouldRetry
        )
        
        let statistics = RetryStatistics(
            totalAttempts: errors.count + (successfulAttempt != nil ? 1 : 0),
            successfulAttempt: successfulAttempt,
            totalDuration: Date().timeIntervalSince(startTime),
            errors: errors
        )
        
        return (result, statistics)
    }
}
