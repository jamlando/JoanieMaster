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
        
        logError("Error handled: \(appError.localizedDescription)")
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        isShowingError = true
        
        logError("App error handled: \(appError.localizedDescription)")
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

// MARK: - Enhanced Error View

struct EnhancedErrorView: View {
    let error: AuthenticationError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    let onRecoveryAction: (() -> Void)?
    
    @State private var isRetrying = false
    
    init(error: AuthenticationError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void, onRecoveryAction: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
        self.onRecoveryAction = onRecoveryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            Image(systemName: error.severity.icon)
                .font(.system(size: 60))
                .foregroundColor(error.severity.color)
            
            // Error Title
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Error Description
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Recovery Suggestion
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                // Retry Button
                if error.canRetry, let onRetry = onRetry {
                    Button(action: {
                        isRetrying = true
                        onRetry()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isRetrying = false
                        }
                    }) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRetrying ? "Retrying..." : "Try Again")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRetrying)
                }
                
                // Recovery Action Button
                if let onRecoveryAction = onRecoveryAction {
                    Button(action: onRecoveryAction) {
                        HStack {
                            Image(systemName: recoveryActionIcon)
                            Text(recoveryActionTitle)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Dismiss Button
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 12)
        .padding(.horizontal, 20)
    }
    
    private var errorTitle: String {
        switch error.severity {
        case .warning:
            return "Something went wrong"
        case .error:
            return "Error occurred"
        case .critical:
            return "Critical error"
        case .info:
            return "Information"
        }
    }
    
    private var recoveryActionIcon: String {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            return "wifi"
        case .invalidCredentials, .userNotFound:
            return "person.badge.key"
        case .emailAlreadyExists:
            return "envelope"
        case .weakPassword, .passwordTooCommon:
            return "key"
        case .accountLocked, .accountDisabled:
            return "lock"
        case .emailNotVerified:
            return "envelope.badge"
        case .sessionExpired, .sessionInvalid, .refreshTokenExpired:
            return "arrow.clockwise.circle"
        case .serverError, .serviceUnavailable, .serverOverloaded:
            return "server.rack"
        case .rateLimitExceeded:
            return "clock"
        case .keychainError, .storageError:
            return "externaldrive"
        case .biometricError:
            return "faceid"
        case .permissionDenied:
            return "hand.raised"
        case .appleSignInCancelled, .appleSignInFailed:
            return "applelogo"
        case .passwordResetFailed, .passwordResetExpired:
            return "key.horizontal"
        default:
            return "questionmark.circle"
        }
    }
    
    private var recoveryActionTitle: String {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            return "Check Connection"
        case .invalidCredentials, .userNotFound:
            return "Reset Password"
        case .emailAlreadyExists:
            return "Sign In Instead"
        case .weakPassword, .passwordTooCommon:
            return "Use Stronger Password"
        case .accountLocked, .accountDisabled:
            return "Contact Support"
        case .emailNotVerified:
            return "Resend Verification"
        case .sessionExpired, .sessionInvalid, .refreshTokenExpired:
            return "Sign In Again"
        case .serverError, .serviceUnavailable, .serverOverloaded:
            return "Try Later"
        case .rateLimitExceeded:
            return "Wait and Retry"
        case .keychainError, .storageError:
            return "Restart App"
        case .biometricError:
            return "Use Password"
        case .permissionDenied:
            return "Enable Permissions"
        case .appleSignInCancelled, .appleSignInFailed:
            return "Use Email Sign In"
        case .passwordResetFailed, .passwordResetExpired:
            return "Request New Reset"
        default:
            return "Get Help"
        }
    }
}

// MARK: - Authentication Error Alert

struct AuthenticationErrorAlert: ViewModifier {
    @Binding var error: AuthenticationError?
    let onRetry: (() -> Void)?
    let onRecoveryAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Authentication Error", isPresented: .constant(error != nil)) {
                if let error = error {
                    if error.canRetry, let onRetry = onRetry {
                        Button("Try Again") {
                            onRetry()
                            self.error = nil
                        }
                    }
                    
                    if onRecoveryAction != nil {
                        Button(recoveryActionTitle(for: error)) {
                            onRecoveryAction?()
                            self.error = nil
                        }
                    }
                    
                    Button("OK") {
                        self.error = nil
                    }
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
    
    private func recoveryActionTitle(for error: AuthenticationError) -> String {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed:
            return "Check Connection"
        case .invalidCredentials, .userNotFound:
            return "Reset Password"
        case .emailAlreadyExists:
            return "Sign In Instead"
        case .sessionExpired, .sessionInvalid:
            return "Sign In Again"
        case .serverError, .serviceUnavailable:
            return "Try Later"
        case .rateLimitExceeded:
            return "Wait and Retry"
        default:
            return "Get Help"
        }
    }
}

extension View {
    func authenticationErrorAlert(
        _ error: Binding<AuthenticationError?>,
        onRetry: (() -> Void)? = nil,
        onRecoveryAction: (() -> Void)? = nil
    ) -> some View {
        self.modifier(AuthenticationErrorAlert(
            error: error,
            onRetry: onRetry,
            onRecoveryAction: onRecoveryAction
        ))
    }
}

// MARK: - Error Toast

struct ErrorToast: View {
    let error: AuthenticationError
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .foregroundColor(error.severity.color)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.localizedDescription)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onDismiss()
        }
    }
}

// MARK: - Error Toast Container

struct ErrorToastContainer: ViewModifier {
    @Binding var error: AuthenticationError?
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let error = error {
                VStack {
                    ErrorToast(error: error, onDismiss: onDismiss)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func errorToast(_ error: Binding<AuthenticationError?>, onDismiss: @escaping () -> Void) -> some View {
        self.modifier(ErrorToastContainer(error: error, onDismiss: onDismiss))
    }
}

// MARK: - Error Recovery Actions

class ErrorRecoveryActions {
    static let shared = ErrorRecoveryActions()
    
    private init() {}
    
    func handleRecoveryAction(for error: AuthenticationError, in viewModel: AuthenticationViewModel) {
        switch error {
        case .networkUnavailable, .networkTimeout, .networkConnectionFailed, .networkSlowConnection:
            // Network errors - could open settings or show network status
            break
            
        case .invalidCredentials, .userNotFound:
            // Show password reset flow
            break
            
        case .emailAlreadyExists:
            // Navigate to sign in
            break
            
        case .sessionExpired, .sessionInvalid, .refreshTokenExpired:
            // Force re-authentication
            Task {
                await viewModel.signOut()
            }
            
        case .serverError, .serviceUnavailable, .serverOverloaded:
            // Show server status or retry later
            break
            
        case .rateLimitExceeded:
            // Show countdown timer
            break
            
        case .keychainError, .storageError:
            // Suggest app restart
            break
            
        case .biometricError:
            // Fallback to password
            break
            
        case .permissionDenied:
            // Open app settings
            break
            
        case .appleSignInCancelled, .appleSignInFailed:
            // Fallback to email/password
            break
            
        case .passwordResetFailed, .passwordResetExpired:
            // Show password reset form
            break
            
        default:
            break
        }
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

struct ErrorLoadingView: View {
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
                ErrorLoadingView(message: message, progress: progress)
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
        @ViewBuilder loading: @escaping () -> Loading = { ErrorLoadingView() },
        @ViewBuilder error: @escaping (AppError) -> Error = { _ in EmptyView() }
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
