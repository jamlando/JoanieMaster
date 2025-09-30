import Foundation
import Combine

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var timelineEntries: [TimelineEntry] = []
    @Published var filteredEntries: [TimelineEntry] = []
    @Published var selectedEntry: TimelineEntry?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Filter Properties
    @Published var selectedCategory: TimelineCategory = .all
    @Published var selectedDateRange: DateRange = .all
    @Published var searchText: String = ""
    @Published var sortOption: TimelineSortOption = .chronological
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var selectedChild: Child? {
        return appState.selectedChild
    }
    
    var hasEntries: Bool {
        return !timelineEntries.isEmpty
    }
    
    var hasFilteredEntries: Bool {
        return !filteredEntries.isEmpty
    }
    
    var entriesCount: Int {
        return timelineEntries.count
    }
    
    var filteredEntriesCount: Int {
        return filteredEntries.count
    }
    
    var isFiltered: Bool {
        return selectedCategory != .all ||
               selectedDateRange != .all ||
               !searchText.isEmpty ||
               sortOption != .chronological
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
                    await self?.loadTimeline()
                }
            }
            .store(in: &cancellables)
        
        // Observe filter changes
        Publishers.CombineLatest4(
            $selectedCategory,
            $selectedDateRange,
            $searchText,
            $sortOption
        )
        .sink { [weak self] _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadTimeline() async {
        guard let selectedChild = selectedChild else {
            clearData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let artworkTask = supabaseService.getAllArtwork(for: selectedChild.id)
            async let storiesTask = supabaseService.getAllStories(for: selectedChild.id)
            async let progressTask = supabaseService.getChildProgress(for: selectedChild.id)
            
            let (artwork, stories, progress) = try await (artworkTask, storiesTask, progressTask)
            
            timelineEntries = createTimelineEntries(
                artwork: artwork,
                stories: stories,
                progress: progress
            )
            
            applyFilters()
            
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("Failed to load timeline: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshTimeline() async {
        await loadTimeline()
    }
    
    func clearData() {
        timelineEntries = []
        filteredEntries = []
        selectedEntry = nil
        errorMessage = nil
    }
    
    func selectEntry(_ entry: TimelineEntry) {
        selectedEntry = entry
    }
    
    func clearSelection() {
        selectedEntry = nil
    }
    
    // MARK: - Filter Methods
    
    func applyFilters() {
        var filtered = timelineEntries
        
        // Filter by category
        if selectedCategory != .all {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by date range
        if selectedDateRange != .all {
            let calendar = Calendar.current
            let now = Date()
            
            switch selectedDateRange {
            case .today:
                filtered = filtered.filter { calendar.isDateInToday($0.date) }
            case .thisWeek:
                filtered = filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            case .thisMonth:
                filtered = filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            case .thisYear:
                filtered = filtered.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
            case .all:
                break
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                entry.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort entries
        switch sortOption {
        case .chronological:
            filtered = filtered.sorted { $0.date > $1.date }
        case .reverseChronological:
            filtered = filtered.sorted { $0.date < $1.date }
        case .category:
            filtered = filtered.sorted { $0.category.displayName < $1.category.displayName }
        case .title:
            filtered = filtered.sorted { $0.title < $1.title }
        }
        
        filteredEntries = filtered
    }
    
    func clearFilters() {
        selectedCategory = .all
        selectedDateRange = .all
        searchText = ""
        sortOption = .chronological
    }
    
    // MARK: - Private Methods
    
    private func createTimelineEntries(
        artwork: [ArtworkUpload],
        stories: [Story],
        progress: [ProgressEntry]
    ) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        
        // Add artwork entries
        for item in artwork {
            entries.append(TimelineEntry(
                id: item.id,
                title: item.displayTitle,
                description: item.description ?? "Artwork created",
                date: item.createdAt,
                category: .artwork,
                artwork: item,
                story: nil,
                progress: nil
            ))
        }
        
        // Add story entries
        for story in stories {
            entries.append(TimelineEntry(
                id: story.id,
                title: story.title,
                description: "Story created with \(story.artworkCount) artwork\(story.artworkCount == 1 ? "" : "s")",
                date: story.createdAt,
                category: .story,
                artwork: nil,
                story: story,
                progress: nil
            ))
        }
        
        // Add progress entries
        for progressItem in progress {
            entries.append(TimelineEntry(
                id: progressItem.id,
                title: "\(progressItem.skillDisplayName) - \(progressItem.levelDisplayName)",
                description: progressItem.notes ?? "Skill progress updated",
                date: progressItem.createdAt,
                category: .progress,
                artwork: nil,
                story: nil,
                progress: progressItem
            ))
        }
        
        return entries
    }
}

// MARK: - Supporting Types

struct TimelineEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let category: TimelineCategory
    let artwork: ArtworkUpload?
    let story: Story?
    let progress: ProgressEntry?
    
    var emoji: String {
        return category.emoji
    }
    
    var formattedDate: String {
        return DateFormatter.timelineDateFormatter.string(from: date)
    }
    
    var relativeDate: String {
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

enum TimelineCategory: String, CaseIterable {
    case all = "all"
    case artwork = "artwork"
    case story = "story"
    case progress = "progress"
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .artwork:
            return "Artwork"
        case .story:
            return "Stories"
        case .progress:
            return "Progress"
        }
    }
    
    var emoji: String {
        switch self {
        case .all:
            return "📅"
        case .artwork:
            return "🎨"
        case .story:
            return "📚"
        case .progress:
            return "📈"
        }
    }
}

enum TimelineSortOption: String, CaseIterable {
    case chronological = "chronological"
    case reverseChronological = "reverse_chronological"
    case category = "category"
    case title = "title"
    
    var displayName: String {
        switch self {
        case .chronological:
            return "Newest First"
        case .reverseChronological:
            return "Oldest First"
        case .category:
            return "By Category"
        case .title:
            return "By Title"
        }
    }
}
