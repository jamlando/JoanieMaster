//
//  EmailAnalyticsService.swift
//  Joanie
//
//  Email Analytics & Monitoring Service
//  Tracks email delivery metrics, performance analytics, and service health monitoring
//

import Foundation
import Combine

// MARK: - Email Analytics Service

@MainActor
class EmailAnalyticsService: ObservableObject {
    
    // MARK: - Properties
    private let logger: Logger
    private let keychainService: KeychainService?
    
    // MARK: - Published Analytics
    @Published var emailStatistics = EmailStatistics()
    @Published var serviceHealthMetrics = ServiceHealthMetrics()
    @Published var performanceMetrics = PerformanceMetrics()
    @Published var errorAnalytics = ErrorAnalytics()
    
    // MARK: - Analytics Storage
    private var emailEvents: [EmailAnalyticsEvent] = []
    private var serviceHealthHistory: [HealthCheckEvent] = []
    private var errorHistory: [ErrorEvent] = []
    private var performanceHistory: [PerformanceEvent] = []
    
    // MARK: - Real-time Monitoring
    @Published var realTimeEmailCount: Int = 0
    @Published var realTimeFailureRate: Double = 0.0
    @Published var realTimeResponseTime: TimeInterval = 0.0
    
    // MARK: - Configuration
    private let maxStoredEvents = 1000
    private let healthCheckInterval: TimeInterval = 300 // 5 minutes
    private let analyticsFlushInterval: TimeInterval = 3600 // 1 hour
    
    private var analyticsTimer: Timer?
    private var healthCheckTimer: Timer?
    
    // MARK: - Initialization
    init(logger: Logger = Logger.shared, keychainService: KeychainService? = KeychainService.shared) {
        self.logger = logger
        self.keychainService = keychainService
        
        startPeriodicTasks()
        
        logger.info("EmailAnalyticsService initialized", metadata: [
            "maxStoredEvents": maxStoredEvents,
            "healthCheckInterval": Int(healthCheckInterval),
            "analyticsFlushInterval": Int(analyticsFlushInterval)
        ])
    }
    
    deinit {
        stopPeriodicTasks()
    }
    
    // MARK: - Public Analytics Methods
    
    /// Track email sending event
    func trackEmailSent(_ result: EmailResult, template: EmailTemplate, metadata: EmailAnalyticsMetadata = EmailAnalyticsMetadata()) {
        let event = EmailAnalyticsEvent(
            id: UUID(),
            type: .emailSent,
            timestamp: Date(),
            emailResult: result,
            template: template,
            metadata: metadata
        )
        
        recordEvent(event)
        
        // Update real-time statistics
        updateRealTimeStatistics()
        
        logger.info("Email sent tracked", metadata: [
            "eventId": event.id.uuidString,
            "service": result.service.rawValue,
            "status": result.status.rawValue,
            "messageId": result.messageId ?? "",
            "template": template.rawValue
        ])
    }
    
    /// Track email failure event
    func trackEmailFailure(_ error: EmailError, template: EmailTemplate, metadata: EmailAnalyticsMetadata = EmailAnalyticsMetadata()) {
        let event = EmailAnalyticsEvent(
            id: UUID(),
            type: .emailFailed,
            timestamp: Date(),
            emailError: error,
            template: template,
            metadata: metadata
        )
        
        recordEvent(event)
        
        // Update error analytics
        updateErrorAnalytics(error)
        
        // Update real-time statistics
        updateRealTimeStatistics()
        
        logger.error("Email failure tracked", metadata: [
            "eventId": event.id.uuidString,
            "error": error.localizedDescription,
            "severity": error.severity.rawValue,
            "template": template.rawValue
        ])
    }
    
    /// Track service health check
    func trackHealthCheck(serviceType: EmailServiceType, health: EmailServiceHealth, metadata: HealthCheckMetadata = HealthCheckMetadata()) {
        let event = HealthCheckEvent(
            id: UUID(),
            timestamp: Date(),
            serviceType: serviceType,
            isHealthy: health.isHealthy,
            responseTime: health.responseTime,
            errors: health.error?.localizedDescription,
            metadata: metadata
        )
        
        recordHealthEvent(event)
        
        // Update service health metrics
        updateServiceHealthMetrics(event)
        
        logger.debug("Health check tracked", metadata: [
            "service": serviceType.rawValue,
            "healthy": health.isHealthy,
            "responseTime": health.responseTime ?? 0
        ])
    }
    
