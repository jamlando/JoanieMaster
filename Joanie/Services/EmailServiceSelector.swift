//
//  EmailServiceSelector.swift
//  Joanie
//
//  Email Service Selection Logic
//  Manages service health tracking and automatic service switching
//

import Foundation

// MARK: - Email Service Selector

@MainActor
class EmailServiceSelector: ObservableObject {
    // MARK: - Configuration
    private let maxConsecutiveFailures = 3
    private let recoveryTimeMinutes = 5
    private let healthCheckInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - State Tracking
    @Published var selectedService: EmailServiceType = .resend
    @Published var serviceHealth: [EmailServiceType: ServiceHealthStatus] = [:]
    @Published var consecutiveFailures: Int = 0
    @Published var lastFailureTime: Date?
    @Published var lastHealthCheck: Date?
    @Published var healthCheckInProgress: Bool = false
    
    // MARK: - Statistics
    @Published var primaryServiceFailures: Int = 0
    @Published var fallbackAttempts: Int = 0
    @Published var successfulRecoveries: Int = 0
    
    // MARK: - Service References
    private var primaryService: EmailService?
    private var fallbackService: EmailService?
    
    // MARK: - Callbacks
    var onPrimaryServiceSelected: (() -> Void)?
    var onFallbackServiceSelected: (() -> Void)?
    var onHealthCheckCompleted: ((ServiceHealthStatus) -> Void)?
    
    // MARK: - Initialization
    init() {
        initializeHealthStates()
        startHealthMonitoring()
        
        Logger.shared.info("EmailServiceSelector initialized", metadata: [
            "maxFailures": maxConsecutiveFailures,
            "recoveryTime": "\(recoveryTimeMinutes)m",
            "healthCheckInterval": "\(Int(healthCheckInterval))s"
        ])
    }
    
    // MARK: - Service Registration
    
    func registerServices(primary: EmailService, fallback: EmailService) {
        self.primaryService = primary
        self.fallbackService = fallback
        
        Logger.shared.info("Services registered", metadata: [
            "primaryType": String(describing: type(of: primary)),
            "fallbackType": String(describing: type(of: fallback))
        ])
    }
    
    // MARK: - Service Selection
    
    /// Get the currently active service
    var activeService: EmailService? {
        switch selectedService {
        case .resend, .mock:
            return primaryService
        case .supabase:
            return fallbackService
        }
    }
    
    /// Check if primary service should be selected
    var shouldUsePrimaryService: Bool {
        guard let primaryHealth = serviceHealth[.resend] else { return false }
        return primaryHealth == .healthy && consecutiveFailures < maxConsecutiveFailures
    }
    
    /// Check if fallback should be triggered
    var shouldFallback: Bool {
        return !shouldUsePrimaryService && hasRecoveryConditionMet
    }
    
    /// Select primary service (Resend/Mock)
    func selectPrimaryService() {
        selectedService = .resend
        consecutiveFailures = 0
        lastFailureTime = nil
        
        Logger.shared.info("Primary service selected", metadata: [
            "service": selectedService.rawValue
        ])
        
        onPrimaryServiceSelected?()
    }
    
    /// Select fallback service (Supabase)
    func selectFallbackService() {
        selectedService = .supabase
        fallbackAttempts += 1
        
        Logger.shared.info("Fallback service selected", metadata: [
            "service": selectedService.rawValue,
            "attemptCount": fallbackAttempts
        ])
        
        onFallbackServiceSelected?()
    }
    
    // MARK: - Health Tracking
    
    /// Record successful email operation
    func recordSuccess() {
        guard consecutiveFailures > 0 else { return }
        
        consecutiveFailures = 0
        lastFailureTime = nil
        
        if selectedService != .resend {
            successfulRecoveries += 1
            
            Logger.shared.info("Service recovered", metadata: [
                "service": selectedService.rawValue,
                "recoveryCount": successfulRecoveries
            ])
            
            // Consider switching back to primary service
            evaluateServiceSwitch()
        }
    }
    
    /// Record failed email operation
    func recordFailure(_ error: Error) {
        consecutiveFailures += 1
        lastFailureTime = Date()
        primaryServiceFailures += 1
        
        // Update health status based on error type
        if let emailError = error as? EmailError {
            updateHealthFromError(emailError)
        } else {
            serviceHealth[.resend] = .degraded
        }
        
        if selectedService == .resend && consecutiveFailures >= maxConsecutiveFailures {
            selectFallbackService()
        }
        
        Logger.shared.warning("Service failure recorded", metadata: [
            "error": error.localizedDescription,
            "consecutiveFailures": consecutiveFailures,
            "totalFailures": primaryServiceFailures,
            "serviceSwitch": selectedService != .resend
        ])
    }
    
