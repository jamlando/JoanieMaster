import Foundation
import Combine
import Network

// MARK: - Offline Error Queue Manager

class OfflineErrorQueueManager: ObservableObject {
    static let shared = OfflineErrorQueueManager()
    
    @Published var isOnline: Bool = true
    @Published var queuedErrors: [QueuedError] = []
    @Published var isProcessingQueue: Bool = false
    
    private let logger = Logger.shared
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "offline.error.queue")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Queued Error
    
    struct QueuedError: Codable, Identifiable {
        let id: UUID
        let error: AuthenticationError
        let context: [String: AnyCodable]
        let timestamp: Date
        let retryCount: Int
        let maxRetries: Int
        let priority: Priority
        
        enum Priority: Int, Codable, CaseIterable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3
            
            var description: String {
                switch self {
                case .low: return "Low"
                case .normal: return "Normal"
                case .high: return "High"
                case .critical: return "Critical"
                }
            }
        }
        
        init(error: AuthenticationError, context: [String: Any] = [:], priority: Priority = .normal, maxRetries: Int = 3) {
            self.id = UUID()
            self.error = error
            self.context = context.mapValues { AnyCodable($0) }
            self.timestamp = Date()
            self.retryCount = 0
            self.maxRetries = maxRetries
            self.priority = priority
        }
        
        var canRetry: Bool {
            return retryCount < maxRetries && error.canRetry
        }
        
        var shouldRetry: Bool {
            return canRetry && shouldRetryBasedOnError()
        }
        
        private func shouldRetryBasedOnError() -> Bool {
            switch error {
            case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
                return true
            case .serverError, .serviceUnavailable, .serverOverloaded:
                return true
            case .rateLimitExceeded:
                return true
            case .storageError, .imageUploadFailed:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - AnyCodable Helper
    
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else {
                throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let string = value as? String {
                try container.encode(string)
            } else if let int = value as? Int {
                try container.encode(int)
            } else if let double = value as? Double {
                try container.encode(double)
            } else if let bool = value as? Bool {
                try container.encode(bool)
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
            }
        }
    }
    
    private init() {
        setupNetworkMonitoring()
        loadQueuedErrors()
        startQueueProcessor()
    }
    
    // MARK: - Public Methods
    
    func queueError(_ error: AuthenticationError, context: [String: Any] = [:], priority: QueuedError.Priority = .normal) {
        let queuedError = QueuedError(error: error, context: context, priority: priority)
        
        queue.async { [weak self] in
            self?.addToQueue(queuedError)
        }
    }
    
    func processQueue() {
        guard isOnline && !isProcessingQueue else { return }
        
        queue.async { [weak self] in
            self?.processQueuedErrors()
        }
    }
    
    func clearQueue() {
        queue.async { [weak self] in
            self?.queuedErrors.removeAll()
            self?.saveQueuedErrors()
        }
    }
    
    func removeError(_ id: UUID) {
        queue.async { [weak self] in
            self?.queuedErrors.removeAll { $0.id == id }
            self?.saveQueuedErrors()
        }
    }
    
    func retryError(_ id: UUID) {
        queue.async { [weak self] in
            guard let index = self?.queuedErrors.firstIndex(where: { $0.id == id }) else { return }
            self?.queuedErrors[index] = QueuedError(
                error: self?.queuedErrors[index].error ?? .unknown(""),
                context: self?.queuedErrors[index].context.mapValues { $0.value } ?? [:],
                priority: self?.queuedErrors[index].priority ?? .normal,
                maxRetries: self?.queuedErrors[index].maxRetries ?? 3
            )
            self?.saveQueuedErrors()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                if !wasOnline && self?.isOnline == true {
                    // Network came back online, process queue
                    self?.processQueue()
                }
            }
        }
        
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - Queue Processing
    
    private func startQueueProcessor() {
        // Process queue every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processQueue()
            }
            .store(in: &cancellables)
    }
    
    private func addToQueue(_ queuedError: QueuedError) {
        queuedErrors.append(queuedError)
        queuedErrors.sort { $0.priority.rawValue > $1.priority.rawValue }
        saveQueuedErrors()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        logger.logInfo("OfflineErrorQueue: Added error to queue - \(queuedError.error.errorCode)")
    }
    
    private func processQueuedErrors() {
        guard isOnline && !isProcessingQueue else { return }
        
        DispatchQueue.main.async {
            self.isProcessingQueue = true
        }
        
        let errorsToProcess = queuedErrors.filter { $0.shouldRetry }
        
        logger.logInfo("OfflineErrorQueue: Processing \(errorsToProcess.count) queued errors")
        
        for queuedError in errorsToProcess {
            processQueuedError(queuedError)
        }
        
        DispatchQueue.main.async {
            self.isProcessingQueue = false
        }
    }
    
    private func processQueuedError(_ queuedError: QueuedError) {
        // Mock processing - in real implementation, this would retry the actual operation
        logger.logInfo("OfflineErrorQueue: Processing error \(queuedError.error.errorCode)")
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Mock success/failure
            let success = Bool.random()
            
            if success {
                self.removeError(queuedError.id)
                self.logger.logInfo("OfflineErrorQueue: Successfully processed error \(queuedError.error.errorCode)")
            } else {
                self.incrementRetryCount(for: queuedError.id)
                self.logger.logError("OfflineErrorQueue: Failed to process error \(queuedError.error.errorCode)")
            }
        }
    }
    
    private func incrementRetryCount(for id: UUID) {
        guard let index = queuedErrors.firstIndex(where: { $0.id == id }) else { return }
        
        let currentError = queuedErrors[index]
        let updatedError = QueuedError(
            error: currentError.error,
            context: currentError.context.mapValues { $0.value },
            priority: currentError.priority,
            maxRetries: currentError.maxRetries
        )
        
        queuedErrors[index] = updatedError
        saveQueuedErrors()
    }
    
    // MARK: - Persistence
    
    private func saveQueuedErrors() {
        do {
            let data = try JSONEncoder().encode(queuedErrors)
            UserDefaults.standard.set(data, forKey: "offline_error_queue")
        } catch {
            logger.logError("OfflineErrorQueue: Failed to save queued errors - \(error)")
        }
    }
    
    private func loadQueuedErrors() {
        guard let data = UserDefaults.standard.data(forKey: "offline_error_queue") else { return }
        
        do {
            queuedErrors = try JSONDecoder().decode([QueuedError].self, from: data)
            logger.logInfo("OfflineErrorQueue: Loaded \(queuedErrors.count) queued errors")
        } catch {
            logger.logError("OfflineErrorQueue: Failed to load queued errors - \(error)")
            queuedErrors = []
        }
    }
    
    // MARK: - Statistics
    
    func getQueueStatistics() -> QueueStatistics {
        let totalErrors = queuedErrors.count
        let errorsByPriority = Dictionary(grouping: queuedErrors, by: { $0.priority })
        let errorsByType = Dictionary(grouping: queuedErrors, by: { $0.error.errorCode })
        let averageRetryCount = queuedErrors.isEmpty ? 0 : queuedErrors.map { $0.retryCount }.reduce(0, +) / queuedErrors.count
        
        return QueueStatistics(
            totalErrors: totalErrors,
            errorsByPriority: errorsByPriority.mapValues { $0.count },
            errorsByType: errorsByType.mapValues { $0.count },
            averageRetryCount: averageRetryCount,
            oldestError: queuedErrors.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
            newestError: queuedErrors.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        )
    }
    
    struct QueueStatistics {
        let totalErrors: Int
        let errorsByPriority: [QueuedError.Priority: Int]
        let errorsByType: [String: Int]
        let averageRetryCount: Int
        let oldestError: Date?
        let newestError: Date?
    }
}