    /// Track performance metrics
    func trackPerformance<T>(_ operation: EmailOperation, duration: TimeInterval, result: T?, metadata: PerformanceMetadata = PerformanceMetadata()) {
        let event = PerformanceEvent(
            id: UUID(),
            timestamp: Date(),
            operation: operation,
            duration: duration,
            success: result != nil,
            metadata: metadata
        )
        
        recordPerformanceEvent(event)
        
        // Update performance metrics
        updatePerformanceMetrics(event)
        
        logger.debug("Performance tracked", metadata: [
            "operation": operation.rawValue,
            "duration": duration,
            "success": result != nil
        ])
    }
    
    /// Track service switching event
    func trackServiceSwitch(from: EmailServiceType, to: EmailService Type, reason: ServiceSwitchReason, metadata: ServiceSwitchMetadata = ServiceSwitchMetadata()) {
        let event = ServiceSwitchEvent(
            id: UUID(),
            timestamp: Date(),
            fromService: from,
            toService: to,
            reason: reason,
            metadata: metadata
        )
        
        recordServiceSwitchEvent(event)
        
        logger.info("Service switch tracked", metadata: [
            "from": from.rawValue,
            "to": to.rawValue,
            "reason": reason.rawValue
        ])
    }
    
    // MARK: - Analytics Queries
    
    /// Get comprehensive email statistics
    func getEmailStatistics(for period: AnalyticsPeriod = .last24Hours) -> EmailStatistics {
        let filtered = filterEventsByPeriod(emailEvents, period: period)
        
        return EmailStatistics(
            totalSent: filtered.filter { $0.type == .emailSent }.count,
            totalFailed: filtered.filter { $0.type == .emailFailed }.count,
            successRate: calculateSuccessRate(filtered),
            averageResponseTime: calculateAverageResponseTime(filtered),
            serviceBreakdown: calculateServiceBreakdown(filtered),
            templateBreakdown: calculateTemplateBreakdown(filtered),
            period: period,
            lastUpdated: Date()
        )
    }
    
    /// Get service health analytics
    func getServiceHealthAnalytics(for period: AnalyticsPeriod = .last24Hours) -> ServiceHealthAnalytics {
        let filtered = filterHealthEventsByPeriod(serviceHealthHistory, period: period)
        let services = Set(filtered.map { $0.serviceType })
        
        var serviceHealth: [EmailServiceType: ServiceHealthSummary] = [:]
        
        for service in services {
            let serviceEvents = filtered.filter { $0.serviceType == service }
            serviceHealth[service] = ServiceHealthSummary(
                serviceType: service,
                healthPercentage: calculateHealthPercentate(serviceEvents),
                averageResponseTime: calculateAverageHealthResponseTime(serviceEvents),
                totalChecks: serviceEvents.count,
                lastCheckTime: serviceEvents.last?.timestamp,
                uptime: calculateUptime(serviceEvents)
            )
        }
        
        return ServiceHealthAnalytics(
            overallHealthPercentage: calculateOverallHealthPercentage(filtered),
            serviceHealth: serviceHealth,
            period: period,
            lastUpdated: Date()
        )
    }
    
    /// Get performance analytics
    func getPerformanceAnalytics(for period: AnalyticsPeriod = .last24Hours) -> PerformanceAnalytics {
        let filtered = filterPerformanceEventsByPeriod(performance History, period: period)
        
        return PerformanceAnalytics(
            averageResponseTime: calculateAveragePerformanceTime(filtered),
            operationsBreakdown: calculateOperationsBreakdown(filtered),
            slowestOperations: getSlowestOperations(filtered, limit: 10),
            performanceTrends: calculatePerformanceTrends(filtered),
            period: period,
            lastUpdated: Date()
        )
    }
    
    /// Get error analytics
    func getErrorAnalytics(for period: AnalyticsPeriod = .last24Hours) -> ErrorAnalyticsDetail {
        let filtered = filterErrorEventsByPeriod(errorHistory, period: period)
        
        return ErrorAnalyticsDetail(
            totalErrors: filtered.count,
            errorBreakdown: calculateErrorBre askdown(filtered),
            errorTrends: calculateErrorTrends(filtered),
            mostCommonErrors: getMostCommonErrors(filtered, limit: 10),
            recoveryTime: calculateAverageRecoveryTime(filtered),
            period: period,
            lastUpdated: Date()
        )
    }
    
