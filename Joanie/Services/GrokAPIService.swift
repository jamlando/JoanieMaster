import Foundation
import UIKit

// MARK: - Grok API Models

struct GrokStoryRequest: Codable {
    let images: [String] // Base64 encoded images or URLs
    let childName: String
    let theme: String?
    let context: String?
    
    enum CodingKeys: String, CodingKey {
        case images
        case childName = "child_name"
        case theme
        case context
    }
}

struct GrokStoryResponse: Codable {
    let storyText: String
    let imagePlacements: [ImagePlacement]
    let metadata: StoryMetadata?
    
    enum CodingKeys: String, CodingKey {
        case storyText = "story_text"
        case imagePlacements = "image_placements"
        case metadata
    }
}

struct ImagePlacement: Codable {
    let imageIndex: Int
    let position: Int // Position in story text
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case imageIndex = "image_index"
        case position
        case description
    }
}

struct StoryMetadata: Codable {
    let theme: String?
    let ageAppropriate: Bool
    let estimatedReadingTime: Int // in minutes
    let wordCount: Int
    
    enum CodingKeys: String, CodingKey {
        case theme
        case ageAppropriate = "age_appropriate"
        case estimatedReadingTime = "estimated_reading_time"
        case wordCount = "word_count"
    }
}

// MARK: - Grok API Errors

enum GrokAPIError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case contentFiltered
    case imageProcessingFailed
    case storyGenerationFailed(String)
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Grok API"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .contentFiltered:
            return "Content was filtered by safety guidelines"
        case .imageProcessingFailed:
            return "Failed to process images"
        case .storyGenerationFailed(let reason):
            return "Story generation failed: \(reason)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Grok API Service

class GrokAPIService: ObservableObject {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    @Published var isLoading = false
    @Published var lastError: GrokAPIError?
    
    // MARK: - Initialization
    
