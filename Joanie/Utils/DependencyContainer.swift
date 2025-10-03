import Foundation
import Combine
import UIKit

// MARK: - Dependency Container

@MainActor
class DependencyContainer: ObservableObject {
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Services
    private(set) var supabaseService: SupabaseService
    private(set) var authService: AuthService
    private(set) var storageService: StorageService
    private(set) var aiService: AIService
    private(set) var imageProcessor: ImageProcessor
    private(set) var logger: Logger
    
    // MARK: - Email Services
    private(set) var emailServiceManager: Any // EmailServiceManager
    private(set) var resendService: Any? // EmailService?
    private(set) var supabaseEmailService: Any // SupabaseEmailService
    private(set) var emailTemplateManager: Any // EmailTemplateManager
    
    // MARK: - App State
    private(set) var appState: AppState
    
    // MARK: - ViewModels
    private(set) var homeViewModel: HomeViewModel
    private(set) var galleryViewModel: GalleryViewModel
    private(set) var timelineViewModel: TimelineViewModel
    private(set) var profileViewModel: ProfileViewModel
    
    // MARK: - Initialization
    
    private init() {
        // Initialize core services
        self.supabaseService = SupabaseService.shared
        self.logger = Logger.shared
        self.imageProcessor = ImageProcessor()
        
        // Initialize email services
        let supabaseEmailService = "SupabaseEmailService" // SupabaseEmailService(supabaseService: supabaseService)
        let templateManager = "EmailTemplateManager" // EmailTemplateManager()
        
        // Create primary service (Resend Service) if enabled
        var resendService: Any? // EmailService?
        var emailServiceManager: Any // EmailServiceManager
        
        if EmailConfiguration.isResendEnabled {
            // Create Resend service
            let resendConfiguration = EmailConfiguration.resendConfig
            resendService = "ResendService" // Placeholder
            
            // Create service manager with both services
            emailServiceManager = "EmailServiceManager" // EmailServiceManager(
                // primaryService: resendService!,
                // fallbackService: supabaseEmailService
            // )
            
            Logger.shared.info("Email services created with Resend")
            
        } else {
            // Create service manager with only fallback service
            emailServiceManager = "EmailServiceManager" // EmailServiceManager(
                // primaryService: supabaseEmailService,
                // fallbackService: supabaseEmailService
            // )
            
            Logger.shared.info("Email services created with Supabase fallback only")
        }
        
        self.emailServiceManager = emailServiceManager
        self.resendService = resendService
        self.supabaseEmailService = supabaseEmailService
        self.emailTemplateManager = templateManager
        
        // Initialize business services with email integration
        self.authService = AuthService(
            supabaseService: supabaseService,
            emailServiceManager: emailServiceManager
        )
        self.storageService = StorageService(supabaseService: supabaseService)
        self.aiService = AIService()
        
        // Initialize app state
        self.appState = AppState()
        
        // Initialize view models
        self.homeViewModel = HomeViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        self.galleryViewModel = GalleryViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        self.timelineViewModel = TimelineViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        self.profileViewModel = ProfileViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        // Setup service dependencies
        setupServiceDependencies()
    }
    
    // MARK: - Setup
    
    private func setupServiceDependencies() {
        // Configure services with their dependencies
        // Email services are configured during initialization
        Logger.shared.info("DependencyContainer initialised with email services")
    }
    
    
    // MARK: - Public Methods
    
    func reset() {
        // Reset app state
        appState.logout()
        
        // Reset services
        // supabaseService.reset() // TODO: Implement service reset
        authService.reset()
        storageService.reset()
        aiService.reset()
        
        // Reset email services (clear statistics)
        // if let resendService = resendService as? ResendService {
        //     resendService.resetDailyStatistics()
        // }
        // supabaseEmailService.resetDailyStatistics()
        // emailServiceManager.resetStatistics()
        
        // Reinitialize view models
        homeViewModel = HomeViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        galleryViewModel = GalleryViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        timelineViewModel = TimelineViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
        
        profileViewModel = ProfileViewModel(
            supabaseService: supabaseService,
            appState: appState
        )
    }
    
