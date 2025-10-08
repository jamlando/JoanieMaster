import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Photo Capture
            PhotoCaptureView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Capture")
                }
                .tag(0)
            
            // Story Generation Tab
            StoryGenerationView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Stories")
                }
                .tag(1)
            
            // Photo Library Tab
            PhotoLibraryView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Library")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}