// MARK: - Offline Error Handler

class OfflineErrorHandler {
    static let shared = OfflineErrorHandler()
    
    private let queueManager = OfflineErrorQueueManager.shared
    private let logger = Logger.shared
    
    private init() {}
    
    func handleOfflineError(_ error: AuthenticationError, context: [String: Any] = [:]) {
        // Determine if error should be queued for offline handling
        guard shouldQueueError(error) else {
            logger.logInfo("OfflineErrorHandler: Error \(error.errorCode) not suitable for offline queuing")
            return
        }
        
        // Determine priority based on error type
        let priority = determinePriority(for: error)
        
        // Queue the error
        queueManager.queueError(error, context: context, priority: priority)
        
        logger.logInfo("OfflineErrorHandler: Queued error \(error.errorCode) with priority \(priority)")
    }
    
    private func shouldQueueError(_ error: AuthenticationError) -> Bool {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            return true
        case .serverError, .serviceUnavailable, .serverOverloaded:
            return true
        case .rateLimitExceeded:
            return true
        case .storageError, .imageUploadFailed:
            return true
        case .accountUpdateFailed, .profileUpdateFailed:
            return true
        default:
            return false
        }
    }
    
    private func determinePriority(for error: AuthenticationError) -> OfflineErrorQueueManager.QueuedError.Priority {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed:
            return .high
        case .serverError, .serviceUnavailable, .serverOverloaded:
            return .normal
        case .rateLimitExceeded:
            return .low
        case .storageError, .imageUploadFailed:
            return .normal
        case .accountUpdateFailed, .profileUpdateFailed:
            return .high
        default:
            return .normal
        }
    }
}

