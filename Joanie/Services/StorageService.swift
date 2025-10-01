import Foundation
// import Supabase // TODO: Add Supabase dependency
import Combine
import UIKit

@MainActor
class StorageService: ObservableObject, ServiceProtocol {
    // MARK: - Published Properties
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe upload state changes
        // supabaseService.$isUploading // TODO: Add upload state tracking
        //     .sink { [weak self] isUploading in
        //         self?.isUploading = isUploading
        //     }
        //     .store(in: &cancellables)
        
        // supabaseService.$uploadProgress // TODO: Add upload progress tracking
        //     .sink { [weak self] progress in
        //         self?.uploadProgress = progress
        //     }
        //     .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func uploadArtwork(
        _ imageData: Data,
        for childId: UUID,
        title: String? = nil,
        description: String? = nil,
        artworkType: ArtworkType
    ) async throws -> ArtworkUpload {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            let artwork = try await supabaseService.uploadArtwork(
                childId: childId,
                title: title,
                description: description,
                imageData: imageData,
                artworkType: artworkType
            )
            
            isUploading = false
            uploadProgress = 1.0
            return artwork
            
        } catch {
            isUploading = false
            uploadProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func uploadProfileImage(_ imageData: Data, for userId: UUID) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            let imageURL = try await supabaseService.uploadProfileImage(imageData, for: userId)
            
            isUploading = false
            uploadProgress = 1.0
            return imageURL
            
        } catch {
            isUploading = false
            uploadProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func uploadChildAvatar(_ imageData: Data, for childId: UUID) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            // let imageURL = try await supabaseService.uploadChildAvatar(imageData, for: childId) // TODO: Implement child avatar upload
            let imageURL = "https://example.com/mock-child-avatar.jpg"
            
            isUploading = false
            uploadProgress = 1.0
            return imageURL
            
        } catch {
            isUploading = false
            uploadProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteArtwork(_ artworkId: UUID) async throws {
        isUploading = true
        errorMessage = nil
        
        do {
            // try await supabaseService.deleteArtwork(artworkId) // TODO: Implement artwork deletion
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteProfileImage(for userId: UUID) async throws {
        isUploading = true
        errorMessage = nil
        
        do {
            // try await supabaseService.deleteProfileImage(for: userId) // TODO: Implement profile image deletion
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func deleteChildAvatar(for childId: UUID) async throws {
        isUploading = true
        errorMessage = nil
        
        do {
            // try await supabaseService.deleteChildAvatar(for: childId) // TODO: Implement child avatar deletion
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Image Processing
    
    func processImage(_ image: UIImage, maxSize: CGSize = CGSize(width: 1920, height: 1920), quality: CGFloat = 0.8) -> Data? {
        // Sanitize image first to remove metadata
        guard let sanitizedImage = sanitizeImage(image) else { return nil }
        
        // Resize image if needed
        let resizedImage = sanitizedImage.resized(to: maxSize)
        
        // Compress image
        return resizedImage.jpegData(compressionQuality: quality)
    }
    
    func createThumbnail(from image: UIImage, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        return image.resized(to: size)
    }
    
    // MARK: - File Management
    
    func getFileSize(_ data: Data) -> Int {
        return data.count
    }
    
    func getImageDimensions(from data: Data) -> CGSize? {
        guard let image = UIImage(data: data) else { return nil }
        return image.size
    }
    
    func validateImage(_ data: Data) -> Bool {
        // Use enhanced security validation from ImageProcessor
        let imageProcessor = ImageProcessor()
        return imageProcessor.validateImage(data)
    }
    
    func sanitizeImage(_ image: UIImage) -> UIImage? {
        // Sanitize image to remove metadata
        let imageProcessor = ImageProcessor()
        return imageProcessor.sanitizeImage(image)
    }
    
    // MARK: - Offline Support
    
    func queueUpload(_ upload: QueuedUpload) async {
        // Add to offline queue
        // await supabaseService.queueOfflineUpload(upload) // TODO: Implement offline upload queue
    }
    
    func processOfflineQueue() async {
        // Process queued uploads when online
        // await supabaseService.processOfflineQueue() // TODO: Implement offline queue processing
    }
    
    func getOfflineQueue() async -> [QueuedUpload] {
        // return await supabaseService.getOfflineQueue() // TODO: Implement offline queue retrieval
        return []
    }
    
    func clearOfflineQueue() async {
        // await supabaseService.clearOfflineQueue() // TODO: Implement offline queue clearing
    }
    
    // MARK: - ServiceProtocol
    
    func reset() {
        isUploading = false
        uploadProgress = 0.0
        errorMessage = nil
    }
    
    func configureForTesting() {
        reset()
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var isUploadingArtwork: Bool {
        return isUploading
    }
    
    var uploadProgressPercentage: Int {
        return Int(uploadProgress * 100)
    }
}

// MARK: - Queued Upload

struct QueuedUpload: Codable, Identifiable {
    let id: UUID
    let childId: UUID
    let title: String?
    let description: String?
    let artworkType: ArtworkType
    let imageData: Data
    let createdAt: Date
    
    init(childId: UUID, title: String? = nil, description: String? = nil, artworkType: ArtworkType, imageData: Data) {
        self.id = UUID()
        self.childId = childId
        self.title = title
        self.description = description
        self.artworkType = artworkType
        self.imageData = imageData
        self.createdAt = Date()
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func resized(toFit size: CGSize) -> UIImage {
        let aspectRatio = self.size.width / self.size.height
        let targetAspectRatio = size.width / size.height
        
        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        return resized(to: newSize)
    }
    
    func resized(toFill size: CGSize) -> UIImage {
        let aspectRatio = self.size.width / self.size.height
        let targetAspectRatio = size.width / size.height
        
        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        }
        
        return resized(to: newSize)
    }
}
