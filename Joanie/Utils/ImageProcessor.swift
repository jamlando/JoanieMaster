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
                    logError("Image processing failed: \(error.localizedDescription)")
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
            hasAlpha: image.cgImage?.alphaInfo != CGImageAlphaInfo.none
        )
    }
    
    // MARK: - Image Validation
    
    func validateImage(_ data: Data) -> Bool {
        // Check if data is valid image
        guard UIImage(data: data) != nil else { return false }
        
        // Check file size
        guard data.count <= maxFileSize else { return false }
        
        // Check for malicious content patterns
        guard !containsMaliciousPatterns(data) else { return false }
        
        // Check image dimensions (prevent extremely large images)
        guard let image = UIImage(data: data) else { return false }
        let maxDimension = 4096
        guard image.size.width <= maxDimension && image.size.height <= maxDimension else { return false }
        
        return true
    }
    
    func validateImage(_ image: UIImage) -> Bool {
        // Check image dimensions
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return false }
        
        // Check if image is too large
        let maxDimension = max(size.width, size.height)
        guard maxDimension <= 10000 else { return false } // 10k pixels max
        
        // Check for suspicious metadata
        guard !hasSuspiciousMetadata(image) else { return false }
        
        return true
    }
    
    // MARK: - Security Functions
    
    private func containsMaliciousPatterns(_ data: Data) -> Bool {
        // Check for common malicious file signatures
        let maliciousSignatures: [[UInt8]] = [
            [0x4D, 0x5A], // PE executable
            [0x7F, 0x45, 0x4C, 0x46], // ELF executable
            [0xCA, 0xFE, 0xBA, 0xBE], // Mach-O executable
            [0xFE, 0xED, 0xFA, 0xCE], // Mach-O executable (reverse)
            [0xFE, 0xED, 0xFA, 0xCF], // Mach-O executable (reverse)
            [0xCE, 0xFA, 0xED, 0xFE], // Mach-O executable
            [0xCF, 0xFA, 0xED, 0xFE]  // Mach-O executable
        ]
        
        for signature in maliciousSignatures {
            if data.starts(with: signature) {
                logError("SECURITY: Malicious file signature detected")
                return true
            }
        }
        
        // Check for embedded scripts or executables
        let dataString = String(data: data.prefix(1024), encoding: .utf8) ?? ""
        let suspiciousPatterns = [
            "<script", "javascript:", "vbscript:", "onload=", "onerror=",
            "eval(", "document.cookie", "window.location", "alert(",
            "<?php", "<?=", "#!/bin/", "#!/usr/bin/"
        ]
        
        for pattern in suspiciousPatterns {
            if dataString.lowercased().contains(pattern.lowercased()) {
                logError("SECURITY: Suspicious pattern detected: \(pattern)")
                return true
            }
        }
        
        return false
    }
    
    private func hasSuspiciousMetadata(_ image: UIImage) -> Bool {
        // Check for suspicious metadata in image
        guard let cgImage = image.cgImage else { return false }
        
        // Check for extremely large images that might be used for DoS
        let pixelCount = cgImage.width * cgImage.height
        let maxPixels = 50_000_000 // 50 megapixels
        if pixelCount > maxPixels {
            logError("SECURITY: Image too large: \(pixelCount) pixels")
            return true
        }
        
        return false
    }
    
    func sanitizeImage(_ image: UIImage) -> UIImage? {
        // Remove all metadata and create a clean image
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
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
                logError("Image analysis failed: \(error.localizedDescription)")
                completion(ImageAnalysis())
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                completion(ImageAnalysis())
                return
            }
            
            let classifications = observations
                .filter { $0.confidence > 0.5 }
                .map { Classification(identifier: $0.identifier, confidence: Double($0.confidence)) }
            
            let analysis = ImageAnalysis(classifications: classifications)
            completion(analysis)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logError("Image analysis request failed: \(error.localizedDescription)")
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
