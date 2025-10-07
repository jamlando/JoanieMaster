import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var appViewModel: AppViewModel
    @State private var showingProfileCompletion = false
    
    init() {
        // Initialize with a placeholder - will be updated in onAppear
        self._appViewModel = StateObject(wrappedValue: AppViewModel(authService: AuthService(supabaseService: SupabaseService.shared, emailServiceManager: DependencyContainer.shared.emailServiceManager)))
    }
    
    var body: some View {
        Group {
            if appViewModel.isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if appViewModel.isAuthenticated {
                MainTabView()
                    .onAppear {
                        // Check if user needs to complete profile
                        checkProfileCompletion()
                    }
            } else {
                LandingViewContent()
            }
        }
        .onAppear {
            // Update the appViewModel to use the injected authService
            appViewModel.updateAuthService(authService)
            
            // Attempt to restore session automatically
            Task {
                await appViewModel.restoreSession()
            }
            
            // Test Supabase connection on app launch
            Task {
                // TODO: Add Supabase tests
            }
        }
        .sheet(isPresented: $showingProfileCompletion) {
            ProfileCompletionSheet()
        }
    }
    
    private func checkProfileCompletion() {
        guard let currentUser = authService.currentUser else { return }
        
        // Check if user has incomplete profile (no full name)
        if currentUser.fullName?.isEmpty ?? true {
            showingProfileCompletion = true
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            GalleryView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Gallery")
                }
            
            TimelineView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Timeline")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
        }
    }
}

struct HomeView: View {
    @State private var showingPhotoCapture = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Joanie")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Preserve and celebrate your child's creative journey")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        showingPhotoCapture = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Artwork")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // TODO: Implement story generation
                    }) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Create Story")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Home")
        }
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureFlowView(
                isPresented: $showingPhotoCapture,
                capturedImage: $capturedImage
            )
        }
        .onChange(of: capturedImage) { image in
            if image != nil {
                // TODO: Handle captured image - upload to storage, create artwork entry, etc.
                print("Image captured: \(image?.size ?? CGSize.zero)")
            }
        }
    }
}

struct GalleryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Gallery")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Your child's artwork collection will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Gallery")
        }
    }
}

