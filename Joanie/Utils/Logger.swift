import Foundation
import os.log

// MARK: - Logger

class Logger {
    // MARK: - Singleton
    static let shared = Logger()
    
    // MARK: - Properties
    private let osLog: OSLog
    private let dateFormatter: DateFormatter
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    
    // MARK: - Initialization
    
    private init() {
        self.osLog = OSLog(subsystem: "com.joanie.app", category: "general")
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.timeZone = TimeZone.current
    }
    
    // MARK: - Public Methods
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = Date()
        
        // Create log entry
        let entry = LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            file: fileName,
            function: function,
            line: line
        )
        
        // Add to in-memory log
        addLogEntry(entry)
        
        // Log to system
        logToSystem(entry)
        
        // Log to console in debug mode
        if Config.isDebugMode {
            logToConsole(entry)
        }
    }
    
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // Keep only the most recent entries
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }
    
    private func logToSystem(_ entry: LogEntry) {
        let osLogType: OSLogType
        switch entry.level {
        case .info:
            osLogType = .info
        case .debug:
            osLogType = .debug
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        case .critical:
            osLogType = .fault
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, entry.formattedMessage)
    }
    
    private func logToConsole(_ entry: LogEntry) {
        print(entry.formattedMessage)
    }
    
    // MARK: - Log Management
    
    func getLogEntries(level: LogLevel? = nil, limit: Int? = nil) -> [LogEntry] {
        var entries = logEntries
        
        if let level = level {
            entries = entries.filter { $0.level == level }
        }
        
        if let limit = limit {
            entries = Array(entries.suffix(limit))
        }
        
        return entries
    }
    
    func clearLogs() {
        logEntries.removeAll()
    }
    
    func exportLogs() -> String {
        return logEntries.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    func getLogStats() -> LogStats {
        let totalEntries = logEntries.count
        let infoCount = logEntries.filter { $0.level == .info }.count
        let debugCount = logEntries.filter { $0.level == .debug }.count
        let warningCount = logEntries.filter { $0.level == .warning }.count
        let errorCount = logEntries.filter { $0.level == .error }.count
        let criticalCount = logEntries.filter { $0.level == .critical }.count
        
        return LogStats(
            totalEntries: totalEntries,
            infoCount: infoCount,
            debugCount: debugCount,
            warningCount: warningCount,
            errorCount: errorCount,
            criticalCount: criticalCount
        )
    }
}

// MARK: - Log Level

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case debug = "DEBUG"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var emoji: String {
        switch self {
        case .info:
            return "ℹ️"
        case .debug:
            return "🔍"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .critical:
            return "🚨"
        }
    }
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .debug:
            return "gray"
        case .warning:
            return "orange"
        case .error:
            return "red"
        case .critical:
            return "purple"
        }
    }
}

// MARK: - Log Entry

struct LogEntry {
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int
    
    var formattedMessage: String {
        let timestampString = DateFormatter.logFormatter.string(from: timestamp)
        return "[\(timestampString)] \(level.emoji) \(level.rawValue) [\(file):\(line)] \(function) - \(message)"
    }
    
    var shortMessage: String {
        return "[\(level.rawValue)] \(message)"
    }
}

// MARK: - Log Stats

struct LogStats {
    let totalEntries: Int
    let infoCount: Int
    let debugCount: Int
    let warningCount: Int
    let errorCount: Int
    let criticalCount: Int
    
    var errorRate: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(errorCount + criticalCount) / Double(totalEntries)
    }
    
    var warningRate: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(warningCount) / Double(totalEntries)
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Global Logger Functions

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, file: file, function: function, line: line)
}

func logCritical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, file: file, function: function, line: line)
}

// MARK: - Debug Tools

class DebugTools: ObservableObject {
    @Published var isDebugMode: Bool = false
    @Published var showLogs: Bool = false
    @Published var logEntries: [LogEntry] = []
    
    // MARK: - Singleton
    static let shared = DebugTools()
    
    private init() {
        self.isDebugMode = Config.isDebugMode
    }
    
    // MARK: - Public Methods
    
    func toggleDebugMode() {
        isDebugMode.toggle()
        // Config.isDebugMode = isDebugMode // TODO: Make Config.isDebugMode mutable
    }
    
    func refreshLogs() {
        logEntries = Logger.shared.getLogEntries(limit: 100)
    }
    
    func clearLogs() {
        Logger.shared.clearLogs()
        logEntries.removeAll()
    }
    
    func exportLogs() -> String {
        return Logger.shared.exportLogs()
    }
    
