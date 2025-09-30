import Foundation
import Vision
import Combine

@MainActor
class AIService: ObservableObject, ServiceProtocol {
    // MARK: - Published Properties
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.supabaseService = SupabaseService()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Setup any necessary bindings
    }
    
    // MARK: - Public Methods
    
    func analyzeArtwork(_ imageData: Data, for child: Child) async throws -> AIAnalysis {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        do {
            // Step 1: Basic image analysis with Vision Framework
            analysisProgress = 0.2
            let basicAnalysis = try await performBasicImageAnalysis(imageData)
            
            // Step 2: Color analysis
            analysisProgress = 0.4
            let colorAnalysis = try await analyzeColors(imageData)
            
            // Step 3: Object detection
            analysisProgress = 0.6
            let objectDetection = try await detectObjects(imageData)
            
            // Step 4: Skill assessment
            analysisProgress = 0.8
            let skillAssessment = try await assessSkills(basicAnalysis, colorAnalysis, objectDetection, for: child)
            
            // Step 5: Generate tips
            analysisProgress = 0.9
            let tips = try await generateTips(skillAssessment, for: child)
            
            // Combine all analyses
            let finalAnalysis = AIAnalysis(
                detectedObjects: objectDetection,
                colors: colorAnalysis,
                emotions: basicAnalysis.emotions,
                skills: skillAssessment,
                tips: tips,
                confidence: calculateConfidence(basicAnalysis, colorAnalysis, objectDetection)
            )
            
            isAnalyzing = false
            analysisProgress = 1.0
            return finalAnalysis
            
        } catch {
            isAnalyzing = false
            analysisProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func generateStory(from artwork: [ArtworkUpload], for child: Child) async throws -> Story {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        do {
            // Step 1: Analyze all artwork
            analysisProgress = 0.2
            let analyses = try await analyzeMultipleArtwork(artwork, for: child)
            
            // Step 2: Generate story content
            analysisProgress = 0.6
            let storyContent = try await generateStoryContent(analyses, for: child)
            
            // Step 3: Create story title
            analysisProgress = 0.8
            let storyTitle = try await generateStoryTitle(storyContent, for: child)
            
            // Step 4: Create story object
            analysisProgress = 0.9
            let story = Story(
                userId: child.userId,
                childId: child.id,
                title: storyTitle,
                content: storyContent,
                artworkIds: artwork.map { $0.id },
                status: .generated
            )
            
            isAnalyzing = false
            analysisProgress = 1.0
            return story
            
        } catch {
            isAnalyzing = false
            analysisProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func generateVoiceover(for story: Story) async throws -> String {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        
        do {
            // Generate voiceover using text-to-speech
            analysisProgress = 0.5
            let voiceURL = try await generateTextToSpeech(story.content)
            
            isAnalyzing = false
            analysisProgress = 1.0
            return voiceURL
            
        } catch {
            isAnalyzing = false
            analysisProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func performBasicImageAnalysis(_ imageData: Data) async throws -> BasicImageAnalysis {
        return try await withCheckedThrowingContinuation { continuation in
            guard let image = UIImage(data: imageData) else {
                continuation.resume(throwing: AppError.aiServiceError("Invalid image data"))
                return
            }
            
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: AppError.aiServiceError("Could not create CGImage"))
                return
            }
            
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(throwing: AppError.aiServiceError("No classification results"))
                    return
                }
                
                let emotions = observations
                    .filter { $0.confidence > 0.5 }
                    .map { $0.identifier }
                    .prefix(5)
                
                let analysis = BasicImageAnalysis(emotions: Array(emotions))
                continuation.resume(returning: analysis)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func analyzeColors(_ imageData: Data) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let image = UIImage(data: imageData) else {
                continuation.resume(throwing: AppError.aiServiceError("Invalid image data"))
                return
            }
            
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: AppError.aiServiceError("Could not create CGImage"))
                return
            }
            
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // For now, return basic color analysis
                // In a real implementation, you would analyze the image for dominant colors
                let colors = ["Red", "Blue", "Yellow", "Green", "Purple"]
                continuation.resume(returning: colors)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func detectObjects(_ imageData: Data) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let image = UIImage(data: imageData) else {
                continuation.resume(throwing: AppError.aiServiceError("Invalid image data"))
                return
            }
            
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: AppError.aiServiceError("Could not create CGImage"))
                return
            }
            
            let request = VNRecognizeObjectsRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(throwing: AppError.aiServiceError("No object detection results"))
                    return
                }
                
                let objects = observations
                    .filter { $0.confidence > 0.5 }
                    .compactMap { $0.labels.first?.identifier }
                    .prefix(10)
                
                continuation.resume(returning: Array(objects))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func assessSkills(_ basicAnalysis: BasicImageAnalysis, _ colorAnalysis: [String], _ objectDetection: [String], for child: Child) async throws -> [String] {
        // Assess skills based on analysis results
        var skills: [String] = []
        
        // Color recognition skill
        if colorAnalysis.count >= 3 {
            skills.append("Color Recognition")
        }
        
        // Object recognition skill
        if objectDetection.count >= 2 {
            skills.append("Object Recognition")
        }
        
        // Creativity skill (based on complexity)
        if objectDetection.count >= 5 {
            skills.append("Creativity")
        }
        
        // Fine motor skills (based on detail level)
        if objectDetection.count >= 3 {
            skills.append("Fine Motor Skills")
        }
        
        return skills
    }
    
    private func generateTips(_ skills: [String], for child: Child) async throws -> [String] {
        // Generate age-appropriate tips based on skills
        var tips: [String] = []
        
        for skill in skills {
            switch skill {
            case "Color Recognition":
                tips.append("Great use of colors! Try mixing different colors to create new ones.")
            case "Object Recognition":
                tips.append("I can see you drew recognizable objects. Keep practicing to add more details!")
            case "Creativity":
                tips.append("Your creativity is amazing! Try telling a story with your drawings.")
            case "Fine Motor Skills":
                tips.append("Your fine motor skills are developing well. Keep practicing with different tools!")
            default:
                tips.append("Keep up the great work! Your artistic skills are growing.")
            }
        }
        
        return tips
    }
    
    private func analyzeMultipleArtwork(_ artwork: [ArtworkUpload], for child: Child) async throws -> [AIAnalysis] {
        var analyses: [AIAnalysis] = []
        
        for item in artwork {
            if let analysis = item.aiAnalysis {
                analyses.append(analysis)
            }
        }
        
        return analyses
    }
    
    private func generateStoryContent(_ analyses: [AIAnalysis], for child: Child) async throws -> String {
        // Generate story content based on artwork analyses
        let objects = analyses.flatMap { $0.detectedObjects ?? [] }
        let colors = analyses.flatMap { $0.colors ?? [] }
        
        let story = """
        Once upon a time, \(child.name) created a magical world filled with \(colors.joined(separator: ", ")) colors. 
        In this world, there were \(objects.joined(separator: ", ")) that came to life and had amazing adventures together.
        
        The story of \(child.name)'s imagination continues to grow with each new creation!
        """
        
        return story
    }
    
    private func generateStoryTitle(_ content: String, for child: Child) async throws -> String {
        return "\(child.name)'s Magical Adventure"
    }
    
    private func generateTextToSpeech(_ text: String) async throws -> String {
        // In a real implementation, you would use a text-to-speech service
        // For now, return a placeholder URL
        return "https://example.com/voice/\(UUID().uuidString).mp3"
    }
    
    private func calculateConfidence(_ basicAnalysis: BasicImageAnalysis, _ colorAnalysis: [String], _ objectDetection: [String]) -> Double {
        // Calculate overall confidence based on analysis results
        let colorConfidence = min(1.0, Double(colorAnalysis.count) / 5.0)
        let objectConfidence = min(1.0, Double(objectDetection.count) / 10.0)
        let emotionConfidence = min(1.0, Double(basicAnalysis.emotions.count) / 5.0)
        
        return (colorConfidence + objectConfidence + emotionConfidence) / 3.0
    }
    
    // MARK: - ServiceProtocol
    
    func reset() {
        isAnalyzing = false
        analysisProgress = 0.0
        errorMessage = nil
    }
    
    func configureForTesting() {
        reset()
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var isAnalyzingArtwork: Bool {
        return isAnalyzing
    }
    
    var analysisProgressPercentage: Int {
        return Int(analysisProgress * 100)
    }
}

// MARK: - Supporting Types

struct BasicImageAnalysis {
    let emotions: [String]
}

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case imageAnalysisFailed
    case storyGenerationFailed
    case voiceoverGenerationFailed
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .imageAnalysisFailed:
            return "Failed to analyze image"
        case .storyGenerationFailed:
            return "Failed to generate story"
        case .voiceoverGenerationFailed:
            return "Failed to generate voiceover"
        case .networkError:
            return "Network error occurred"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .imageAnalysisFailed:
            return "Please try again with a different image"
        case .storyGenerationFailed:
            return "Please try again or contact support"
        case .voiceoverGenerationFailed:
            return "Please try again later"
        case .networkError:
            return "Please check your internet connection"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}