struct TimelineView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Timeline")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Track your child's creative progress over time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Timeline")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    
    init() {
        self._profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            supabaseService: SupabaseService.shared,
            appState: AppState()
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                VStack(spacing: 16) {
                    // Profile Image
                    Group {
                        if let avatarURL = authService.currentUser?.avatarURL, !avatarURL.isEmpty {
                            AsyncImage(url: URL(string: avatarURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(authService.userDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(authService.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let role = authService.currentUser?.role {
                        Text(role.displayName)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                // Profile Options
                VStack(spacing: 16) {
                    Button(action: {
                        showingEditProfile = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Edit Profile")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // TODO: Navigate to child management
                    }) {
                        HStack {
                            Image(systemName: "person.2")
                            Text("Manage Children")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Out Button
                Button(action: {
                    Task {
                        do {
                            try await authService.signOut()
                        } catch {
                            print("Sign out failed: \(error)")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Sign Out")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                // TODO: Add ProfileEditSheet
                Text("Profile Edit")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var showingDeleteAccountAlert = false
    @State private var showingExportDataAlert = false
    @State private var notificationsEnabled = true
    @State private var analyticsEnabled = true
    @State private var darkModeEnabled = false
    
    init() {
        self._profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            supabaseService: SupabaseService.shared,
            appState: AppState()
        ))
    }
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    SettingsRow(
                        icon: "person.circle",
                        title: "Profile Information",
                        subtitle: "Manage your personal details"
                    ) {
                        // TODO: Navigate to profile editing
                    }
                    
                    SettingsRow(
                        icon: "key",
                        title: "Change Password",
                        subtitle: "Update your account password"
                    ) {
                        // TODO: Navigate to password change
                    }
                    
                    SettingsRow(
                        icon: "envelope",
                        title: "Email Preferences",
                        subtitle: "Manage email notifications"
                    ) {
                        // TODO: Navigate to email preferences
                    }
                }
                
                // Privacy & Security Section
                Section("Privacy & Security") {
                    SettingsRow(
                        icon: "lock.shield",
                        title: "Privacy Settings",
                        subtitle: "Control your data privacy"
                    ) {
                        // TODO: Navigate to privacy settings
                    }
                    
                    SettingsRow(
                        icon: "eye.slash",
                        title: "Data Visibility",
                        subtitle: "Control who can see your content"
                    ) {
                        // TODO: Navigate to data visibility settings
                    }
                    
                    SettingsRow(
                        icon: "trash",
                        title: "Delete Account",
                        subtitle: "Permanently delete your account",
                        isDestructive: true
                    ) {
                        showingDeleteAccountAlert = true
                    }
                }
                
                // App Preferences Section
                Section("App Preferences") {
                    ToggleRow(
                        icon: "bell",
                        title: "Push Notifications",
                        subtitle: "Receive notifications about your child's progress",
                        isOn: $notificationsEnabled
                    )
                    
                    ToggleRow(
                        icon: "chart.bar",
                        title: "Analytics",
                        subtitle: "Help improve the app with anonymous usage data",
                        isOn: $analyticsEnabled
                    )
                    
                    ToggleRow(
                        icon: "moon",
                        title: "Dark Mode",
                        subtitle: "Use dark appearance",
                        isOn: $darkModeEnabled
                    )
                }
                
                // Data Management Section
                Section("Data Management") {
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: "Export Data",
                        subtitle: "Download your data"
                    ) {
                        showingExportDataAlert = true
                    }
                    
                    SettingsRow(
                        icon: "icloud.and.arrow.down",
                        title: "Sync Settings",
                        subtitle: "Manage data synchronization"
                    ) {
                        // TODO: Navigate to sync settings
                    }
                }
                
                // Support Section
                Section("Support") {
                    SettingsRow(
                        icon: "questionmark.circle",
                        title: "Help & FAQ",
                        subtitle: "Get help and find answers"
                    ) {
                        // TODO: Navigate to help
                    }
                    
                    SettingsRow(
                        icon: "envelope",
                        title: "Contact Support",
                        subtitle: "Get in touch with our team"
                    ) {
                        // TODO: Navigate to contact support
                    }
                    
                    SettingsRow(
                        icon: "star",
                        title: "Rate App",
                        subtitle: "Rate Joanie on the App Store"
                    ) {
                        // TODO: Open App Store rating
                    }
                }
                
                // App Information Section
                Section("About") {
                    SettingsRow(
                        icon: "info.circle",
                        title: "App Version",
                        subtitle: "1.0.0 (Build 1)",
                        showChevron: false
                    ) {}
                    
                    SettingsRow(
                        icon: "doc.text",
                        title: "Terms of Service",
                        subtitle: "Read our terms and conditions"
                    ) {
                        // TODO: Navigate to terms
                    }
                    
                    SettingsRow(
                        icon: "hand.raised",
                        title: "Privacy Policy",
                        subtitle: "Learn how we protect your data"
                    ) {
                        // TODO: Navigate to privacy policy
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await profileViewModel.deleteAccount()
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Export Data", isPresented: $showingExportDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                // TODO: Implement data export
            }
        } message: {
            Text("Your data will be exported as a ZIP file containing all your artwork, stories, and profile information.")
        }
    }
}

// MARK: - Settings Components

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isDestructive: Bool
    let showChevron: Bool
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        isDestructive: Bool = false,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Profile Completion Sheet

struct ProfileCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var fullName: String = ""
    @State private var role: UserRole = .parent
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentStep = 1
    @State private var canSkip = false
    
    init() {
        self._profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            supabaseService: SupabaseService.shared,
            appState: AppState()
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Header
                VStack(spacing: 16) {
                    // Progress Bar
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { step in
                            Circle()
                                .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.top, 20)
                    
                    Text("Complete Your Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(stepDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 30)
                
                // Content
                TabView(selection: $currentStep) {
                    // Step 1: Welcome
                    WelcomeStepView()
                        .tag(1)
                    
                    // Step 2: Profile Information
                    ProfileInfoStepView(
                        fullName: $fullName,
                        role: $role,
                        nameValidationMessage: nameValidationMessage
                    )
                    .tag(2)
                    
                    // Step 3: Profile Photo
                    ProfilePhotoStepView(
                        profileImage: $profileImage,
                        showingActionSheet: $showingActionSheet,
                        showingImagePicker: $showingImagePicker,
                        showingCamera: $showingCamera
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Navigation Buttons
                HStack {
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    if currentStep < 3 {
                        Button("Next") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .foregroundColor(.blue)
                        .disabled(currentStep == 2 && !isStep2Valid)
                    } else {
                        Button("Complete") {
                            Task {
                                await completeProfile()
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(8)
                        .disabled(!isFormValid || isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .overlay(
                // Loading Overlay
                Group {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Completing Profile...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
            )
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Select Photo"),
                message: Text("Choose how you'd like to add a photo"),
                buttons: [
                    .default(Text("Camera")) {
                        showingCamera = true
                    },
                    .default(Text("Photo Library")) {
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            SingleImagePicker(selectedImage: $profileImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            SingleImagePicker(selectedImage: $profileImage, sourceType: .camera)
        }
        .alert("Profile Completed", isPresented: .constant(false)) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been completed successfully!")
        }
        .onAppear {
            // Initialize with current user data
            if let currentUser = authService.currentUser {
                fullName = currentUser.fullName ?? ""
                role = currentUser.role
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var stepDescription: String {
        switch currentStep {
        case 1:
            return "Welcome to Joanie! Let's set up your profile to get started."
        case 2:
            return "Tell us about yourself so we can personalize your experience."
        case 3:
            return "Add a profile photo to make your account more personal."
        default:
            return ""
        }
    }
    
    var isStep2Valid: Bool {
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               nameValidationMessage.isEmpty
    }
    
    var isFormValid: Bool {
        return isStep2Valid
    }
    
    var nameValidationMessage: String {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "Full name is required"
        } else if trimmedName.count < 2 {
            return "Name must be at least 2 characters"
        } else if trimmedName.count > 50 {
            return "Name must be less than 50 characters"
        } else if !trimmedName.allSatisfy({ $0.isLetter || $0.isWhitespace }) {
            return "Name can only contain letters and spaces"
        }
        
        return ""
    }
    
    // MARK: - Actions
    
    func completeProfile() async {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Upload image if selected
            var finalAvatarURL: String?
            if let profileImage = profileImage {
                finalAvatarURL = try await uploadProfileImage(profileImage)
            }
            
            // Update profile
            await profileViewModel.updateProfile(
                name: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: finalAvatarURL
            )
            
            if profileViewModel.errorMessage == nil {
                dismiss()
            } else {
                errorMessage = profileViewModel.errorMessage
            }
            
        } catch {
            errorMessage = "Failed to complete profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func uploadProfileImage(_ image: UIImage) async throws -> String {
        // TODO: Implement actual image upload to Supabase Storage
        // For now, return a placeholder URL
        return "https://example.com/profile/\(UUID().uuidString).jpg"
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Welcome to Joanie!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Preserve and celebrate your child's creative journey with AI-powered insights and personalized stories.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                FeatureRow(icon: "camera.fill", title: "Capture Artwork", description: "Take photos of your child's drawings and artwork")
                FeatureRow(icon: "brain.head.profile", title: "AI Insights", description: "Get personalized tips and analysis")
                FeatureRow(icon: "book.fill", title: "Create Stories", description: "Transform artwork into magical stories")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "See your child's creative development")
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct ProfileInfoStepView: View {
    @Binding var fullName: String
    @Binding var role: UserRole
    let nameValidationMessage: String
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Profile Information")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This information helps us personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Full Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your full name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                    
                    if !nameValidationMessage.isEmpty {
                        Text(nameValidationMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Role Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Role", selection: $role) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct ProfilePhotoStepView: View {
    @Binding var profileImage: UIImage?
    @Binding var showingActionSheet: Bool
    @Binding var showingImagePicker: Bool
    @Binding var showingCamera: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Profile Photo")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add a photo to make your profile more personal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Profile Image Display
                Group {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 4)
                            )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 4)
                            )
                    }
                }
                
                Button(action: {
                    showingActionSheet = true
                }) {
                    Text(profileImage == nil ? "Add Photo" : "Change Photo")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Text("Optional - You can skip this step")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Landing View Content

struct LandingViewContent: View {
    @State private var currentSlide = 0
    @State private var showingSignUp = false
    @State private var showingLogin = false
    
    private let slides = [
        LandingSlide(
            title: "Tired of throwing away your child's drawings?",
            description: "Preserve every masterpiece digitally",
            icon: "trash.slash.fill",
            color: .red
        ),
        LandingSlide(
            title: "Upload to Joanie and create stories to share with your child.",
            description: "Transform artwork into magical bedtime stories",
            icon: "book.fill",
            color: .blue
        ),
        LandingSlide(
            title: "Watch your child's creativity grow",
            description: "Track progress and celebrate milestones",
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Hero Section
                VStack(spacing: 20) {
                    Spacer()
                    
                    // App Icon/Logo
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.bottom, 10)
                    
                    // Hero Text
                    Text("Turn your kids' drawings into a bedtime story that can continue with all the new drawings your child creates.")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.4)
                
                // Carousel Section
                VStack(spacing: 20) {
                    // Carousel
                    TabView(selection: $currentSlide) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            LandingSlideView(slide: slides[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 200)
                    
                    // Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentSlide ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 10)
                }
                .frame(height: geometry.size.height * 0.35)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Sign Up Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Sign Up")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Login Button
                    Button(action: {
                        showingLogin = true
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Login")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color.blue.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingSignUp) {
            RegisterView(authService: DependencyContainer.shared.authService)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(authService: DependencyContainer.shared.authService)
        }
        .onAppear {
            // Auto-rotate carousel every 5 seconds
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentSlide = (currentSlide + 1) % slides.count
                }
            }
        }
    }
}

struct LandingSlide {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct LandingSlideView: View {
    let slide: LandingSlide
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: slide.icon)
                .font(.system(size: 60))
                .foregroundColor(slide.color)
            
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(slide.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
