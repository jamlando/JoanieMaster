import Foundation
import Combine

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
    
    // MARK: - App State
    private(set) var appState: AppState
    
    // MARK: - ViewModels
    private(set) var homeViewModel: HomeViewModel
    private(set) var galleryViewModel: GalleryViewModel
    private(set) var timelineViewModel: TimelineViewModel
    private(set) var profileViewModel: ProfileViewModel
    
    // MARK: - Initialization
    
    private init() {
        // Initialize services
        self.supabaseService = SupabaseService()
        self.authService = AuthService(supabaseService: supabaseService)
        self.storageService = StorageService(supabaseService: supabaseService)
        self.aiService = AIService()
        self.imageProcessor = ImageProcessor()
        self.logger = Logger()
        
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
        authService.configure(with: supabaseService)
        storageService.configure(with: supabaseService)
        aiService.configure(with: supabaseService)
    }
    
    // MARK: - Public Methods
    
    func reset() {
        // Reset app state
        appState.logout()
        
        // Reset services
        supabaseService.reset()
        authService.reset()
        storageService.reset()
        aiService.reset()
        
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
        supabaseService.configureForTesting()
        authService.configureForTesting()
        storageService.configureForTesting()
        aiService.configureForTesting()
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
        default:
            return nil
        }
    }
    
    // MARK: - ViewModel Injection
    
    func inject<T>(_ viewModelType: T.Type) -> T? {
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

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencies, container)
    }
}

// MARK: - Property Wrapper

@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>
    
    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        DependencyContainer.shared[keyPath: keyPath]
    }
}

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
