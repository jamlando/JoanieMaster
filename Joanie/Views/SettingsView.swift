import SwiftUI
import UserNotifications

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.featureToggleManager) var featureToggleManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Profile Section
                profileSection
                
                // MARK: - Notifications Section
                notificationsSection
                
                // MARK: - Privacy & Security Section
                privacySection
                
                // MARK: - App Settings Section
                appSettingsSection
                
                // MARK: - Support Section
                supportSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        Section {
            HStack {
                // Profile Avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(viewModel.userInitials)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.userDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.memberSince)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    viewModel.showEditProfile()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
            
        } header: {
            Text("Profile")
        }
    }
    
    // MARK: - Notifications Section
    
    private var notificationsSection: some View {
        Section {
            // Notification Toggle
            NotificationToggleRow(
                isEnabled: $viewModel.notificationsEnabled,
                permissionStatus: viewModel.notificationPermissionStatus,
                onToggle: { enabled in
                    Task {
                        await viewModel.toggleNotifications(enabled: enabled)
                    }
                },
                notificationWrapperService: viewModel.notificationWrapperService
            )
            
            // Notification Types (if notifications are enabled)
            if viewModel.notificationsEnabled {
                NotificationTypesRow(
                    selectedTypes: $viewModel.selectedNotificationTypes,
                    onTypesChanged: { types in
                        viewModel.updateNotificationTypes(types)
                    }
                )
                
                // Quiet Hours (if notifications are enabled)
                QuietHoursRow(
                    quietHours: $viewModel.quietHours,
                    onQuietHoursChanged: { quietHours in
                        viewModel.updateQuietHours(quietHours)
                    }
                )
            }
            
        } header: {
            Text("Notifications")
        } footer: {
            Text("Control when and how you receive notifications about your child's artwork and progress.")
        }
    }
    
    // MARK: - Privacy & Security Section
    
    private var privacySection: some View {
        Section {
            NavigationLink(destination: PrivacySettingsView()) {
                Label("Privacy Settings", systemImage: "hand.raised.fill")
            }
            
            NavigationLink(destination: SecuritySettingsView()) {
                Label("Security", systemImage: "lock.fill")
            }
            
            Button(action: {
                viewModel.showDataExport()
            }) {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            .foregroundColor(.primary)
            
        } header: {
            Text("Privacy & Security")
        }
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section {
            NavigationLink(destination: AppearanceSettingsView()) {
                Label("Appearance", systemImage: "paintbrush.fill")
            }
            
            NavigationLink(destination: StorageSettingsView()) {
                Label("Storage", systemImage: "externaldrive.fill")
            }
            
            Button(action: {
                viewModel.clearCache()
            }) {
                Label("Clear Cache", systemImage: "trash")
            }
            .foregroundColor(.primary)
            
        } header: {
            Text("App Settings")
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            NavigationLink(destination: HelpView()) {
                Label("Help & Support", systemImage: "questionmark.circle.fill")
            }
            
            NavigationLink(destination: AboutView()) {
                Label("About", systemImage: "info.circle.fill")
            }
            
            Button(action: {
                viewModel.showFeedback()
            }) {
                Label("Send Feedback", systemImage: "envelope.fill")
            }
            .foregroundColor(.primary)
            
            Button(action: {
                Task {
                    await viewModel.logout()
                }
            }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .foregroundColor(.red)
            
        } header: {
            Text("Support")
        }
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    @Binding var isEnabled: Bool
    let permissionStatus: UNAuthorizationStatus
    let onToggle: (Bool) -> Void
    let notificationWrapperService: NotificationWrapperService
    
    @State private var showingPermissionAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(permissionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { newValue in
                    if newValue && permissionStatus != .authorized {
                        showingPermissionAlert = true
                    } else {
                        onToggle(newValue)
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notifications")
        .accessibilityValue(permissionDescription)
        .accessibilityHint("Double tap to toggle notifications")
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {
                isEnabled = false
            }
            Button("Allow") {
                Task {
                    await requestNotificationPermission()
                }
            }
        } message: {
            Text("To send notifications, please allow notification access in your device settings.")
        }
    }
    
    private var permissionDescription: String {
        switch permissionStatus {
        case .authorized:
            return "Notifications are enabled"
        case .denied:
            return "Notifications are disabled in Settings"
        case .notDetermined:
            return "Tap to enable notifications"
        case .provisional:
            return "Notifications are enabled (provisional)"
        case .ephemeral:
            return "Notifications are enabled (temporary)"
        @unknown default:
            return "Unknown permission status"
        }
    }
    
    private func requestNotificationPermission() async {
        await notificationWrapperService.requestNotificationPermission()
        
        if notificationWrapperService.notificationPermissionStatus == .authorized {
            onToggle(true)
        } else {
            isEnabled = false
        }
    }
}

// MARK: - Notification Types Row

struct NotificationTypesRow: View {
    @Binding var selectedTypes: [NotificationType]
    let onTypesChanged: ([NotificationType]) -> Void
    
    var body: some View {
        NavigationLink(destination: NotificationTypesSettingsView(
            selectedTypes: $selectedTypes,
            onTypesChanged: onTypesChanged
        )) {
            HStack {
                Label("Notification Types", systemImage: "bell.badge")
                
                Spacer()
                
                Text("\(selectedTypes.count) enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Quiet Hours Row

struct QuietHoursRow: View {
    @Binding var quietHours: QuietHours?
    let onQuietHoursChanged: (QuietHours?) -> Void
    
    var body: some View {
        NavigationLink(destination: QuietHoursSettingsView(
            quietHours: $quietHours,
            onQuietHoursChanged: onQuietHoursChanged
        )) {
            HStack {
                Label("Quiet Hours", systemImage: "moon")
                
                Spacer()
                
                if let quietHours = quietHours {
                    Text(quietHoursDisplayText(quietHours))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func quietHoursDisplayText(_ quietHours: QuietHours) -> String {
        let startHour = Int(quietHours.startTime / 3600)
        let endHour = Int(quietHours.endTime / 3600)
        return "\(startHour):00 - \(endHour):00"
    }
}

// MARK: - Settings View Model

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var selectedNotificationTypes: [NotificationType] = NotificationType.allCases
    @Published var quietHours: QuietHours? = nil
    @Published var userDisplayName: String = "User"
    @Published var userInitials: String = "U"
    @Published var memberSince: String = "Unknown"
    
    private let featureToggleManager: FeatureToggleManager
    private let notificationToggleService: NotificationToggleService
    let notificationWrapperService: NotificationWrapperService
    
    init(
        featureToggleManager: FeatureToggleManager = FeatureToggleManager(),
        notificationToggleService: NotificationToggleService = NotificationToggleService(),
        notificationWrapperService: NotificationWrapperService = NotificationWrapperService()
    ) {
        self.featureToggleManager = featureToggleManager
        self.notificationToggleService = notificationToggleService
        self.notificationWrapperService = notificationWrapperService
    }
    
    func loadSettings() async {
        // Load notification settings
        await checkNotificationPermission()
        
        // Load notification toggle state
        notificationsEnabled = featureToggleManager.isToggleEnabled(id: "notifications_enabled")
        
        // Load user profile info
        loadUserProfile()
    }
    
    func toggleNotifications(enabled: Bool) async {
        await featureToggleManager.setToggleEnabled(id: "notifications_enabled", enabled: enabled)
        notificationsEnabled = enabled
        
        // Track toggle usage
        featureToggleManager.trackToggleUsage(toggleId: "notifications_enabled", action: enabled ? "enabled" : "disabled")
    }
    
    func updateNotificationTypes(_ types: [NotificationType]) {
        selectedNotificationTypes = types
        // TODO: Update notification toggle metadata with selected types
    }
    
    func updateQuietHours(_ quietHours: QuietHours?) {
        self.quietHours = quietHours
        // TODO: Update notification toggle metadata with quiet hours
    }
    
    private func checkNotificationPermission() async {
        await notificationWrapperService.checkNotificationPermission()
        notificationPermissionStatus = notificationWrapperService.notificationPermissionStatus
    }
    
    private func loadUserProfile() {
        // TODO: Load from AppState or UserProfile
        userDisplayName = "John Doe"
        userInitials = "JD"
        memberSince = "Member since Jan 2024"
    }
    
    // MARK: - UI Actions
    
    func showEditProfile() {
        // TODO: Navigate to edit profile
    }
    
    func showDataExport() {
        // TODO: Show data export options
    }
    
    func clearCache() {
        // TODO: Clear app cache
    }
    
    func showFeedback() {
        // TODO: Show feedback form
    }
    
    func logout() async {
        await featureToggleManager.clearUserContext()
        // TODO: Handle logout
    }
}

// MARK: - Placeholder Views

struct PrivacySettingsView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

struct SecuritySettingsView: View {
    var body: some View {
        Text("Security Settings")
            .navigationTitle("Security")
    }
}

struct AppearanceSettingsView: View {
    var body: some View {
        Text("Appearance Settings")
            .navigationTitle("Appearance")
    }
}

struct StorageSettingsView: View {
    var body: some View {
        Text("Storage Settings")
            .navigationTitle("Storage")
    }
}

struct NotificationTypesSettingsView: View {
    @Binding var selectedTypes: [NotificationType]
    let onTypesChanged: ([NotificationType]) -> Void
    
    var body: some View {
        List {
            ForEach(NotificationType.allCases, id: \.self) { type in
                HStack {
                    Text(type.displayName)
                    Spacer()
                    if selectedTypes.contains(type) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedTypes.contains(type) {
                        selectedTypes.removeAll { $0 == type }
                    } else {
                        selectedTypes.append(type)
                    }
                    onTypesChanged(selectedTypes)
                }
            }
        }
        .navigationTitle("Notification Types")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QuietHoursSettingsView: View {
    @Binding var quietHours: QuietHours?
    let onQuietHoursChanged: (QuietHours?) -> Void
    
    var body: some View {
        Text("Quiet Hours Settings")
            .navigationTitle("Quiet Hours")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help & Support")
            .navigationTitle("Help")
    }
}

struct AboutView: View {
    var body: some View {
        Text("About Joanie")
            .navigationTitle("About")
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.featureToggleManager, FeatureToggleManager())
}
