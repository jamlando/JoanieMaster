import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var userProfile: UserProfile?
    @State private var children: [Child] = []
    @State private var showingAddChild = false
    @State private var showingEditProfile = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // User Info Section
                        userInfoSection
                        
                        // Children Section
                        childrenSection
                        
                        // Story Statistics Section
                        storyStatisticsSection
                        
                        // Settings Section
                        settingsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .refreshable {
                await loadProfileData()
            }
            .onAppear {
                Task {
                    await loadProfileData()
                }
            }
            .sheet(isPresented: $showingAddChild) {
                AddChildView { newChild in
                    children.append(newChild)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(profile: userProfile) { updatedProfile in
                    userProfile = updatedProfile
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("User Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Edit") {
                    showingEditProfile = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userProfile?.firstName ?? "First Name")
                            .font(.headline)
                        Text(userProfile?.lastName ?? "Last Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text(userProfile?.email ?? "email@example.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Children Section
    
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Children")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Add Child") {
                    showingAddChild = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if children.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No children added yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your first child to start creating personalized stories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Your First Child") {
                        showingAddChild = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(children) { child in
                        ChildRowView(child: child) { updatedChild in
                            if let index = children.firstIndex(where: { $0.id == child.id }) {
                                children[index] = updatedChild
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Story Statistics Section
    
    private var storyStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Story Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "Total Stories",
                    value: "12",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "This Month",
                    value: "3",
                    icon: "calendar",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "Total Artwork",
                    value: "47",
                    icon: "photo.fill",
                    color: .orange
                )
                
                StatisticCard(
                    title: "Favorites",
                    value: "8",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Story reminders and updates"
                )
                
                Divider()
                
                SettingsRow(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    subtitle: "Manage your data and privacy"
                )
                
                Divider()
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help and contact support"
                )
                
                Divider()
                
                SettingsRow(
                    icon: "arrow.right.square.fill",
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    isDestructive: true
                ) {
                    Task {
                        await signOut()
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadProfileData() async {
        isLoading = true
        
        do {
            // Load user profile
            if let currentUser = authService.currentUser {
                userProfile = UserProfile(
                    id: currentUser.id,
                    email: currentUser.email,
                    firstName: currentUser.userMetadata["first_name"] as? String ?? "",
                    lastName: currentUser.userMetadata["last_name"] as? String ?? "",
                    createdAt: currentUser.createdAt,
                    updatedAt: currentUser.updatedAt
                )
            }
            
            // Load children (mock data for now)
            children = [
                Child(
                    userId: authService.currentUser?.id ?? UUID(),
                    name: "Emma",
                    birthDate: Calendar.current.date(byAdding: .year, value: -5, to: Date()),
                    avatarURL: nil
                ),
                Child(
                    userId: authService.currentUser?.id ?? UUID(),
                    name: "Liam",
                    birthDate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
                    avatarURL: nil
                )
            ]
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            isLoading = false
        }
    }
    
    private func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Child Row View

struct ChildRowView: View {
    let child: Child
    let onUpdate: (Child) -> Void
    @State private var showingEditChild = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            if let avatarURL = child.avatarURL {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Text(child.initials)
                                .font(.headline)
                                .foregroundColor(.blue)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(child.initials)
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
            }
            
            // Child Info
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(child.ageDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(child.ageGroup.displayName)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Edit Button
            Button(action: {
                showingEditChild = true
            }) {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingEditChild) {
            EditChildView(child: child) { updatedChild in
                onUpdate(updatedChild)
            }
        }
    }
}

// MARK: - Statistic Card

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, isDestructive: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService(supabaseService: SupabaseService.shared, emailServiceManager: DependencyContainer.shared.emailServiceManager))
}
