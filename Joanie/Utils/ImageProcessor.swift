import Foundation
import UIKit
import CoreImage
import Vision

// MARK: - Image Processor

class ImageProcessor: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    
    // MARK: - Constants
    private let maxImageSize: CGSize = CGSize(width: 1920, height: 1920)
    private let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    private let compressionQuality: CGFloat = 0.8
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    
    // MARK: - Public Methods
    
    func processImage(_ image: UIImage, completion: @escaping (ProcessedImage) -> Void) {
        isProcessing = true
        processingProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let processedImage = try self.processImageSync(image)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingProgress = 1.0
                    completion(processedImage)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingProgress = 0.0
                    Logger.error("Image processing failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func processImageSync(_ image: UIImage) throws -> ProcessedImage {
        // Step 1: Resize image
        processingProgress = 0.2
        let resizedImage = resizeImage(image, to: maxImageSize)
        
        // Step 2: Compress image
        processingProgress = 0.4
        guard let compressedData = compressImage(resizedImage) else {
            throw ImageProcessingError.compressionFailed
        }
        
        // Step 3: Create thumbnail
        processingProgress = 0.6
        let thumbnail = createThumbnail(from: resizedImage)
        
        // Step 4: Extract metadata
        processingProgress = 0.8
        let metadata = extractMetadata(from: resizedImage)
        
        // Step 5: Create processed image
        processingProgress = 1.0
        return ProcessedImage(
            originalImage: image,
            processedImage: resizedImage,
            compressedData: compressedData,
            thumbnail: thumbnail,
            metadata: metadata
        )
    }
    
    // MARK: - Image Resizing
    
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func resizeImageToFit(_ image: UIImage, in size: CGSize) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func resizeImageToFill(_ image: UIImage, in size: CGSize) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - Image Compression
    
    func compressImage(_ image: UIImage, quality: CGFloat? = nil) -> Data? {
        let compressionQuality = quality ?? self.compressionQuality
        return image.jpegData(compressionQuality: compressionQuality)
    }
    
    func compressImageToSize(_ image: UIImage, targetSize: Int) -> Data? {
        var compressionQuality: CGFloat = 1.0
        var compressedData: Data?
        
        repeat {
            compressedData = image.jpegData(compressionQuality: compressionQuality)
            compressionQuality -= 0.1
        } while (compressedData?.count ?? 0) > targetSize && compressionQuality > 0.1
        
        return compressedData
    }
    
    // MARK: - Thumbnail Creation
    
    func createThumbnail(from image: UIImage, size: CGSize? = nil) -> UIImage? {
        let thumbnailSize = size ?? self.thumbnailSize
        return resizeImageToFit(image, in: thumbnailSize)
    }
    
    func createThumbnailData(from image: UIImage, size: CGSize? = nil) -> Data? {
        guard let thumbnail = createThumbnail(from: image, size: size) else { return nil }
        return compressImage(thumbnail, quality: 0.7)
    }
    
    // MARK: - Metadata Extraction
    
    func extractMetadata(from image: UIImage) -> ImageMetadata {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        return ImageMetadata(
            width: Int(size.width),
            height: Int(size.height),
            aspectRatio: aspectRatio,
            orientation: image.imageOrientation,
            hasAlpha: image.cgImage?.alphaInfo != .none
        )
    }
    
    // MARK: - Image Validation
    
    func validateImage(_ data: Data) -> Bool {
        // Check if data is valid image
        guard UIImage(data: data) != nil else { return false }
        
        // Check file size
        return data.count <= maxFileSize
    }
    
    func validateImage(_ image: UIImage) -> Bool {
        // Check image dimensions
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return false }
        
        // Check if image is too large
        let maxDimension = max(size.width, size.height)
        return maxDimension <= 10000 // 10k pixels max
    }
    
    // MARK: - Image Enhancement
    
    func enhanceImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply basic enhancements
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.1, forKey: kCIInputBrightnessKey) // Slight brightness increase
        filter?.setValue(1.05, forKey: kCIInputContrastKey) // Slight contrast increase
        filter?.setValue(1.02, forKey: kCIInputSaturationKey) // Slight saturation increase
        
        guard let outputImage = filter?.outputImage else { return image }
        
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return image
    }
    
    // MARK: - Image Analysis
    
    func analyzeImage(_ image: UIImage, completion: @escaping (ImageAnalysis) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ImageAnalysis())
            return
        }
        
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                Logger.error("Image analysis failed: \(error.localizedDescription)")
                completion(ImageAnalysis())
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                completion(ImageAnalysis())
                return
            }
            
            let classifications = observations
                .filter { $0.confidence > 0.5 }
                .map { Classification(identifier: $0.identifier, confidence: $0.confidence) }
            
            let analysis = ImageAnalysis(classifications: classifications)
            completion(analysis)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Logger.error("Image analysis request failed: \(error.localizedDescription)")
            completion(ImageAnalysis())
        }
    }
    
    // MARK: - Helper Methods
    
    func getFileSize(_ data: Data) -> Int {
        return data.count
    }
    
    func getFileSizeDisplay(_ data: Data) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
    
    func getImageDimensions(from data: Data) -> CGSize? {
        guard let image = UIImage(data: data) else { return nil }
        return image.size
    }
    
    func getImageDimensionsDisplay(from data: Data) -> String {
        guard let size = getImageDimensions(from: data) else { return "Unknown" }
        return "\(Int(size.width)) × \(Int(size.height))"
    }
}

// MARK: - Supporting Types

struct ProcessedImage {
    let originalImage: UIImage
    let processedImage: UIImage
    let compressedData: Data
    let thumbnail: UIImage?
    let metadata: ImageMetadata
    
    var fileSize: Int {
        return compressedData.count
    }
    
    var fileSizeDisplay: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var dimensions: CGSize {
        return processedImage.size
    }
    
    var dimensionsDisplay: String {
        return "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }
}

struct ImageMetadata {
    let width: Int
    let height: Int
    let aspectRatio: Double
    let orientation: UIImage.Orientation
    let hasAlpha: Bool
    
    var isLandscape: Bool {
        return width > height
    }
    
    var isPortrait: Bool {
        return height > width
    }
    
    var isSquare: Bool {
        return width == height
    }
}

struct ImageAnalysis {
    let classifications: [Classification]
    
    init(classifications: [Classification] = []) {
        self.classifications = classifications
    }
    
    var topClassification: Classification? {
        return classifications.first
    }
    
    var confidence: Double {
        return topClassification?.confidence ?? 0.0
    }
}

struct Classification {
    let identifier: String
    let confidence: Double
    
    var displayName: String {
        return identifier.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Image Processing Error

enum ImageProcessingError: LocalizedError {
    case compressionFailed
    case resizeFailed
    case thumbnailCreationFailed
    case metadataExtractionFailed
    case validationFailed
    case enhancementFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .resizeFailed:
            return "Failed to resize image"
        case .thumbnailCreationFailed:
            return "Failed to create thumbnail"
        case .metadataExtractionFailed:
            return "Failed to extract metadata"
        case .validationFailed:
            return "Image validation failed"
        case .enhancementFailed:
            return "Image enhancement failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .compressionFailed:
            return "Try with a different image or reduce quality"
        case .resizeFailed:
            return "Try with a different image"
        case .thumbnailCreationFailed:
            return "Try with a different image"
        case .metadataExtractionFailed:
            return "Try with a different image"
        case .validationFailed:
            return "Please use a valid image file"
        case .enhancementFailed:
            return "Try with a different image"
        }
    }
}