    /// Perform comprehensive health check
    func performHealthCheck() async -> HealthCheckResult {
        guard !healthCheckInProgress else {
            return HealthCheckResult(
                isHealthy: false,
                servicesChecked: [],
                error: EmailError.serviceHealthCheckFailed("Health check already in progress")
            )
        }
        
        healthCheckInProgress = true
        lastHealthCheck = Date()
        
        var servicesChecked: [EmailServiceType] = []
        var healthyServices: [EmailServiceType] = []
        var errors: [Error] = []
        
        // Check primary service
        if let primaryService = primaryService {
            servicesChecked.append(.resend)
            
            if let resendService = primaryService as? ResendService {
                do {
                    let health = await resendService.checkHealth()
                    serviceHealth[.resend] = health.isHealthy ? .healthy : .unhealthy
                    
                    if health.isHealthy {
                        healthyServices.append(.resend)
                    }
                } catch {
                    serviceHealth[.resend] = .unhealthy
                    errors.append(error)
                }
            } else {
                serviceHealth[.resend] = .unknown
            }
        }
        
        // Check fallback service
        if let fallbackService = fallbackService {
            servicesChecked.append(.supabase)
            
            if let supabaseService = fallbackService as? SupabaseEmailService {
                do {
                    let health = await supabaseService.checkHealth()
                    serviceHealth[.supabase] = health.isHealthy ? .healthy : .unhealthy
                    
                    if health.isHealthy {
                        healthyServices.append(.supabase)
                    }
                } catch {
                    serviceHealth[.supabase] = .unhealthy
                    errors.append(error)
                }
            } else {
                serviceHealth[.supabase] = .unknown
            }
        }
        
        healthCheckInProgress = false
        
        let isHealthy = !healthyServices.isEmpty
        let overallHealthStatus = determineOverallHealthStatus(healthyServices: healthyServices)
        
        let result = HealthCheckResult(
            isHealthy: isHealthy,
            servicesChecked: servicesChecked,
            healthyServices: healthyServices,
            errors: errors,
            overallHealthStatus: overallHealthStatus
        )
        
        Logger.shared.info("Health check completed", metadata: [
            "isHealthy": isHealthy,
            "servicesChecked": servicesChecked.map { $0.rawValue }.joined(separator: ", "),
            "healthyServices": healthyServices.map { $0.rawValue }.joined(separator: ", "),
            "overallStatus": overallHealthStatus.rawValue
        ])
        
        onHealthCheckCompleted?(overallHealthStatus)
        
        return result
    }
    
    /// Force health check for specific service
    func forceHealthCheck(for serviceType: EmailServiceType) async -> Bool {
        switch serviceType {
        case .resend:
            guard let primaryService = primaryService as? ResendService else { return false }
            do {
                let health = await primaryService.checkHealth()
                serviceHealth[.resend] = health.isHealthy ? .healthy : .unhealthy
                return health.isHealthy
            } catch {
                serviceHealth[.resend] = .unhealthy
                return false
            }
        case .supabase:
            guard let fallbackService = fallbackService as? SupabaseEmailService else { return false }
            do {
                let health = await fallbackService.checkHealth()
                serviceHealth[.supabase] = health.isHealthy ? .healthy : .unhealthy
                return health.isHealthy
            } catch {
                serviceHealth[.supabase] = .unhealthy
                return false
            }
        case .mock:
            serviceHealth[.mock] = .healthy
            return true
        }
    }
    
    /// Get current service statistics
    func getStatistics() -> ServiceSelectorStatistics {
        return ServiceSelectorStatistics(
            selectedService: selectedService,
            consecutiveFailures: consecutiveFailures,
            primaryServiceFailures: primaryServiceFailures,
            fallbackAttempts: fallbackAttempts,
            successfulRecoveries: successfulRecoveries,
            serviceHealth: serviceHealth,
            healthCheckHistory: getHealthCheckHistory(),
            lastHealthCheck: lastHealthCheck
        )
    }
    
    /// Reset statistics
    func resetStatistics() {
        consecutiveFailures = 0
        primaryServiceFailures = 0
        fallbackAttempts = 0
        successfulRecoveries = 0
        lastFailureTime = nil
        
        Logger.shared.info("Service selector statistics reset")
    }
    