    func getLogStats() -> LogStats {
        return Logger.shared.getLogStats()
    }
    
    // MARK: - Performance Monitoring
    
    func measureTime<T>(_ operation: () throws -> T, label: String) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        logInfo("\(label) took \(String(format: "%.3f", timeElapsed)) seconds")
        return result
    }
    
    func measureTimeAsync<T>(_ operation: () async throws -> T, label: String) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        logInfo("\(label) took \(String(format: "%.3f", timeElapsed)) seconds")
        return result
    }
    
    // MARK: - Memory Monitoring
    
    func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return MemoryUsage(
                residentSize: info.resident_size,
                virtualSize: info.virtual_size
            )
        } else {
            return MemoryUsage(residentSize: 0, virtualSize: 0)
        }
    }
    
    // MARK: - Network Monitoring
    
    func logNetworkRequest(_ request: URLRequest) {
        logInfo("🌐 Network Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
        
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                logError("Header: \(key): \(value)")
            }
        }
        
        if let body = request.httpBody {
            logError("Body size: \(body.count) bytes")
        }
    }
    
    func logNetworkResponse(_ response: URLResponse, data: Data?) {
        if let httpResponse = response as? HTTPURLResponse {
            logInfo("🌐 Network Response: \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "unknown")")
            
            for (key, value) in httpResponse.allHeaderFields {
                logError("Response Header: \(key): \(value)")
            }
        }
        
        if let data = data {
            logError("Response data size: \(data.count) bytes")
        }
    }
}

// MARK: - Memory Usage

struct MemoryUsage {
    let residentSize: UInt64
    let virtualSize: UInt64
    
    var residentSizeMB: Double {
        return Double(residentSize) / 1024.0 / 1024.0
    }
    
    var virtualSizeMB: Double {
        return Double(virtualSize) / 1024.0 / 1024.0
    }
    
    var formattedResidentSize: String {
        return String(format: "%.2f MB", residentSizeMB)
    }
    
    var formattedVirtualSize: String {
        return String(format: "%.2f MB", virtualSizeMB)
    }
}

// MARK: - Performance Timer

class PerformanceTimer {
    private let startTime: CFAbsoluteTime
    private let label: String
    
    init(label: String) {
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.label = label
        logError("⏱️ Starting timer: \(label)")
    }
    
    deinit {
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logError("⏱️ Timer \(label) completed in \(String(format: "%.3f", timeElapsed)) seconds")
    }
    
    func elapsed() -> CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func logElapsed() {
        let timeElapsed = elapsed()
        logInfo("⏱️ \(label): \(String(format: "%.3f", timeElapsed)) seconds")
    }
}

// MARK: - Debug View

#if DEBUG
import SwiftUI

struct DebugView: View {
    @StateObject private var debugTools = DebugTools.shared
    @State private var showingLogs = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Debug Controls") {
                    Toggle("Debug Mode", isOn: $debugTools.isDebugMode)
                    Button("Refresh Logs") {
                        debugTools.refreshLogs()
                    }
                    Button("Clear Logs") {
                        debugTools.clearLogs()
                    }
                }
                
                Section("Log Statistics") {
                    let stats = debugTools.getLogStats()
                    HStack {
                        Text("Total Entries")
                        Spacer()
                        Text("\(stats.totalEntries)")
                    }
                    HStack {
                        Text("Errors")
                        Spacer()
                        Text("\(stats.errorCount)")
                            .foregroundColor(.red)
                    }
                    HStack {
                        Text("Warnings")
                        Spacer()
                        Text("\(stats.warningCount)")
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Memory Usage") {
                    let memory = debugTools.getMemoryUsage()
                    HStack {
                        Text("Resident Memory")
                        Spacer()
                        Text(memory.formattedResidentSize)
                    }
                    HStack {
                        Text("Virtual Memory")
                        Spacer()
                        Text(memory.formattedVirtualSize)
                    }
                }
                
                Section("Actions") {
                    Button("Show Logs") {
                        showingLogs = true
                    }
                    Button("Export Logs") {
                        let logs = debugTools.exportLogs()
                        // In a real app, you would share this
                        print(logs)
                    }
                }
            }
            .navigationTitle("Debug Tools")
            .sheet(isPresented: $showingLogs) {
                LogsView()
            }
        }
    }
}

struct LogsView: View {
    @StateObject private var debugTools = DebugTools.shared
    
    var body: some View {
        NavigationView {
            List(debugTools.logEntries, id: \.timestamp) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.level.emoji)
                        Text(entry.level.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.message)
                        .font(.body)
                    
                    Text("\(entry.file):\(entry.line)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}
#endif
