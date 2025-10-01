import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var appViewModel: AppViewModel
    
    init() {
        // Initialize with a placeholder - will be updated in onAppear
        self._appViewModel = StateObject(wrappedValue: AppViewModel(authService: AuthService(supabaseService: SupabaseService.shared)))
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
            } else {
                LoginView(authService: authService)
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
                await SupabaseTest.shared.runAllTests()
            }
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
                        // TODO: Implement camera capture
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(authService.userDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(authService.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Profile Options
                VStack(spacing: 16) {
                    Button(action: {
                        // TODO: Navigate to profile editing
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
                        // TODO: Navigate to settings
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
        }
    }
}

#Preview {
    ContentView()
}