    // MARK: - Private Methods
    
    private func initializeHealthStates() {
        serviceHealth[.resend] = .unknown
        serviceHealth[.supabase] = .unknown
        serviceHealth[.mock] = .healthy
    }
    
    private func startHealthMonitoring() {
        Task {
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
                
                await performHealthCheck()
            }
        }
    }
    
    private func updateHealthFromError(_ error: EmailError) {
        switch error.severity {
        case .critical:
            serviceHealth[.resend] = .unhealthy
        case .error:
            serviceHealth[.resend] = .degraded
        case .warning:
            if consecutiveFailures >= maxConsecutiveFailures {
                serviceHealth[.resend] = .degraded
            }
        case .info:
            // Don't update health for info-level errors
            break
        }
    }
    
    private func evaluateServiceSwitch() {
        switch selectedService {
        case .supabase:
            // If primary service is healthy and we've had time to recover, consider switching back
            if shouldUsePrimaryService && hasRecoveryTimeElapsed {
                selectPrimaryService()
            }
        case .resend:
            // Already using primary service
            break
        case .mock:
            // Test service, typically don't switch away
            break
        }
    }
    
    private var hasRecoveryConditionMet: Bool {
        guard let lastFailure = lastFailureTime else { return true }
        return Date().timeIntervalSince(lastFailure) > TimeInterval(recoveryTimeMinutes * 60)
    }
    
    private var hasRecoveryTimeElapsed: Bool {
        guard let lastFailure = lastFailureTime else { return true }
        return Date().timeIntervalSince(lastFailure) > TimeInterval(recoveryTimeMinutes * 60)
    }
    
    private func determineOverallHealthStatus(healthyServices: [EmailServiceType]) -> ServiceHealthStatus {
        if healthyServices.contains(.resend) {
            return .healthy
        } else if healthyServices.contains(.supabase) {
            return .degraded
        } else {
            return .unhealthy
        }
    }
    
    private func getHealthCheckHistory() -> [HealthCheckEntry] {
        // Simplified health check history
        // In a real implementation, this would track historical health data
        return []
    }
}

// MARK: - Supporting Types

/// Health check result container
struct HealthCheckResult {
    let isHealthy: Bool
    let servicesChecked: [EmailServiceType]
    let healthyServices: [EmailServiceType]
    let errors: [Error]
    let overallHealthStatus: ServiceHealthStatus
    
    init(
        isHealthy: Bool,
        servicesChecked: [EmailServiceType],
        healthyServices: [EmailServiceType] = [],
        errors: [Error] = [],
        overallHealthStatus: ServiceHealthStatus = .unknown
    ) {
        self.isHealthy = isHealthy
        self.servicesChecked = servicesChecked
        self.healthyServices = healthyServices
        self.errors = errors
        self.overallHealthStatus = overallHealthStatus
    }
    
    var summary: [String: Any] {
        return [
            "isHealthy": isHealthy,
            "servicesChecked": servicesChecked.map { $0.rawValue },
            "healthyServices": healthyServices.map { $0.rawValue },
            "errorCount": errors.count,
            "overallStatus": overallHealthStatus.rawValue
        ]
    }
}

/// Service selector statistics
struct ServiceSelectorStatistics {
    let selectedService: EmailServiceType
    let consecutiveFailures: Int
    let primaryServiceFailures: Int
    let fallbackAttempts: Int
    let successfulRecoveries: Int
    let serviceHealth: [EmailServiceType: ServiceHealthStatus]
    let healthCheckHistory: [HealthCheckEntry]
    let lastHealthCheck: Date?
    
    var summary: [String: Any] {
        return [
            "selectedService": selectedService.rawValue,
            "consecutiveFailures": consecutiveFailures,
            "primaryFailures": primaryServiceFailures,
            "fallbackAttempts": fallbackAttempts,
            "successfulRecoveries": successfulRecoveries,
            "serviceHealth": serviceHealth.mapValues { $0.rawValue },
            "healthCheckHistoryCount": healthCheckHistory.count,
            "lastHealthCheck": lastHealthCheck?.timeIntervalSince1970 ?? 0
        ]
    }
}

/// Health check history entry
struct HealthCheckEntry {
    let timestamp: Date
    let serviceType: EmailServiceType
    let healthStatus: ServiceHealthStatus
    let responseTime: TimeInterval?
    let error: Error?
}
