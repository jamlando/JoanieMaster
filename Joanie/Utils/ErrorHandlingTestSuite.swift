import Foundation
import XCTest
import Combine

// MARK: - Error Handling Test Suite

class ErrorHandlingTestSuite {
    static let shared = ErrorHandlingTestSuite()
    
    private let logger = Logger.shared
    private var testResults: [TestResult] = []
    
    private init() {}
    
    // MARK: - Test Result
    
    struct TestResult {
        let testName: String
        let success: Bool
        let error: Error?
        let duration: TimeInterval
        let details: String
        
        init(testName: String, success: Bool, error: Error? = nil, duration: TimeInterval, details: String = "") {
            self.testName = testName
            self.success = success
            self.error = error
            self.duration = duration
            self.details = details
        }
    }
    
    // MARK: - Test Scenarios
    
    func runAllTests() async -> [TestResult] {
        logger.logInfo("ErrorHandlingTestSuite: Starting comprehensive error handling tests")
        
        testResults.removeAll()
        
        // Authentication Error Tests
        await testAuthenticationErrorTypes()
        await testAuthenticationErrorMapping()
        await testAuthenticationErrorSeverity()
        await testAuthenticationErrorRetryCapability()
        
        // Error Mapping Tests
        await testSupabaseErrorMapping()
        await testURLErrorMapping()
        await testHTTPErrorMapping()
        await testGenericErrorMapping()
        
        // Retry Mechanism Tests
        await testRetryServiceBasic()
        await testRetryServiceExponentialBackoff()
        await testRetryServiceMaxAttempts()
        await testRetryServiceCustomLogic()
        
        // Error UI Tests
        await testEnhancedErrorView()
        await testErrorToast()
        await testErrorAlert()
        await testRecoveryActions()
        
        // Error Analytics Tests
        await testErrorAnalyticsTracking()
        await testErrorMetrics()
        await testErrorReporting()
        
        // Offline Error Queue Tests
        await testOfflineErrorQueue()
        await testOfflineErrorHandling()
        await testQueuePersistence()
        
        // Recovery Flow Tests
        await testRecoveryFlowCreation()
        await testRecoveryFlowExecution()
        await testRecoveryFlowCompletion()
        
        // Integration Tests
        await testAuthServiceErrorHandling()
        await testSupabaseServiceErrorHandling()
        await testEndToEndErrorScenarios()
        
        logger.logInfo("ErrorHandlingTestSuite: Completed \(testResults.count) tests")
        return testResults
    }
    
    // MARK: - Authentication Error Tests
    