    /// Export analytics data
    func exportAnalyticsData(for period: AnalyticsPeriod = .allTime) -> AnalyticsExport {
        return AnalyticsExport(
            emailEvents: filterEventsByPeriod(emailEvents, period: period),
            healthEvents: filterHealthEventsByPeriod(serviceHealthHistory, period: period),
            performanceEvents: filterPerformanceEventsByPeriod(performanceHistory, period: period),
            errorEvents: filterErrorEventsByPeriod(errorHistory, period: period),
            exportDate: Date(),
            period: period
        )
    }
    
    /// Clear old analytics data
    func clearOldAnalyticsData(olderThan period: AnalyticsPeriod) {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        
        emailEvents.removeAll { $0.timestamp < cutoffDate }
        serviceHealthHistory.removeAll { $0.timestamp < cutoffDate }
        performanceHistory.removeAll { $0.timestamp < cutoffDate }
        errorHistory.removeAll { $0.timestamp < cutoffDate }
        
        // Trim arrays to max size
        trimArraysToMaxSize()
        
        logger.info("Cleared old analytics data", metadata: [
            "cutoffDate": cutoffDate.timeIntervalSince1970,
            "period": period.rawValue
        ])
    }
    
    /// Reset all analytics (for testing)
    func resetAnalytics() {
        emailEvents.removeAll()
        serviceHealthHistory.removeAll()
        performanceHistory.removeAll()
        errorHistory.removeAll()
        
        emailStatistics = EmailStatistics()
        serviceHealthMetrics = ServiceHealthMetrics()
        performanceMetrics = PerformanceMetrics()
        errorAnalytics = ErrorAnalytics()
        
        realTimeEmailCount = 0
        realTimeFailureRate = 0.0
        realTimeResponseTime = 0.0
        
        logger.info("Analytics reset")
    }
    
    // MARK: - Private Methods
    
    private func recordEvent(_ event: EmailAnalyticsEvent) {
        emailEvents.append(event)
        
        // Trim to max size
        if emailEvents.count > maxStoredEvents {
            emailEvents.removeFirst(emailEvents.count - maxStoredEvents)
        }
    }
    
    private func recordHealthEvent(_ event: HealthCheckEvent) {
        serviceHealthHistory.append(event)
        
        if serviceHealthHistory.count > maxStoredEvents {
            serviceHealthHistory.removeFirst(serviceHealthHistory.count - maxStoredEvents)
        }
    }
    
    private func recordPerformanceEvent(_ event: PerformanceEvent) {
        performanceHistory.append(event)
        
        if performanceHistory.count > maxStoredEvents {
            performanceHistory.removeFirst(performanceHistory.count - maxStoredEvents)
        }
    }
    
    private func recordServiceSwitchEvent(_ event: ServiceSwitchEvent) {
        // Service switch events are tracked separately
        logger.info("Service switch event", metadata: [
            "event": event.eventData
        ])
    }
    
    private func updateRealTimeStatistics() {
        let recentEvents = emailEvents.suffix(50) // Last 50 events
        
        realTimeEmailCount = recentEvents.filter { $0.type == .emailSent }.count
        realTimeFailureRate = recentEvents.isEmpty ? 0.0 : 
            Double(recentEvents.filter { $0.type == .emailFailed }.count) / Double(recentEvents.count)
        
        let responseTimes = recentEvents.compactMap { event in
            event.emailResult?.metadata?.serviceResponseTime
        }
        realTimeResponseTime = responseTimes.isEmpty ? 0.0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    private func updateErrorAnalytics(_ error: EmailError) {
        errorAnalytics.incrementError(error)
        
        // Add to error history
        let errorEvent = ErrorEvent(
            id: UUID(),
            timestamp: Date(),
            error: error,
            severity: error.severity,
            context: ["template": "unknown"] // Could be enhanced with more context
        )
        
        errorHistory.append(errorEvent)
        
        if errorHistory.count > maxStoredEvents {
            errorHistory.removeFirst(errorHistory.count - maxStoredEvents)
        }
    }
    
    private func updateServiceHealthMetrics(_ event: HealthCheckEvent) {
        serviceHealthMetrics.updateWithEvent(event)
    }
    
    private func updatePerformanceMetrics(_ event: PerformanceEvent) {
        performanceMetrics.updateWithEvent(event)
    }
    
    private func startPeriodicTasks() {
        // Analytics flush timer
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: analyticsFlushInterval, repeats: true) { [weak self] _ in
            self?.flushAnalytics()
        }
        
        logger.debug("Periodic analytics tasks started")
    }
    
