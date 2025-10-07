import SwiftUI
import UIKit

struct StoryGenerationView: View {
    @StateObject private var grokService = GrokAPIService()
    @State private var selectedImages: [UIImage] = []
    @State private var selectedChild: Child?
    @State private var children: [Child] = []
    @State private var theme: String = ""
    @State private var generatedStory: String = ""
    @State private var imagePlacements: [ImagePlacement] = []
    @State private var showingImagePicker = false
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var storyMetadata: StoryMetadata?
    @State private var isLoadingChildren = true
    
    // Available themes for story generation
    private let themes = [
        "Adventure", "Friendship", "Magic", "Animals", 
        "Space", "Underwater", "Fairy Tale", "Superhero"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header Section
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Create Magic Stories")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Turn your child's drawings into amazing bedtime stories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Child Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Story Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            // Child Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Child")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if isLoadingChildren {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading children...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                } else if children.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "person.2.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        
                                        Text("No children added yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text("Add a child in your profile to create personalized stories")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(children) { child in
                                                ChildSelectionCard(
                                                    child: child,
                                                    isSelected: selectedChild?.id == child.id
                                                ) {
                                                    selectedChild = child
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            
                            // Theme Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Story Theme (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Theme", selection: $theme) {
                                    Text("No specific theme").tag("")
                                    ForEach(themes, id: \.self) { theme in
                                        Text(theme).tag(theme)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Selected Images Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Selected Drawings")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Images")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if selectedImages.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("No drawings selected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Add your child's drawings to create a story")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            // Image preview grid
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        VStack(spacing: 8) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(12)
                                                .overlay(
                                                    Button(action: {
                                                        selectedImages.remove(at: index)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                    }
                                                    .offset(x: 8, y: -8),
                                                    alignment: .topTrailing
                                                )
                                            
                                            Text("Drawing \(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Magic Button Section
                    VStack(spacing: 16) {
                        if grokService.isLoading {
                            // Loading State
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                
                                Text("Creating magic...")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                
                                Text("Our AI is crafting your story")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 40)
                        } else {
                            // Magic Button
                            Button(action: generateStory) {
                                HStack(spacing: 12) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.title2)
                                    
                                    Text("Generate Story")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.purple, .blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(selectedImages.isEmpty || selectedChild == nil)
                            .opacity(selectedImages.isEmpty || selectedChild == nil ? 0.6 : 1.0)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Generated Story Section
                    if !generatedStory.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Your Story")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingShareSheet = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Story content with embedded images
                            StoryContentView(
                                storyText: generatedStory,
                                images: selectedImages,
                                imagePlacements: imagePlacements
                            )
                            
                            // Story metadata
                            if let metadata = storyMetadata {
                                StoryMetadataView(metadata: metadata)
                            }
                            
                            // Action buttons
                            HStack(spacing: 16) {
                                Button(action: {
                                    // Save to profile functionality
                                }) {
                                    HStack {
                                        Image(systemName: "bookmark.fill")
                                        Text("Save Story")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    // Continue story functionality
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Continue Story")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Story Generator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImages: $selectedImages, maxSelection: 10)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generatedStory])
        }
            .onAppear {
                loadChildren()
            }
    }
    
    // MARK: - Story Generation
    
    private func generateStory() {
        guard let child = selectedChild else { return }
        
        Task {
            do {
                let response = try await grokService.generateStory(
                    from: selectedImages,
                    childName: child.name,
                    theme: theme.isEmpty ? nil : theme
                )
                
                await MainActor.run {
                    generatedStory = response.storyText
                    imagePlacements = response.imagePlacements
                    storyMetadata = response.metadata
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadChildren() {
        isLoadingChildren = true
        
        // Mock data for now - in production, this would load from the backend
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            children = [
                Child(
                    userId: UUID(), // This should be the current user's ID
                    name: "Emma",
                    birthDate: Calendar.current.date(byAdding: .year, value: -5, to: Date()),
                    avatarURL: nil
                ),
                Child(
                    userId: UUID(),
                    name: "Liam",
                    birthDate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
                    avatarURL: nil
                )
            ]
            
            // Auto-select first child if available
            if let firstChild = children.first {
                selectedChild = firstChild
            }
            
            isLoadingChildren = false
        }
    }
}

// MARK: - Story Content View

struct StoryContentView: View {
    let storyText: String
    let images: [UIImage]
    let imagePlacements: [ImagePlacement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(storyText)
                .font(.body)
                .lineSpacing(4)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - Story Metadata View

struct StoryMetadataView: View {
    let metadata: StoryMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Story Details")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                if let theme = metadata.theme {
                    Label(theme, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Label("\(metadata.estimatedReadingTime) min read", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(metadata.wordCount) words", systemImage: "textformat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

}

// MARK: - Child Selection Card

struct ChildSelectionCard: View {
    let child: Child
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
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
                
                // Name
                Text(child.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Age
                Text(child.ageDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StoryGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        StoryGenerationView()
    }
}
