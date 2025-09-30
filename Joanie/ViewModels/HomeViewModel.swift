import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recentArtwork: [ArtworkUpload] = []
    @Published var featuredStories: [Story] = []
    @Published var childProgress: [ProgressEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var selectedChild: Child? {
        return appState.selectedChild
    }
    
    var hasRecentArtwork: Bool {
        return !recentArtwork.isEmpty
    }
    
    var hasFeaturedStories: Bool {
        return !featuredStories.isEmpty
    }
    
    var hasProgress: Bool {
        return !childProgress.isEmpty
    }
    
    var recentArtworkCount: Int {
        return recentArtwork.count
    }
    
    var featuredStoriesCount: Int {
        return featuredStories.count
    }
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService, appState: AppState) {
        self.supabaseService = supabaseService
        self.appState = appState
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe selected child changes
        appState.$selectedChild
            .sink { [weak self] _ in
                Task {
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        guard let selectedChild = selectedChild else {
            clearData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let recentArtworkTask = loadRecentArtwork(for: selectedChild.id)
            async let featuredStoriesTask = loadFeaturedStories(for: selectedChild.id)
            async let progressTask = loadChildProgress(for: selectedChild.id)
            
            let (artwork, stories, progress) = try await (recentArtworkTask, featuredStoriesTask, progressTask)
            
            recentArtwork = artwork
            featuredStories = stories
            childProgress = progress
            
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load home data: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadData()
    }
    
    func clearData() {
        recentArtwork = []
        featuredStories = []
        childProgress = []
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func loadRecentArtwork(for childId: UUID) async throws -> [ArtworkUpload] {
        return try await supabaseService.getRecentArtwork(for: childId, limit: 6)
    }
    
    private func loadFeaturedStories(for childId: UUID) async throws -> [Story] {
        return try await supabaseService.getFeaturedStories(for: childId, limit: 3)
    }
    
    private func loadChildProgress(for childId: UUID) async throws -> [ProgressEntry] {
        return try await supabaseService.getChildProgress(for: childId, limit: 5)
    }
}

// MARK: - Helper Extensions

extension HomeViewModel {
    var welcomeMessage: String {
        guard let child = selectedChild else {
            return "Welcome to Joanie!"
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        
        return "\(greeting), \(child.name)!"
    }
    
    var progressSummary: String {
        guard !childProgress.isEmpty else {
            return "No progress data available"
        }
        
        let advancedSkills = childProgress.filter { $0.level == .advanced || $0.level == .expert }.count
        let totalSkills = childProgress.count
        
        if advancedSkills > 0 {
            return "\(advancedSkills) of \(totalSkills) skills are advanced or expert level"
        } else {
            return "\(totalSkills) skills being tracked"
        }
    }
}