    private func stopPeriodicTasks() {
        analyticsTimer?.invalidate()
        analyticsTimer = nil
        
        logger.debug("Periodic analytics tasks stopped")
    }
    
    private func flushAnalytics() {
        // Export analytics for external processing
        let export = exportAnalyticsData()
        
        // Clear old data
        clearOldAnalyticsData(olderThan: .lastWeek)
        
        logger.info("Analytics flushed", metadata: [
            "totalEvents": emailEvents.count,
            "healthChecks": serviceHealthHistory.count,
            "performanceEvents": performanceHistory.count,
            "errorEvents": errorHistory.count
        ])
    }
    
    private func trimArraysToMaxSize() {
        let arrays = [emailEvents, serviceHealthHistory, performanceHistory, errorHistory]
        
        for array in arrays where array.count > maxStoredEvents {
            array.removeFirst(array.count - maxStoredEvents)
        }
    }
    
    // MARK: - Calculation Methods
    
    private func calculateSuccessRate(_ events: [EmailAnalyticsEvent]) -> Double {
        guard !events.isEmpty else { return 0.0 }
        let successful = events.filter { $0.type == .emailSent }.count
        return Double(successful) / Double(events.count)
    }
    
    private func calculateAverageResponseTime(_ events: [EmailAnalyticsEvent]) -> TimeInterval {
        let responseTimes = events.compactMap { event in
            event.emailResult?.metadata?.serviceResponseTime
        }
        
        guard !responseTimes.isEmpty else { return 0.0 }
        return responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    private func calculateServiceBreakdown(_ events: [EmailAnalyticsEvent]) -> [EmailServiceType: Int] {
        var breakdown: [EmailServiceType: Int] = [:]
        
        for event in events {
            if let result = event.emailResult {
                breakdown[result.service, default: 0] += 1
            }
        }
        
        return breakdown
    }
    
    private func calculateTemplateBreakdown(_ events: [EmailAnalyticsEvent]) -> [EmailTemplate: Int] {
        var breakdown: [EmailTemplate: Int] = [:]
        
        for event in events {
            breakdown[event.template, default: 0] += 1
        }
        
        return breakdown
    }
    
    private func filterEventsByPeriod(_ events: [EmailAnalyticsEvent], period: AnalyticsPeriod) -> [EmailAnalyticsEvent] {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        return events.filter { $0.timestamp >= cutoffDate }
    }
    
    private func filterHealthEventsByPeriod(_ events: [HealthCheckEvent], period: AnalyticsPeriod) -> [HealthCheckEvent] {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        return events.filter { $0.timestamp >= cutoffDate }
    }
    
    private func filterPerformanceEventsByPeriod(_ events: [PerformanceEvent], period: AnalyticsPeriod) -> [PerformanceEvent] {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        return events.filter { $0.timestamp >= cutoffDate }
    }
    
    private func filterErrorEventsByPeriod(_ events: [ErrorEvent], period: AnalyticsPeriod) -> [ErrorEvent] {
        let cutoffDate = Date().addingTimeInterval(-period.timeInterval)
        return events.filter { $0.timestamp >= cutoffDate }
    }
    
    // Placeholder calculation methods - would be implemented based on specific analytics requirements
    private func calculateHealthPercentage(_ events: [HealthCheckEvent]) -> Double { 95.0 }
    private func calculateAverageHealthResponseTime(_ events: [HealthCheckEvent]) -> TimeInterval { 1.5 }
    private func calculateUptime(_ events: [HealthCheckEvent]) -> TimeInterval { 3600 * 24 }
    private func calculateOverallHealthPercentage(_ events: [HealthCheckEvent]) -> Double { 95.0 }
    private func calculateAveragePerformanceTime(_ events: [PerformanceEvent]) -> TimeInterval { 2.0 }
    private func calculateOperationsBreakdown(_ events: [PerformanceEvent]) -> [EmailOperation: Double] { [:] }
    private func getSlowestOperations(_ events: [PerformanceEvent], limit: Int) -> [PerformanceEvent] { [] }
    private func calculatePerformanceTrends(_ events: [PerformanceEvent]) -> [Date: Double] { [:] }
    private func calculateErrorBreakdown(_ events: [ErrorEvent]) -> [EmailError: Int] { [:] }
    private func calculateErrorTrends(_ events: [ErrorEvent]) -> [Date: Int] { [:] }
    private func getMostCommonErrors(_ events: [ErrorEvent], limit: Int) -> [(EmailError, Int)] { [] }
    private func calculateAverageRecoveryTime(_ events: [ErrorEvent]) -> TimeInterval { 300.0 }
}

// MARK: - Supporting Types

enum AnalyticsPeriod: String, CaseIterable {
    case lastHour = "last_hour"
    case last24Hours = "last_24_hours"
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    case allTime = "all_time"
    
    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last24Hours: return 3600 * 24
        case .lastWeek: return 3600 * 24 * 7
        case .lastMonth: return 3600 * 24 * 30
        case .allTime: return TimeInterval.greatestFiniteMagnitude
        }
    }
}

