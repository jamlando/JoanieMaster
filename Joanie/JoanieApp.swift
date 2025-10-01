import SwiftUI

@main
struct JoanieApp: App {
    // MARK: - Dependencies
    @StateObject private var dependencyContainer = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer)
                .environmentObject(dependencyContainer.authService)
        }
    }
}