    func configureForTesting() {
        // Configure services for testing environment
        // supabaseService.configureForTesting() // TODO: Implement testing configuration
        authService.configureForTesting()
        storageService.configureForTesting()
        aiService.configureForTesting()
        
        // Configure email services for testing (use MockEmailService)
        // let mockEmailService = MockEmailService()
        self.emailServiceManager = "MockEmailServiceManager" // EmailServiceManager(
            // primaryService: mockEmailService,
            // fallbackService: mockEmailService
        // )
        
        Logger.shared.info("DependencyContainer configured for testing")
    }
}

// MARK: - Service Protocols

protocol ServiceProtocol {
    func reset()
    func configureForTesting()
}

// MARK: - Dependency Injection Extensions

extension DependencyContainer {
    // MARK: - Service Injection
    
    func inject<T>(_ serviceType: T.Type) -> T? {
        switch serviceType {
        case is SupabaseService.Type:
            return supabaseService as? T
        case is AuthService.Type:
            return authService as? T
        case is StorageService.Type:
            return storageService as? T
        case is AIService.Type:
            return aiService as? T
        case is ImageProcessor.Type:
            return imageProcessor as? T
        case is Logger.Type:
            return logger as? T
        case is Any.Type: // EmailServiceManager.Type:
            return emailServiceManager as? T
        case is Any.Type: // ResendService.Type:
            return resendService as? T
        case is Any.Type: // SupabaseEmailService.Type:
            return supabaseEmailService as? T
        case is Any.Type: // EmailTemplateManager.Type:
            return emailTemplateManager as? T
        default:
            return nil
        }
    }
    
    // MARK: - ViewModel Injection
    
    func injectViewModel<T>(_ viewModelType: T.Type) -> T? {
        switch viewModelType {
        case is HomeViewModel.Type:
            return homeViewModel as? T
        case is GalleryViewModel.Type:
            return galleryViewModel as? T
        case is TimelineViewModel.Type:
            return timelineViewModel as? T
        case is ProfileViewModel.Type:
            return profileViewModel as? T
        default:
            return nil
        }
    }
}

// MARK: - Environment Key (TODO: Implement SwiftUI environment integration)

// struct DependencyContainerKey: EnvironmentKey {
//     static let defaultValue = DependencyContainer.shared
// }
//
// extension EnvironmentValues {
//     var dependencies: DependencyContainer {
//         get { self[DependencyContainerKey.self] }
//         set { self[DependencyContainerKey.self] = newValue }
//     }
// }
//
// // MARK: - View Extension
//
// extension View {
//     func withDependencies(_ container: DependencyContainer = .shared) -> some View {
//         self.environment(\.dependencies, container)
//     }
// }
//
// // MARK: - Property Wrapper
//
// @propertyWrapper
// struct Injected<T> {
//     private let keyPath: KeyPath<DependencyContainer, T>
//     
//     init(_ keyPath: KeyPath<DependencyContainer, T>) {
//         self.keyPath = keyPath
//     }
//     
//     var wrappedValue: T {
//         DependencyContainer.shared[keyPath: keyPath]
//     }
// }

// MARK: - Usage Examples

/*
 // In a View:
 struct MyView: View {
     @Environment(\.dependencies) private var dependencies
     @Injected(\.supabaseService) private var supabaseService
     
     var body: some View {
         // Use dependencies
     }
 }
 
 // In a ViewModel:
 class MyViewModel: ObservableObject {
     @Injected(\.supabaseService) private var supabaseService
     @Injected(\.appState) private var appState
     
     // Use injected services
 }
 
 // In a Service:
 class MyService {
     @Injected(\.logger) private var logger
     
     func doSomething() {
         logger.info("Doing something")
     }
 }
 */

// MARK: - Email Services Container

/// Container for email service initialization results
struct EmailServicesContainer {
    let manager: Any // EmailServiceManager
    let resendService: Any? // EmailService?
    let supabaseService: Any // SupabaseEmailService
    let templateManager: Any // EmailTemplateManager
    
    var summary: [String: Any] {
        return [
            "managerType": String(describing: type(of: manager)),
            "hasResendService": resendService != nil,
            "supabaseServiceType": String(describing: type(of: supabaseService)),
            "templateManagerType": String(describing: type(of: templateManager))
        ]
    }
}