enum AnalyticsEventType: String, Codable, CaseIterable {
    case emailSent = "email_sent"
    case emailFailed = "email_failed"
    case serviceSwitch = "service_switch"
    case healthCheck = "health_check"
    case performance = "performance"
}

enum EmailOperation: String, Codable, CaseIterable {
    case sendPasswordReset = "send_password_reset"
    case sendWelcomeEmail = "send_welcome_email"
    case sendAccountVerification = "send_account_verification"
    case sendGeneralEmail = "send_general_email"
    case loadTemplate = "load_template"
    case renderTemplate = "render_template"
}

enum ServiceSwitchReason: String, Codable, CaseIterable {
    case primaryFailure = "primary_failure"
    case manualSwitch = "manual_switch"
    case healthCheck = "health_check"
    case unknown = "unknown"
}

// MARK: - Event Types

struct EmailAnalyticsEvent: Codable {
    let id: UUID
    let type: AnalyticsEventType
    let timestamp: Date
    let emailResult: EmailResult?
    let emailError: EmailError?
    let template: EmailTemplate
    let metadata: EmailAnalyticsMetadata
}

struct HealthCheckEvent: Codable {
    let id: UUID
    let timestamp: Date
    let serviceType: EmailServiceType
    let isHealthy: Bool
    let responseTime: TimeInterval?
    let errors: String?
    let metadata: HealthCheckMetadata
}

struct PerformanceEvent: Codable {
    let id: UUID
    let timestamp: Date
    let operation: EmailOperation
    let duration: TimeInterval
    let success: Bool
    let metadata: PerformanceMetadata
}

struct ServiceSwitchEvent: Codable {
    let id: UUID
    let timestamp: Date
    let fromService: EmailServiceType
    let toService: EmailServiceType
    let reason: ServiceSwitchReason
    let metadata: ServiceSwitchMetadata
    
