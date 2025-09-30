import Foundation
import Combine

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var artwork: [ArtworkUpload] = []
    @Published var filteredArtwork: [ArtworkUpload] = []
    @Published var selectedArtwork: ArtworkUpload?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Filter Properties
    @Published var selectedArtworkType: ArtworkType?
    @Published var selectedDateRange: DateRange = .all
    @Published var searchText: String = ""
    @Published var showFavoritesOnly: Bool = false
    @Published var sortOption: SortOption = .newest
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var selectedChild: Child? {
        return appState.selectedChild
    }
    
    var hasArtwork: Bool {
        return !artwork.isEmpty
    }
    
    var hasFilteredArtwork: Bool {
        return !filteredArtwork.isEmpty
    }
    
    var artworkCount: Int {
        return artwork.count
    }
    
    var filteredArtworkCount: Int {
        return filteredArtwork.count
    }
    
    var isFiltered: Bool {
        return selectedArtworkType != nil ||
               selectedDateRange != .all ||
               !searchText.isEmpty ||
               showFavoritesOnly ||
               sortOption != .newest
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
                    await self?.loadArtwork()
                }
            }
            .store(in: &cancellables)
        
        // Observe filter changes
        Publishers.CombineLatest4(
            $selectedArtworkType,
            $selectedDateRange,
            $searchText,
            $showFavoritesOnly
        )
        .combineLatest($sortOption)
        .sink { [weak self] _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadArtwork() async {
        guard let selectedChild = selectedChild else {
            clearData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            artwork = try await supabaseService.getAllArtwork(for: selectedChild.id)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load artwork: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshArtwork() async {
        await loadArtwork()
    }
    
    func clearData() {
        artwork = []
        filteredArtwork = []
        selectedArtwork = nil
        errorMessage = nil
    }
    
    func selectArtwork(_ artwork: ArtworkUpload) {
        selectedArtwork = artwork
    }
    
    func clearSelection() {
        selectedArtwork = nil
    }
    
    // MARK: - Filter Methods
    
    func applyFilters() {
        var filtered = artwork
        
        // Filter by artwork type
        if let selectedType = selectedArtworkType {
            filtered = filtered.filter { $0.artworkType == selectedType }
        }
        
        // Filter by date range
        if selectedDateRange != .all {
            let calendar = Calendar.current
            let now = Date()
            
            switch selectedDateRange {
            case .today:
                filtered = filtered.filter { calendar.isDateInToday($0.createdAt) }
            case .thisWeek:
                filtered = filtered.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear) }
            case .thisMonth:
                filtered = filtered.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
            case .thisYear:
                filtered = filtered.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .year) }
            case .all:
                break
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { artwork in
                artwork.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                artwork.description?.localizedCaseInsensitiveContains(searchText) == true ||
                artwork.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } == true
            }
        }
        
        // Filter by favorites
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        // Sort artwork
        switch sortOption {
        case .newest:
            filtered = filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            filtered = filtered.sorted { $0.createdAt < $1.createdAt }
        case .alphabetical:
            filtered = filtered.sorted { $0.displayTitle < $1.displayTitle }
        case .artworkType:
            filtered = filtered.sorted { $0.artworkType.displayName < $1.artworkType.displayName }
        }
        
        filteredArtwork = filtered
    }
    
    func clearFilters() {
        selectedArtworkType = nil
        selectedDateRange = .all
        searchText = ""
        showFavoritesOnly = false
        sortOption = .newest
    }
    
    // MARK: - Artwork Actions
    
    func toggleFavorite(_ artwork: ArtworkUpload) async {
        do {
            let updatedArtwork = artwork.withUpdatedFavoriteStatus(!artwork.isFavorite)
            try await supabaseService.updateArtwork(updatedArtwork)
            
            // Update local data
            if let index = self.artwork.firstIndex(where: { $0.id == artwork.id }) {
                self.artwork[index] = updatedArtwork
            }
            applyFilters()
            
        } catch {
            errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            Logger.error("Failed to toggle favorite: \(error)")
        }
    }
    
    func deleteArtwork(_ artwork: ArtworkUpload) async {
        do {
            try await supabaseService.deleteArtwork(artwork.id)
            
            // Update local data
            self.artwork.removeAll { $0.id == artwork.id }
            applyFilters()
            
            if selectedArtwork?.id == artwork.id {
                selectedArtwork = nil
            }
            
        } catch {
            errorMessage = "Failed to delete artwork: \(error.localizedDescription)"
            Logger.error("Failed to delete artwork: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum DateRange: String, CaseIterable {
    case all = "all"
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case thisYear = "this_year"
    
    var displayName: String {
        switch self {
        case .all:
            return "All Time"
        case .today:
            return "Today"
        case .thisWeek:
            return "This Week"
        case .thisMonth:
            return "This Month"
        case .thisYear:
            return "This Year"
        }
    }
}

enum SortOption: String, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case alphabetical = "alphabetical"
    case artworkType = "artwork_type"
    
    var displayName: String {
        switch self {
        case .newest:
            return "Newest First"
        case .oldest:
            return "Oldest First"
        case .alphabetical:
            return "Alphabetical"
        case .artworkType:
            return "By Type"
        }
    }
}
