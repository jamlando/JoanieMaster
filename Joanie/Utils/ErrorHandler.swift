import Foundation
import SwiftUI

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var isShowingError: Bool = false
    
    // MARK: - Singleton
    static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func handle(_ error: Error) {
        let appError = AppError.from(error)
        currentError = appError
        isShowingError = true
        
        Logger.error("Error handled: \(appError.localizedDescription)")
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        isShowingError = true
        
        Logger.error("App error handled: \(appError.localizedDescription)")
    }
    
    func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    func dismissError() {
        clearError()
    }
}

// MARK: - App Error Extensions

extension AppError {
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common errors to AppError
        if let urlError = error as? URLError {
            return .networkError(urlError.localizedDescription)
        }
        
        if let decodingError = error as? DecodingError {
            return .validationError("Data format error: \(decodingError.localizedDescription)")
        }
        
        if let encodingError = error as? EncodingError {
            return .validationError("Data encoding error: \(encodingError.localizedDescription)")
        }
        
        return .unknown(error.localizedDescription)
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .networkError:
            return .warning
        case .authenticationError:
            return .error
        case .validationError:
            return .warning
        case .storageError:
            return .error
        case .aiServiceError:
            return .warning
        case .unknown:
            return .error
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .networkError:
            return true
        case .aiServiceError:
            return true
        case .storageError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    init(error: AppError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: error.severity.icon)
                .font(.system(size: 48))
                .foregroundColor(error.severity.color)
            
            Text("Oops! Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                if error.canRetry, let onRetry = onRetry {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

// MARK: - Error Alert

struct ErrorAlert: ViewModifier {
    @Binding var error: AppError?
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil)) {
                if let error = error, error.canRetry, let onRetry = onRetry {
                    Button("Try Again") {
                        onRetry()
                        self.error = nil
                    }
                }
                Button("OK") {
                    self.error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlert(error: error, onRetry: onRetry))
    }
}

// MARK: - Loading State

enum LoadingState {
    case idle
    case loading
    case success
    case failure(Error)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    let progress: Double?
    
    init(message: String = "Loading...", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let progress = progress {
                ProgressView(value: progress)
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String
    let progress: Double?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingView(message: message, progress: progress)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading...", progress: Double? = nil) -> some View {
        self.modifier(LoadingOverlay(isLoading: isLoading, message: message, progress: progress))
    }
}

// MARK: - Async Loading View

struct AsyncLoadingView<Content: View, Loading: View, Error: View>: View {
    let loadingState: LoadingState
    let content: () -> Content
    let loading: () -> Loading
    let error: (AppError) -> Error
    
    init(
        loadingState: LoadingState,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder loading: @escaping () -> Loading = { LoadingView() },
        @ViewBuilder error: @escaping (AppError) -> Error = { ErrorView(error: $0, onDismiss: {}) }
    ) {
        self.loadingState = loadingState
        self.content = content
        self.loading = loading
        self.error = error
    }
    
    var body: some View {
        switch loadingState {
        case .idle, .loading:
            loading()
        case .success:
            content()
        case .failure(let error):
            if let appError = error as? AppError {
                self.error(appError)
            } else {
                self.error(AppError.from(error))
            }
        }
    }
}