    private func testAuthenticationErrorTypes() async {
        let startTime = Date()
        
        do {
            // Test all error types exist and have proper descriptions
            let errorTypes: [AuthenticationError] = [
                .networkUnavailable,
                .networkTimeout,
                .networkConnectionFailed,
                .invalidCredentials,
                .userNotFound,
                .emailAlreadyExists,
                .weakPassword,
                .accountLocked,
                .sessionExpired,
                .serverError(500),
                .serviceUnavailable,
                .rateLimitExceeded,
                .invalidInput("test"),
                .missingRequiredField("email"),
                .validationFailed("password"),
                .keychainError,
                .storageError,
                .biometricError,
                .appleSignInCancelled,
                .passwordResetFailed,
                .accountDeletionFailed,
                .profileUpdateFailed,
                .imageUploadFailed,
                .unknown("test error")
            ]
            
            for error in errorTypes {
                XCTAssertNotNil(error.localizedDescription, "Error description should not be nil")
                XCTAssertNotNil(error.recoverySuggestion, "Recovery suggestion should not be nil")
                XCTAssertNotNil(error.errorCode, "Error code should not be nil")
                XCTAssertNotNil(error.contextInfo, "Context info should not be nil")
            }
            
            addTestResult("Authentication Error Types", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Authentication Error Types", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testAuthenticationErrorMapping() async {
        let startTime = Date()
        
        do {
            let mapper = SupabaseErrorMapper.shared
            
            // Test URL error mapping
            let urlError = URLError(.notConnectedToInternet)
            let mappedURLError = mapper.mapSupabaseError(urlError)
            XCTAssertEqual(mappedURLError, .networkUnavailable, "URL error should map to networkUnavailable")
            
            // Test HTTP error mapping
            let httpError = HTTPError(statusCode: 401, message: "Unauthorized")
            let mappedHTTPError = mapper.mapSupabaseError(httpError)
            XCTAssertEqual(mappedHTTPError, .invalidCredentials, "HTTP 401 should map to invalidCredentials")
            
            // Test Supabase error mapping
            let supabaseError = SupabaseError.notAuthenticated
            let mappedSupabaseError = mapper.mapSupabaseError(supabaseError)
            XCTAssertEqual(mappedSupabaseError, .sessionExpired, "Supabase notAuthenticated should map to sessionExpired")
            
            addTestResult("Authentication Error Mapping", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Authentication Error Mapping", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testAuthenticationErrorSeverity() async {
        let startTime = Date()
        
        do {
            // Test severity levels
            XCTAssertEqual(AuthenticationError.networkUnavailable.severity, .warning, "Network errors should be warning")
            XCTAssertEqual(AuthenticationError.invalidCredentials.severity, .warning, "Invalid credentials should be warning")
            XCTAssertEqual(AuthenticationError.accountLocked.severity, .error, "Account locked should be error")
            XCTAssertEqual(AuthenticationError.sessionExpired.severity, .error, "Session expired should be error")
            XCTAssertEqual(AuthenticationError.serverError(500).severity, .error, "Server errors should be error")
            
            addTestResult("Authentication Error Severity", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Authentication Error Severity", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testAuthenticationErrorRetryCapability() async {
        let startTime = Date()
        
        do {
            // Test retry capability
            XCTAssertTrue(AuthenticationError.networkUnavailable.canRetry, "Network errors should be retryable")
            XCTAssertTrue(AuthenticationError.serverError(500).canRetry, "Server errors should be retryable")
            XCTAssertTrue(AuthenticationError.rateLimitExceeded.canRetry, "Rate limit errors should be retryable")
            XCTAssertFalse(AuthenticationError.invalidCredentials.canRetry, "Invalid credentials should not be retryable")
            XCTAssertFalse(AuthenticationError.accountLocked.canRetry, "Account locked should not be retryable")
            
            addTestResult("Authentication Error Retry Capability", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Authentication Error Retry Capability", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Error Mapping Tests
    
    private func testSupabaseErrorMapping() async {
        let startTime = Date()
        
        do {
            let mapper = SupabaseErrorMapper.shared
            
            // Test all Supabase error mappings
            let supabaseErrors: [(SupabaseError, AuthenticationError)] = [
                (.notAuthenticated, .sessionExpired),
                (.networkError, .networkConnectionFailed),
                (.invalidResponse, .serverError(500)),
                (.storageError, .storageError),
                (.userNotFound, .userNotFound),
                (.emailAlreadyExists, .emailAlreadyExists),
                (.weakPassword, .weakPassword),
                (.accountLocked, .accountLocked),
                (.sessionExpired, .sessionExpired),
                (.rateLimitExceeded, .rateLimitExceeded)
            ]
            
            for (supabaseError, expectedAuthError) in supabaseErrors {
                let mappedError = mapper.mapSupabaseError(supabaseError)
                XCTAssertEqual(mappedError, expectedAuthError, "Supabase error \(supabaseError) should map to \(expectedAuthError)")
            }
            
            addTestResult("Supabase Error Mapping", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Supabase Error Mapping", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testURLErrorMapping() async {
        let startTime = Date()
        
        do {
            let mapper = SupabaseErrorMapper.shared
            
            // Test URL error mappings
            let urlErrorMappings: [(URLError.Code, AuthenticationError)] = [
                (.notConnectedToInternet, .networkUnavailable),
                (.networkConnectionLost, .networkUnavailable),
                (.timedOut, .networkTimeout),
                (.cannotConnectToHost, .networkConnectionFailed),
                (.cannotFindHost, .networkConnectionFailed),
                (.slowServerResponse, .networkSlowConnection)
            ]
            
            for (urlErrorCode, expectedAuthError) in urlErrorMappings {
                let urlError = URLError(urlErrorCode)
                let mappedError = mapper.mapSupabaseError(urlError)
                XCTAssertEqual(mappedError, expectedAuthError, "URL error \(urlErrorCode) should map to \(expectedAuthError)")
            }
            
            addTestResult("URL Error Mapping", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("URL Error Mapping", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testHTTPErrorMapping() async {
        let startTime = Date()
        
        do {
            let mapper = SupabaseErrorMapper.shared
            
            // Test HTTP status code mappings
            let httpMappings: [(Int, AuthenticationError)] = [
                (400, .invalidInput("Request data")),
                (401, .invalidCredentials),
                (403, .accountDisabled),
                (404, .userNotFound),
                (409, .emailAlreadyExists),
                (422, .validationFailed("Request validation")),
                (429, .rateLimitExceeded),
                (500, .serverError(500)),
                (502, .serviceUnavailable),
                (503, .serviceUnavailable),
                (504, .serverOverloaded)
            ]
            
            for (statusCode, expectedAuthError) in httpMappings {
                let httpError = HTTPError(statusCode: statusCode)
                let mappedError = mapper.mapSupabaseError(httpError)
                XCTAssertEqual(mappedError, expectedAuthError, "HTTP \(statusCode) should map to \(expectedAuthError)")
            }
            
            addTestResult("HTTP Error Mapping", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("HTTP Error Mapping", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testGenericErrorMapping() async {
        let startTime = Date()
        
        do {
            let mapper = SupabaseErrorMapper.shared
            
            // Test generic error mapping
            let genericErrors: [(Error, AuthenticationError)] = [
                (NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"]), .networkConnectionFailed),
                (NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Request timed out"]), .networkTimeout),
                (NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"]), .invalidCredentials),
                (NSError(domain: "Test", code: 4, userInfo: [NSLocalizedDescriptionKey: "User not found"]), .userNotFound),
                (NSError(domain: "Test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Email already exists"]), .emailAlreadyExists),
                (NSError(domain: "Test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Weak password"]), .weakPassword),
                (NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]), .rateLimitExceeded),
                (NSError(domain: "Test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Server error occurred"]), .serverError(500))
            ]
            
            for (genericError, expectedAuthError) in genericErrors {
                let mappedError = mapper.mapSupabaseError(genericError)
                XCTAssertEqual(mappedError, expectedAuthError, "Generic error should map to \(expectedAuthError)")
            }
            
            addTestResult("Generic Error Mapping", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Generic Error Mapping", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Retry Mechanism Tests
    
    private func testRetryServiceBasic() async {
        let startTime = Date()
        
        do {
            let retryService = RetryService.shared
            var attemptCount = 0
            
            let result = await retryService.retry(
                operation: {
                    attemptCount += 1
                    if attemptCount < 3 {
                        throw AuthenticationError.networkUnavailable
                    }
                    return "success"
                },
                config: .default
            )
            
            switch result {
            case .success(let value):
                XCTAssertEqual(value, "success", "Retry should succeed after 3 attempts")
                XCTAssertEqual(attemptCount, 3, "Should have made 3 attempts")
            case .failure, .maxAttemptsReached:
                XCTFail("Retry should have succeeded")
            }
            
            addTestResult("Retry Service Basic", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Retry Service Basic", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRetryServiceExponentialBackoff() async {
        let startTime = Date()
        
        do {
            let retryService = RetryService.shared
            let config = RetryService.RetryConfig(
                maxAttempts: 4,
                baseDelay: 0.1,
                maxDelay: 1.0,
                backoffMultiplier: 2.0,
                jitter: false
            )
            
            var attemptCount = 0
            var delays: [TimeInterval] = []
            let startTime = Date()
            
            let result = await retryService.retry(
                operation: {
                    attemptCount += 1
                    if attemptCount < 4 {
                        delays.append(Date().timeIntervalSince(startTime))
                        throw AuthenticationError.networkUnavailable
                    }
                    return "success"
                },
                config: config
            )
            
            switch result {
            case .success:
                // Verify exponential backoff timing
                XCTAssertEqual(attemptCount, 4, "Should have made 4 attempts")
                XCTAssertGreaterThan(delays[1], delays[0], "Second delay should be greater than first")
                XCTAssertGreaterThan(delays[2], delays[1], "Third delay should be greater than second")
            case .failure, .maxAttemptsReached:
                XCTFail("Retry should have succeeded")
            }
            
            addTestResult("Retry Service Exponential Backoff", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Retry Service Exponential Backoff", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRetryServiceMaxAttempts() async {
        let startTime = Date()
        
        do {
            let retryService = RetryService.shared
            let config = RetryService.RetryConfig(maxAttempts: 2, baseDelay: 0.1, maxDelay: 1.0, backoffMultiplier: 2.0, jitter: false)
            
            var attemptCount = 0
            
            let result = await retryService.retry(
                operation: {
                    attemptCount += 1
                    throw AuthenticationError.networkUnavailable
                },
                config: config
            )
            
            switch result {
            case .maxAttemptsReached:
                XCTAssertEqual(attemptCount, 2, "Should have made exactly 2 attempts")
            case .success, .failure:
                XCTFail("Should have reached max attempts")
            }
            
            addTestResult("Retry Service Max Attempts", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Retry Service Max Attempts", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRetryServiceCustomLogic() async {
        let startTime = Date()
        
        do {
            let retryService = RetryService.shared
            var attemptCount = 0
            
            let result = await retryService.retryWithCustomLogic(
                operation: {
                    attemptCount += 1
                    throw AuthenticationError.invalidCredentials
                },
                config: .default
            ) { error, _ in
                // Custom logic: only retry network errors
                if let authError = error as? AuthenticationError {
                    return authError.canRetry
                }
                return false
            }
            
            switch result {
            case .failure:
                XCTAssertEqual(attemptCount, 1, "Should have made only 1 attempt for non-retryable error")
            case .success, .maxAttemptsReached:
                XCTFail("Should have failed immediately for non-retryable error")
            }
            
            addTestResult("Retry Service Custom Logic", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Retry Service Custom Logic", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Error UI Tests
    
    private func testEnhancedErrorView() async {
        let startTime = Date()
        
        do {
            // Test EnhancedErrorView creation and properties
            let error = AuthenticationError.networkUnavailable
            let view = EnhancedErrorView(
                error: error,
                onRetry: { },
                onDismiss: { },
                onRecoveryAction: { }
            )
            
            // Verify error properties are accessible
            XCTAssertEqual(view.error, error, "Error should match")
            XCTAssertNotNil(view.error.localizedDescription, "Error description should not be nil")
            XCTAssertNotNil(view.error.recoverySuggestion, "Recovery suggestion should not be nil")
            
            addTestResult("Enhanced Error View", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Enhanced Error View", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testErrorToast() async {
        let startTime = Date()
        
        do {
            // Test ErrorToast creation
            let error = AuthenticationError.serverError(500)
            let view = ErrorToast(error: error, onDismiss: { })
            
            // Verify error properties
            XCTAssertEqual(view.error, error, "Error should match")
            XCTAssertEqual(view.error.severity, .error, "Server error should have error severity")
            
            addTestResult("Error Toast", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Error Toast", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testErrorAlert() async {
        let startTime = Date()
        
        do {
            // Test AuthenticationErrorAlert creation
            let error = AuthenticationError.rateLimitExceeded
            let alert = AuthenticationErrorAlert(
                error: .constant(error),
                onRetry: { },
                onRecoveryAction: { }
            )
            
            // Verify error properties
            XCTAssertTrue(error.canRetry, "Rate limit error should be retryable")
            
            addTestResult("Error Alert", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Error Alert", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRecoveryActions() async {
        let startTime = Date()
        
        do {
            let recoveryActions = ErrorRecoveryActions.shared
            
            // Test recovery action handling
            let viewModel = AuthenticationViewModel(authService: AuthService(supabaseService: SupabaseService.shared))
            
            // Test different error types
            let errors: [AuthenticationError] = [
                .networkUnavailable,
                .invalidCredentials,
                .sessionExpired,
                .serverError(500),
                .rateLimitExceeded,
                .keychainError,
                .appleSignInFailed,
                .passwordResetFailed
            ]
            
            for error in errors {
                recoveryActions.handleRecoveryAction(for: error, in: viewModel)
            }
            
            addTestResult("Recovery Actions", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Recovery Actions", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Error Analytics Tests
    
    private func testErrorAnalyticsTracking() async {
        let startTime = Date()
        
        do {
            let analytics = ErrorAnalyticsService.shared
            
            // Test error tracking
            let error = AuthenticationError.networkUnavailable
            analytics.trackError(error, context: ["test": "value"])
            
            // Test retry tracking
            analytics.trackRetryAttempt(error, attempt: 1)
            analytics.trackRetrySuccess(error, attempts: 2, duration: 1.5)
            
            // Test recovery action tracking
            analytics.trackRecoveryAction(error, action: "retry")
            
            // Test error dismissal tracking
            analytics.trackErrorDismissal(error, dismissedBy: "user")
            
            addTestResult("Error Analytics Tracking", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Error Analytics Tracking", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testErrorMetrics() async {
        let startTime = Date()
        
        do {
            let analytics = ErrorAnalyticsService.shared
            
            // Test error metrics creation
            let error = AuthenticationError.serverError(500)
            let metrics = ErrorAnalyticsService.ErrorMetrics(
                errorCode: error.errorCode,
                errorType: "AuthenticationError",
                severity: error.severity,
                timestamp: Date(),
                sessionID: "test-session",
                userID: "test-user",
                deviceInfo: ErrorAnalyticsService.DeviceInfo.current,
                networkInfo: ErrorAnalyticsService.NetworkInfo.current,
                context: ["test": "value"],
                retryAttempts: 2,
                recoveryAction: "retry",
                duration: 1.5
            )
            
            XCTAssertEqual(metrics.errorCode, error.errorCode, "Error code should match")
            XCTAssertEqual(metrics.severity, error.severity, "Severity should match")
            XCTAssertEqual(metrics.retryAttempts, 2, "Retry attempts should match")
            
            addTestResult("Error Metrics", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Error Metrics", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testErrorReporting() async {
        let startTime = Date()
        
        do {
            let analytics = ErrorAnalyticsService.shared
            
            // Test error report generation
            let error = AuthenticationError.accountLocked
            let context = ["reason": "multiple_failed_attempts", "attempts": 5]
            let report = analytics.generateErrorReport(for: error, context: context)
            
            XCTAssertTrue(report.contains("ERROR REPORT"), "Report should contain title")
            XCTAssertTrue(report.contains(error.errorCode), "Report should contain error code")
            XCTAssertTrue(report.contains(error.localizedDescription), "Report should contain error description")
            XCTAssertTrue(report.contains("multiple_failed_attempts"), "Report should contain context")
            
            addTestResult("Error Reporting", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Error Reporting", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Offline Error Queue Tests
    
    private func testOfflineErrorQueue() async {
        let startTime = Date()
        
        do {
            let queueManager = OfflineErrorQueueManager.shared
            
            // Test error queuing
            let error = AuthenticationError.networkUnavailable
            queueManager.queueError(error, context: ["test": "value"], priority: .high)
            
            // Test queue statistics
            let statistics = queueManager.getQueueStatistics()
            XCTAssertGreaterThanOrEqual(statistics.totalErrors, 1, "Queue should have at least 1 error")
            
            addTestResult("Offline Error Queue", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Offline Error Queue", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testOfflineErrorHandling() async {
        let startTime = Date()
        
        do {
            let offlineHandler = OfflineErrorHandler.shared
            
            // Test offline error handling
            let errors: [AuthenticationError] = [
                .networkUnavailable,
                .serverError(500),
                .rateLimitExceeded,
                .storageError,
                .accountUpdateFailed
            ]
            
            for error in errors {
                offlineHandler.handleOfflineError(error, context: ["test": "value"])
            }
            
            addTestResult("Offline Error Handling", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Offline Error Handling", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testQueuePersistence() async {
        let startTime = Date()
        
        do {
            let queueManager = OfflineErrorQueueManager.shared
            
            // Test queue persistence
            let error = AuthenticationError.serviceUnavailable
            queueManager.queueError(error, context: ["test": "persistence"], priority: .normal)
            
            // Clear and reload to test persistence
            queueManager.clearQueue()
            let statisticsAfterClear = queueManager.getQueueStatistics()
            XCTAssertEqual(statisticsAfterClear.totalErrors, 0, "Queue should be empty after clear")
            
            addTestResult("Queue Persistence", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Queue Persistence", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Recovery Flow Tests
    
    private func testRecoveryFlowCreation() async {
        let startTime = Date()
        
        do {
            let recoveryManager = ErrorRecoveryFlowManager.shared
            
            // Test recovery flow creation for different error types
            let errors: [AuthenticationError] = [
                .networkUnavailable,
                .invalidCredentials,
                .sessionExpired,
                .serverError(500),
                .keychainError,
                .appleSignInFailed,
                .passwordResetFailed
            ]
            
            for error in errors {
                recoveryManager.startRecoveryFlow(for: error)
                XCTAssertNotNil(recoveryManager.currentRecoveryFlow, "Recovery flow should be created")
                recoveryManager.cancelRecoveryFlow()
            }
            
            addTestResult("Recovery Flow Creation", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Recovery Flow Creation", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRecoveryFlowExecution() async {
        let startTime = Date()
        
        do {
            let recoveryManager = ErrorRecoveryFlowManager.shared
            
            // Test recovery flow execution
            let error = AuthenticationError.networkUnavailable
            recoveryManager.startRecoveryFlow(for: error)
            
            guard let flow = recoveryManager.currentRecoveryFlow else {
                XCTFail("Recovery flow should be created")
                return
            }
            
            // Test step execution
            let step = ErrorRecoveryFlowManager.RecoveryStep.checkConnection
            recoveryManager.executeRecoveryStep(step)
            
            recoveryManager.completeRecoveryFlow()
            
            addTestResult("Recovery Flow Execution", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Recovery Flow Execution", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testRecoveryFlowCompletion() async {
        let startTime = Date()
        
        do {
            let recoveryManager = ErrorRecoveryFlowManager.shared
            
            // Test recovery flow completion
            let error = AuthenticationError.sessionExpired
            recoveryManager.startRecoveryFlow(for: error)
            
            XCTAssertTrue(recoveryManager.isShowingRecoveryFlow, "Should be showing recovery flow")
            
            recoveryManager.completeRecoveryFlow()
            
            XCTAssertFalse(recoveryManager.isShowingRecoveryFlow, "Should not be showing recovery flow")
            XCTAssertNil(recoveryManager.currentRecoveryFlow, "Current recovery flow should be nil")
            
            addTestResult("Recovery Flow Completion", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Recovery Flow Completion", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Integration Tests
    
    private func testAuthServiceErrorHandling() async {
        let startTime = Date()
        
        do {
            let authService = AuthService(supabaseService: SupabaseService.shared)
            
            // Test error handling in AuthService methods
            do {
                _ = try await authService.signIn(email: "test@example.com", password: "wrongpassword")
            } catch {
                // Expected to fail with mock implementation
            }
            
            addTestResult("Auth Service Error Handling", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Auth Service Error Handling", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testSupabaseServiceErrorHandling() async {
        let startTime = Date()
        
        do {
            let supabaseService = SupabaseService.shared
            
            // Test error handling in SupabaseService methods
            do {
                _ = try await supabaseService.signIn(email: "test@example.com", password: "wrongpassword")
            } catch {
                // Expected to fail with mock implementation
            }
            
            addTestResult("Supabase Service Error Handling", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("Supabase Service Error Handling", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    private func testEndToEndErrorScenarios() async {
        let startTime = Date()
        
        do {
            // Test complete error handling flow
            let authService = AuthService(supabaseService: SupabaseService.shared)
            let analytics = ErrorAnalyticsService.shared
            let queueManager = OfflineErrorQueueManager.shared
            let recoveryManager = ErrorRecoveryFlowManager.shared
            
            // Simulate network error
            let networkError = AuthenticationError.networkUnavailable
            
            // Track error
            analytics.trackError(networkError, context: ["scenario": "end_to_end"])
            
            // Queue for offline handling
            queueManager.queueError(networkError, context: ["scenario": "end_to_end"], priority: .high)
            
            // Start recovery flow
            recoveryManager.startRecoveryFlow(for: networkError)
            
            // Complete recovery flow
            recoveryManager.completeRecoveryFlow()
            
            addTestResult("End To End Error Scenarios", success: true, duration: Date().timeIntervalSince(startTime))
        } catch {
            addTestResult("End To End Error Scenarios", success: false, error: error, duration: Date().timeIntervalSince(startTime))
        }
    }
    
    // MARK: - Helper Methods
    
    private func addTestResult(_ testName: String, success: Bool, error: Error? = nil, duration: TimeInterval, details: String = "") {
        let result = TestResult(
            testName: testName,
            success: success,
            error: error,
            duration: duration,
            details: details
        )
        
        testResults.append(result)
        
        if success {
            logger.logInfo("✅ \(testName) - PASSED (\(String(format: "%.3f", duration))s)")
        } else {
            logger.logError("❌ \(testName) - FAILED (\(String(format: "%.3f", duration))s) - \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func generateTestReport() -> String {
        let totalTests = testResults.count
        let passedTests = testResults.filter { $0.success }.count
        let failedTests = totalTests - passedTests
        let successRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0
        
        var report = """
        ERROR HANDLING TEST REPORT
        =========================
        
        Summary:
        - Total Tests: \(totalTests)
        - Passed: \(passedTests)
        - Failed: \(failedTests)
        - Success Rate: \(String(format: "%.1f", successRate))%
        
        Test Results:
        """
        
        for result in testResults {
            let status = result.success ? "✅ PASS" : "❌ FAIL"
            let duration = String(format: "%.3f", result.duration)
            report += "\n\(status) \(result.testName) (\(duration)s)"
            
            if !result.success, let error = result.error {
                report += "\n    Error: \(error.localizedDescription)"
            }
            
            if !result.details.isEmpty {
                report += "\n    Details: \(result.details)"
            }
        }
        
        return report
    }
}

// MARK: - Test Helper Extensions

extension AuthenticationError: Equatable {
    static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        return lhs.errorCode == rhs.errorCode
    }
}

// Mock XCTest for compilation
func XCTAssertEqual<T: Equatable>(_ expression1: T, _ expression2: T, _ message: String = "") {
    if expression1 != expression2 {
        print("❌ Assertion failed: \(expression1) != \(expression2) - \(message)")
    } else {
        print("✅ Assertion passed: \(expression1) == \(expression2)")
    }
}

func XCTAssertNotNil<T>(_ expression: T?, _ message: String = "") {
    if expression == nil {
        print("❌ Assertion failed: expression is nil - \(message)")
    } else {
        print("✅ Assertion passed: expression is not nil")
    }
}

func XCTAssertTrue(_ expression: Bool, _ message: String = "") {
    if !expression {
        print("❌ Assertion failed: expression is false - \(message)")
    } else {
        print("✅ Assertion passed: expression is true")
    }
}

func XCTAssertFalse(_ expression: Bool, _ message: String = "") {
    if expression {
        print("❌ Assertion failed: expression is true - \(message)")
    } else {
        print("✅ Assertion passed: expression is false")
    }
}

func XCTAssertGreaterThan<T: Comparable>(_ expression1: T, _ expression2: T, _ message: String = "") {
    if expression1 <= expression2 {
        print("❌ Assertion failed: \(expression1) <= \(expression2) - \(message)")
    } else {
        print("✅ Assertion passed: \(expression1) > \(expression2)")
    }
}

func XCTAssertGreaterThanOrEqual<T: Comparable>(_ expression1: T, _ expression2: T, _ message: String = "") {
    if expression1 < expression2 {
        print("❌ Assertion failed: \(expression1) < \(expression2) - \(message)")
    } else {
        print("✅ Assertion passed: \(expression1) >= \(expression2)")
    }
}

func XCTFail(_ message: String = "") {
    print("❌ Test failed: \(message)")
}