    var eventData: [String: Any] {
        return [
            "eventType": "service_switch",
            "from": fromService.rawValue,
            "to": toService.rawValue,
            "reason": reason.rawValue,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

struct ErrorEvent: Codable {
    let id: UUID
    let timestamp: Date
    let error: EmailError
    let severity: EmailErrorSeverity
    let context: [String: String]
}

// MARK: - Metadata Types

struct EmailAnalyticsMetadata: Codable {
    let userId: UUID?
    let sessionId: String?
    let deviceType: String?
    let appVersion: String?
    
    init(userId: UUID? = nil, sessionId: String? = nil, deviceType: String? = nil, appVersion: String? = nil) {
        self.userId = userId
        self.sessionId = sessionId
        self.deviceType = deviceType
        self.appVersion = appVersion
    }
}

struct HealthCheckMetadata: Codable {
    let checkType: String?
    let triggeredAutomatically: Bool
    let previousStatus: ServiceHealthStatus?
    
    init(checkType: String? = nil, triggeredAutomatically: Bool = true, previousStatus: ServiceHealthStatus? = nil) {
        self.checkType = checkType
        self.triggeredAutomatically = triggeredAutomatically
        self.previousStatus = previousStatus
    }
}

struct PerformanceMetadata: Codable {
    let requestSize: Int?
    let cacheHit: Bool?
    let retryCount: Int?
    
    init(requestSize: Int? = nil, cacheHit: Bool? = nil, retryCount: Int? = nil) {
        self.requestSize = requestSize
        self.cacheHit = cacheHit
        self.retryCount = retryCount
    }
}

struct ServiceSwitchMetadata: Codable {
    let reason: String?
    let userTriggered: Bool
    let fallbackActivated: Bool
    
    init(reason: String? = nil, userTriggered: Bool = false, fallbackActivated: Bool = false) {
        self.reason = reason
        self.userTriggered = userTriggered
        self.fallbackActivated = fallbackActivated
    }
}

// MARK: - Analytics Data Types

struct EmailStatistics: Codable {
    var totalSent: Int = 0
    var totalFailed: Int = 0
    var successRate: Double = 0.0
    var averageResponseTime: TimeInterval = 0.0
    var serviceBreakdown: [EmailServiceType: Int] = [:]
    var templateBreakdown: [EmailTemplate: Int] = [:]
    var period: AnalyticsPeriod = .allTime
    var lastUpdated = Date()
}

struct ServiceHealthMetrics: Codable {
    var overallHealthPercentage = 100.0
    var serviceHealth: [EmailServiceType: ServiceHealthSummary] = [:]
    var averageResponseTime = 0.0
    var lastHealthCheck = Date()
    
    mutating func updateWithEvent(_ event: HealthCheckEvent) {
        lastHealthCheck = event.timestamp
        
        // Update service-specific metrics
        if var summary = serviceHealth[event.serviceType] {
            summary.lastCheckTime = event.timestamp
        } else {
            serviceHealth[event.serviceType] = ServiceHealthSummary(
                serviceType: event.serviceType,
                healthPercentage: event.isHealthy ? 100.0 : 0.0,
                averageResponseTime: event.responseTime ?? 0.0,
                totalChecks: 1,
                lastCheckTime: event.timestamp,
                uptime: event.isHealthy ? Date().timeIntervalSince1970 : 0.0
            )
        }
    }
}

struct ServiceHealthSummary: Codable {
    var serviceType: EmailServiceType
    var healthPercentage: Double
    var averageResponseTime: TimeInterval
    var totalChecks: Int
    var lastCheckTime: Date?
    var uptime: TimeInterval
}

struct PerformanceMetrics: Codable {
    var averageResponseTime: TimeInterval = 0.0
    var operationsBreakdown: [EmailOperation: Double] = [:]
    var slowestOperations: [EmailOperation] = []
    var lastUpdated = Date()
    
    mutating func updateWithEvent(_ event: PerformanceEvent) {
        lastUpdated = Date()
        
        // Update operation-specific metrics
        let currentAverage = operationsBreakdown[event.operation] ?? 0.0
        operationsBreakdown[event.operation] = (currentAverage + event.duration) / 2.0
        
        // Update slowest operations (simplified)
        if event.duration > 5.0 && !slowestOperations.contains(event.operation) {
            slowestOperations.append(event.operation)
        }
    }
}

struct ErrorAnalytics: Codable {
    var totalErrors: Int = 0
    var errorBreakdown: [EmailError: Int] = [:]
    var errorTrends: [Date: Int] = [: ]
    var lastUpdated = Date()
    
    mutating func incrementError(_ error: EmailError) {
        totalErrors += 1
        errorBreakdown[error, default: 0] += 1
        lastUpdated = Date()
    }
}

// MARK: - Detailed Analytics Types (for API responses)

struct ServiceHealthAnalytics: Codable {
    let overallHealthPercentage: Double
    let serviceHealth: [EmailServiceType: ServiceHealthSummary]
    let period: AnalyticsPeriod
    let lastUpdated: Date
}

struct PerformanceAnalytics: Codable {
    let averageResponseTime: TimeInterval
    let operationsBreakdown: [EmailOperation: Double]
    let slowestOperations: [PerformanceEvent]
    let performanceTrends: [Date: Double]
    let period: AnalyticsPeriod
    let lastUpdated: Date
}

struct ErrorAnalyticsDetail: Codable {
    let totalErrors: Int
    let errorBreakdown: [EmailError: Int]
    let errorTrends: [Date: Int]
    let mostCommonErrors: [(EmailError, Int)]
    let recoveryTime: TimeInterval
    let period: AnalyticsPeriod
    let lastUpdated: Date
}

struct AnalyticsExport: Codable {
    let emailEvents: [EmailAnalyticsEvent]
    let healthEvents: [HealthCheckEvent]
    let performanceEvents: [PerformanceEvent]
    let errorEvents: [ErrorEvent]
    let exportDate: Date
    let period: AnalyticsPeriod
}

