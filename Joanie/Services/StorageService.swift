import Foundation
// import Supabase // TODO: Add Supabase dependency
import Combine
import UIKit

// MARK: - Network Connectivity Notification

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}

@MainActor
class StorageService: ObservableObject, ServiceProtocol {
    // MARK: - Published Properties
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var currentUpload: UploadTask?
    @Published var uploadQueue: [QueuedUpload] = []
    @Published var completedUploads: [UploadTask] = []
    @Published var failedUploads: [UploadTask] = []
    
    // MARK: - Dependencies
    private let supabaseService: SupabaseService
    private let imageProcessor: ImageProcessor
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
        self.imageProcessor = ImageProcessor()
        setupBindings()
        setupNetworkMonitoring()
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
        _ image: UIImage,
        for childId: UUID,
        title: String? = nil,
        description: String? = nil,
        artworkType: ArtworkType
    ) async throws -> ArtworkUpload {
        // Create upload task
        let uploadTask = UploadTask(
            id: UUID(),
            childId: childId,
            title: title,
            description: description,
            artworkType: artworkType,
            image: image,
            status: .preparing
        )
        
        currentUpload = uploadTask
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            // Step 1: Process image
            uploadTask.status = .processing
            uploadProgress = 0.1
            
            let optimizedImage = try await processImageForUpload(image)
            uploadProgress = 0.3
            
            // Step 2: Upload to storage
            uploadTask.status = .uploading
            let artworkUpload = ArtworkUpload(
                id: uploadTask.id,
                childId: uploadTask.childId,
                userId: UUID(), // TODO: Get actual user ID
                title: uploadTask.title,
                description: uploadTask.description,
                artworkType: uploadTask.artworkType,
                imageURL: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            let artwork = try await supabaseService.uploadArtwork(
                artworkUpload,
                imageData: optimizedImage.compressed
            ) { progress in
                self.uploadProgress = 0.3 + (progress * 0.7)
            }
            
            // Step 3: Complete
            uploadTask.status = UploadStatus.completed
            uploadTask.artwork = artwork
            uploadProgress = 1.0
            
            isUploading = false
            completedUploads.append(uploadTask)
            currentUpload = nil
            
            return artwork
            
        } catch {
                uploadTask.status = UploadStatus.failed
            uploadTask.error = error
            uploadProgress = 0.0
            errorMessage = error.localizedDescription
            
            isUploading = false
            failedUploads.append(uploadTask)
            currentUpload = nil
            
            throw error
        }
    }
    
    func uploadArtworkWithProgress(
        _ image: UIImage,
        for childId: UUID,
        title: String? = nil,
        description: String? = nil,
        artworkType: ArtworkType,
        progress: @escaping (Double) -> Void
    ) async throws -> ArtworkUpload {
        // Create upload task
        let uploadTask = UploadTask(
            id: UUID(),
            childId: childId,
            title: title,
            description: description,
            artworkType: artworkType,
            image: image,
            status: .preparing
        )
        
        currentUpload = uploadTask
        isUploading = true
        errorMessage = nil
        
        do {
            // Step 1: Process image with progress
            uploadTask.status = .processing
            progress(0.1)
            
            let optimizedImage = try await processImageForUploadWithProgress(image) { processingProgress in
                progress(0.1 + (processingProgress * 0.2))
            }
            progress(0.3)
            
            // Step 2: Upload to storage with progress
            uploadTask.status = .uploading
            let artworkUpload = ArtworkUpload(
                id: uploadTask.id,
                childId: uploadTask.childId,
                userId: UUID(), // TODO: Get actual user ID
                title: uploadTask.title,
                description: uploadTask.description,
                artworkType: uploadTask.artworkType,
                imageURL: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            let artwork = try await supabaseService.uploadArtworkWithProgress(
                artworkUpload,
                imageData: optimizedImage.compressed
            ) { uploadProgress in
                progress(0.3 + (uploadProgress * 0.7))
            }
            
            // Step 3: Complete
            uploadTask.status = UploadStatus.completed
            uploadTask.artwork = artwork
            progress(1.0)
            
            isUploading = false
            completedUploads.append(uploadTask)
            currentUpload = nil
            
            return artwork
            
        } catch {
                uploadTask.status = UploadStatus.failed
            uploadTask.error = error
            errorMessage = error.localizedDescription
            
            isUploading = false
            failedUploads.append(uploadTask)
            currentUpload = nil
            
            throw error
        }
    }
    
    private func processImageForUpload(_ image: UIImage) async throws -> OptimizedImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.imageProcessor.processImage(image) { processedImage in
                if let optimized = self.imageProcessor.optimizeImageForUpload(processedImage.processedImage) {
                    continuation.resume(returning: optimized)
                } else {
                    continuation.resume(throwing: ImageProcessingError.compressionFailed)
                }
            }
        }
    }
    
    private func processImageForUploadWithProgress(_ image: UIImage, progress: @escaping (Double) -> Void) async throws -> OptimizedImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.imageProcessor.processImage(image) { processedImage in
                progress(0.5)
                
                if let optimized = self.imageProcessor.optimizeImageForUpload(processedImage.processedImage) {
                    progress(1.0)
                    continuation.resume(returning: optimized)
                } else {
                    continuation.resume(throwing: ImageProcessingError.compressionFailed)
                }
            }
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
        uploadQueue.append(upload)
        
        // Save to persistent storage
        await saveOfflineQueue()
    }
    
    func processOfflineQueue() async {
        guard !uploadQueue.isEmpty else { return }
        
        let queueCopy = uploadQueue
        uploadQueue.removeAll()
        
        for queuedUpload in queueCopy {
            do {
                // Convert QueuedUpload to UploadTask
                guard let image = UIImage(data: queuedUpload.imageData) else { continue }
                
                let uploadTask = UploadTask(
                    childId: queuedUpload.childId,
                    title: queuedUpload.title,
                    description: queuedUpload.description,
                    artworkType: queuedUpload.artworkType,
                    image: image,
                    status: .queued
                )
                
                // Attempt upload
                uploadTask.status = UploadStatus.uploading
                let artworkUpload = ArtworkUpload(
                    id: uploadTask.id,
                    childId: queuedUpload.childId,
                    userId: UUID(), // TODO: Get actual user ID
                    title: queuedUpload.title,
                    description: queuedUpload.description,
                    artworkType: queuedUpload.artworkType,
                    imageURL: "",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let artwork = try await supabaseService.uploadArtwork(
                    artworkUpload,
                    imageData: queuedUpload.imageData
                ) { _ in }
                
                uploadTask.status = UploadStatus.completed
                uploadTask.artwork = artwork
                completedUploads.append(uploadTask)
                
            } catch {
                // Re-queue failed upload
                uploadQueue.append(queuedUpload)
                
                let uploadTask = UploadTask(
                    childId: queuedUpload.childId,
                    title: queuedUpload.title,
                    description: queuedUpload.description,
                    artworkType: queuedUpload.artworkType,
                    image: UIImage(data: queuedUpload.imageData) ?? UIImage(),
                    status: UploadStatus.failed
                )
                uploadTask.error = error
                failedUploads.append(uploadTask)
            }
        }
        
        // Save updated queue
        await saveOfflineQueue()
    }
    
    func getOfflineQueue() async -> [QueuedUpload] {
        return uploadQueue
    }
    
    func clearOfflineQueue() async {
        uploadQueue.removeAll()
        await saveOfflineQueue()
    }
    
    func retryFailedUpload(_ uploadTask: UploadTask) async {
        guard let index = failedUploads.firstIndex(where: { $0.id == uploadTask.id }) else { return }
        
        failedUploads.remove(at: index)
        uploadTask.status = UploadStatus.retrying
        
        do {
            let artworkUpload = ArtworkUpload(
                id: uploadTask.id,
                childId: uploadTask.childId,
                userId: UUID(), // TODO: Get actual user ID
                title: uploadTask.title,
                description: uploadTask.description,
                artworkType: uploadTask.artworkType,
                imageURL: "",
                createdAt: Date(),
                updatedAt: Date()
            )
            let artwork = try await supabaseService.uploadArtwork(
                artworkUpload,
                imageData: uploadTask.image.jpegData(compressionQuality: 0.8) ?? Data()
            ) { _ in }
            
            uploadTask.status = UploadStatus.completed
            uploadTask.artwork = artwork
            completedUploads.append(uploadTask)
            
        } catch {
                uploadTask.status = UploadStatus.failed
            uploadTask.error = error
            failedUploads.append(uploadTask)
        }
    }
    
    func removeFailedUpload(_ uploadTask: UploadTask) {
        failedUploads.removeAll { $0.id == uploadTask.id }
    }
    
    private func saveOfflineQueue() async {
        // Save to UserDefaults for persistence
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(uploadQueue) {
            UserDefaults.standard.set(data, forKey: "offline_upload_queue")
        }
    }
    
    private func loadOfflineQueue() async {
        // Load from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "offline_upload_queue") else { return }
        
        let decoder = JSONDecoder()
        if let queue = try? decoder.decode([QueuedUpload].self, from: data) {
            uploadQueue = queue
        }
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity changes
        NotificationCenter.default.addObserver(
            forName: .networkConnectivityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleNetworkConnectivityChange()
            }
        }
        
        // Load offline queue on initialization
        Task {
            await loadOfflineQueue()
        }
    }
    
    private func handleNetworkConnectivityChange() async {
        // Check if we're online and have queued uploads
        if isNetworkAvailable() && !uploadQueue.isEmpty {
            await processOfflineQueue()
        }
    }
    
    private func isNetworkAvailable() -> Bool {
        // Simple network availability check
        // In a real implementation, you'd use Network framework or similar
        return true // Mock implementation
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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

// MARK: - Upload Task

class UploadTask: ObservableObject, Identifiable {
    let id: UUID
    let childId: UUID
    let title: String?
    let description: String?
    let artworkType: ArtworkType
    let image: UIImage
    let createdAt: Date
    
    @Published var status: UploadStatus
    @Published var progress: Double = 0.0
    @Published var error: Error?
    @Published var artwork: ArtworkUpload?
    
    init(id: UUID = UUID(), childId: UUID, title: String? = nil, description: String? = nil, artworkType: ArtworkType, image: UIImage, status: UploadStatus = .preparing) {
        self.id = id
        self.childId = childId
        self.title = title
        self.description = description
        self.artworkType = artworkType
        self.image = image
        self.status = status
        self.createdAt = Date()
    }
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isFailed: Bool {
        return status == .failed
    }
    
    var isInProgress: Bool {
        return status == .preparing || status == .processing || status == .uploading
    }
    
    var statusDescription: String {
        switch status {
        case .preparing:
            return "Preparing..."
        case .processing:
            return "Processing image..."
        case .uploading:
            return "Uploading..."
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .queued:
            return "Queued"
        case .retrying:
            return "Retrying..."
        }
    }
}

enum UploadStatus: String, CaseIterable {
    case preparing = "preparing"
    case processing = "processing"
    case uploading = "uploading"
    case completed = "completed"
    case failed = "failed"
    case queued = "queued"
    case retrying = "retrying"
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