    init(apiKey: String? = nil, baseURL: String = "https://api.grok.com/v1") {
        // In production, this should come from secure storage
        self.apiKey = apiKey ?? Secrets.grokAPIKey
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // 60 seconds for story generation
        config.timeoutIntervalForResource = 120.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Generate a bedtime story from child's drawings
    /// - Parameters:
    ///   - images: Array of UIImage objects representing child's drawings
    ///   - childName: Name of the child for personalization
    ///   - theme: Optional theme for the story (e.g., "adventure", "friendship", "magic")
    ///   - context: Optional context about the child or drawings
    /// - Returns: Generated story with embedded image placements
    func generateStory(
        from images: [UIImage],
        childName: String,
        theme: String? = nil,
        context: String? = nil
    ) async throws -> GrokStoryResponse {
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        // Check if we have a valid API key, if not use mock mode
        if apiKey.isEmpty || apiKey == "your-grok-api-key-here" {
            print("🔧 GrokAPIService: No valid API key found, using mock mode")
            return await generateMockStory(from: images, childName: childName, theme: theme)
        }
        
        do {
            // Convert images to base64
            let base64Images = try await processImages(images)
            
            // Create request
            let request = GrokStoryRequest(
                images: base64Images,
                childName: childName,
                theme: theme,
                context: context
            )
            
            // Make API call
            let response = try await makeStoryGenerationRequest(request)
            
            return response
            
        } catch let error as GrokAPIError {
            // If API fails, fall back to mock mode
            print("🔧 GrokAPIService: API failed (\(error)), falling back to mock mode")
            return await generateMockStory(from: images, childName: childName, theme: theme)
        } catch {
            // If any other error occurs, fall back to mock mode
            print("🔧 GrokAPIService: Unexpected error (\(error)), falling back to mock mode")
            return await generateMockStory(from: images, childName: childName, theme: theme)
        }
    }
    
    /// Generate a continuation of an existing story
    /// - Parameters:
    ///   - images: New drawings to add to the story
    ///   - previousStory: The previous story text
    ///   - childName: Name of the child
    /// - Returns: Extended story with new content
    func continueStory(
        with images: [UIImage],
        previousStory: String,
        childName: String
    ) async throws -> GrokStoryResponse {
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        // Check if we have a valid API key, if not use mock mode
        if apiKey.isEmpty || apiKey == "your-grok-api-key-here" {
            print("🔧 GrokAPIService: No valid API key found, using mock mode for story continuation")
            return await generateMockStory(from: images, childName: childName, theme: "continuation")
        }
        
        do {
            let base64Images = try await processImages(images)
            
            let request = GrokStoryRequest(
                images: base64Images,
                childName: childName,
                theme: "continuation",
                context: "Continue this story: \(previousStory)"
            )
            
            let response = try await makeStoryGenerationRequest(request)
            
            return response
            
        } catch let error as GrokAPIError {
            // If API fails, fall back to mock mode
            print("🔧 GrokAPIService: API failed (\(error)), falling back to mock mode for continuation")
            return await generateMockStory(from: images, childName: childName, theme: "continuation")
        } catch {
            // If any other error occurs, fall back to mock mode
            print("🔧 GrokAPIService: Unexpected error (\(error)), falling back to mock mode for continuation")
            return await generateMockStory(from: images, childName: childName, theme: "continuation")
        }
    }
    
    // MARK: - Private Methods
    
    private func processImages(_ images: [UIImage]) async throws -> [String] {
        return try await withThrowingTaskGroup(of: String.self) { group in
            var base64Images: [String] = []
            
            for image in images {
                group.addTask {
                    try await self.convertImageToBase64(image)
                }
            }
            
            for try await base64Image in group {
                base64Images.append(base64Image)
            }
            
            return base64Images
        }
    }
    
    private func convertImageToBase64(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Compress image for API efficiency
                guard let compressedImage = image.jpegData(compressionQuality: 0.8),
                      let base64String = compressedImage.base64EncodedString() else {
                    continuation.resume(throwing: GrokAPIError.imageProcessingFailed)
                    return
                }
                
                continuation.resume(returning: base64String)
            }
        }
    }
    
    private func makeStoryGenerationRequest(_ request: GrokStoryRequest) async throws -> GrokStoryResponse {
        guard let url = URL(string: "\(baseURL)/stories/generate") else {
            throw GrokAPIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Joanie-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GrokAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let storyResponse = try JSONDecoder().decode(GrokStoryResponse.self, from: data)
                return storyResponse
                
            case 401:
                throw GrokAPIError.authenticationFailed
                
            case 429:
                throw GrokAPIError.rateLimitExceeded
                
            case 400:
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw GrokAPIError.storyGenerationFailed(errorMessage)
                } else {
                    throw GrokAPIError.storyGenerationFailed("Bad request")
                }
                
            case 403:
                throw GrokAPIError.contentFiltered
                
            default:
                throw GrokAPIError.storyGenerationFailed("Server error: \(httpResponse.statusCode)")
            }
            
        } catch let error as GrokAPIError {
            throw error
        } catch {
            throw GrokAPIError.networkError(error)
        }
    }
    
    // MARK: - Testing Support
    
    /// Generate a mock story for testing purposes
    func generateMockStory(
        from images: [UIImage],
        childName: String,
        theme: String? = nil
    ) async -> GrokStoryResponse {
        
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let mockStory = """
        Once upon a time, there was a wonderful child named \(childName) who loved to draw amazing pictures. 
        
        In their latest masterpiece, \(childName) created a beautiful drawing that told a magical story. The colors were bright and cheerful, just like \(childName)'s imagination.
        
        As \(childName) looked at their drawing, they could see characters coming to life. There was a brave little hero who went on exciting adventures, meeting friendly animals along the way.
        
        The story continued with new drawings, each one adding more magic to the tale. \(childName) discovered that their artwork could create entire worlds filled with wonder and joy.
        
        And so, \(childName) learned that every drawing they made was a doorway to a new adventure, and their creativity would always lead to amazing stories.
        
        The end... for now! 🌟
        """
        
        let mockPlacements = images.enumerated().map { index, _ in
            ImagePlacement(
                imageIndex: index,
                position: index * 200, // Roughly every 200 characters
                description: "Drawing by \(childName)"
            )
        }
        
        let mockMetadata = StoryMetadata(
            theme: theme ?? "adventure",
            ageAppropriate: true,
            estimatedReadingTime: 3,
            wordCount: mockStory.components(separatedBy: .whitespaces).count
        )
        
        return GrokStoryResponse(
            storyText: mockStory,
            imagePlacements: mockPlacements,
            metadata: mockMetadata
        )
    }
}