// MARK: - Offline Error UI

struct OfflineErrorQueueView: View {
    @ObservedObject var queueManager = OfflineErrorQueueManager.shared
    @State private var showingStatistics = false
    
    var body: some View {
        NavigationView {
            List {
                // Queue Status
                Section("Queue Status") {
                    HStack {
                        Image(systemName: queueManager.isOnline ? "wifi" : "wifi.slash")
                            .foregroundColor(queueManager.isOnline ? .green : .red)
                        Text(queueManager.isOnline ? "Online" : "Offline")
                        Spacer()
                        if queueManager.isProcessingQueue {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    HStack {
                        Text("Queued Errors")
                        Spacer()
                        Text("\(queueManager.queuedErrors.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Queued Errors
                Section("Queued Errors") {
                    if queueManager.queuedErrors.isEmpty {
                        Text("No errors in queue")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(queueManager.queuedErrors) { queuedError in
                            QueuedErrorRow(queuedError: queuedError)
                        }
                    }
                }
                
                // Actions
                Section("Actions") {
                    Button("Process Queue") {
                        queueManager.processQueue()
                    }
                    .disabled(!queueManager.isOnline || queueManager.isProcessingQueue)
                    
                    Button("Clear Queue") {
                        queueManager.clearQueue()
                    }
                    .foregroundColor(.red)
                    
                    Button("Show Statistics") {
                        showingStatistics = true
                    }
                }
            }
            .navigationTitle("Error Queue")
            .sheet(isPresented: $showingStatistics) {
                QueueStatisticsView(statistics: queueManager.getQueueStatistics())
            }
        }
    }
}

struct QueuedErrorRow: View {
    let queuedError: OfflineErrorQueueManager.QueuedError
    @ObservedObject var queueManager = OfflineErrorQueueManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(queuedError.error.errorCode)
                    .font(.headline)
                Spacer()
                Text(queuedError.priority.description)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor)
                    .cornerRadius(8)
            }
            
            Text(queuedError.error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Retry: \(queuedError.retryCount)/\(queuedError.maxRetries)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(queuedError.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if queuedError.canRetry {
                Button("Retry Now") {
                    queueManager.retryError(queuedError.id)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var priorityColor: Color {
        switch queuedError.priority {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct QueueStatisticsView: View {
    let statistics: OfflineErrorQueueManager.QueueStatistics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Overview") {
                    HStack {
                        Text("Total Errors")
                        Spacer()
                        Text("\(statistics.totalErrors)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Average Retry Count")
                        Spacer()
                        Text("\(statistics.averageRetryCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("By Priority") {
                    ForEach(OfflineErrorQueueManager.QueuedError.Priority.allCases, id: \.self) { priority in
                        HStack {
                            Text(priority.description)
                            Spacer()
                            Text("\(statistics.errorsByPriority[priority] ?? 0)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("By Type") {
                    ForEach(Array(statistics.errorsByType.keys.sorted()), id: \.self) { type in
                        HStack {
                            Text(type)
                            Spacer()
                            Text("\(statistics.errorsByType[type] ?? 0)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let oldest = statistics.oldestError, let newest = statistics.newestError {
                    Section("Time Range") {
                        HStack {
                            Text("Oldest Error")
                            Spacer()
                            Text(oldest, style: .relative)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Newest Error")
                            Spacer()
                            Text(newest, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Queue Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

