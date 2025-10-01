import Foundation
import UIKit
import CoreImage
import Vision
import Photos
import ImageIO
import CoreLocation

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
    
    func compressImageAdvanced(_ image: UIImage, targetSize: Int, maxDimension: CGFloat = 1920) -> Data? {
        // Step 1: Resize if too large
        var processedImage = image
        let maxSize = max(image.size.width, image.size.height)
        if maxSize > maxDimension {
            let scale = maxDimension / maxSize
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            processedImage = resizeImage(image, to: newSize)
        }
        
        // Step 2: Try different compression strategies
        let strategies: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]
        
        for quality in strategies {
            if let data = processedImage.jpegData(compressionQuality: quality) {
                if data.count <= targetSize {
                    return data
                }
            }
        }
        
        // Step 3: If still too large, resize further
        var currentSize = processedImage.size
        while currentSize.width > 100 && currentSize.height > 100 {
            currentSize = CGSize(width: currentSize.width * 0.8, height: currentSize.height * 0.8)
            let resizedImage = resizeImage(processedImage, to: currentSize)
            
            if let data = resizedImage.jpegData(compressionQuality: 0.7) {
                if data.count <= targetSize {
                    return data
                }
            }
        }
        
        // Step 4: Return the smallest we can get
        return processedImage.jpegData(compressionQuality: 0.1)
    }
    
    func optimizeImageForUpload(_ image: UIImage) -> OptimizedImage? {
        // Create multiple versions for different use cases
        let originalData = image.jpegData(compressionQuality: 0.9)
        let compressedData = compressImageAdvanced(image, targetSize: 2 * 1024 * 1024) // 2MB max
        let thumbnailData = createThumbnailData(from: image, size: CGSize(width: 300, height: 300))
        
        guard let compressed = compressedData,
              let thumbnail = thumbnailData else {
            return nil
        }
        
        return OptimizedImage(
            original: originalData,
            compressed: compressed,
            thumbnail: thumbnail,
            metadata: extractMetadata(from: image)
        )
    }
    
    func compressImageWithProgress(_ image: UIImage, targetSize: Int, progress: @escaping (Double) -> Void) -> Data? {
        progress(0.1)
        
        // Step 1: Resize if needed
        var processedImage = image
        let maxSize = max(image.size.width, image.size.height)
        if maxSize > 1920 {
            let scale = 1920 / maxSize
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            processedImage = resizeImage(image, to: newSize)
        }
        
        progress(0.3)
        
        // Step 2: Try compression
        let qualities: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
        
        for (index, quality) in qualities.enumerated() {
            if let data = processedImage.jpegData(compressionQuality: quality) {
                progress(0.3 + (0.4 * Double(index) / Double(qualities.count)))
                
                if data.count <= targetSize {
                    progress(1.0)
                    return data
                }
            }
        }
        
        progress(0.8)
        
        // Step 3: Further resize if needed
        var currentSize = processedImage.size
        while currentSize.width > 100 && currentSize.height > 100 {
            currentSize = CGSize(width: currentSize.width * 0.8, height: currentSize.height * 0.8)
            let resizedImage = resizeImage(processedImage, to: currentSize)
            
            if let data = resizedImage.jpegData(compressionQuality: 0.5) {
                if data.count <= targetSize {
                    progress(1.0)
                    return data
                }
            }
        }
        
        progress(1.0)
        return processedImage.jpegData(compressionQuality: 0.1)
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
    
    func extractDetailedMetadata(from image: UIImage, imageData: Data? = nil) -> DetailedImageMetadata {
        let basicMetadata = extractMetadata(from: image)
        
        // Extract EXIF and other metadata
        var exifData: [String: Any] = [:]
        var gpsData: GPSData?
        var creationDate: Date?
        var cameraInfo: CameraInfo?
        
        if let data = imageData {
            let metadata = extractMetadataFromData(data)
            exifData = metadata.exifData
            gpsData = metadata.gpsData
            creationDate = metadata.creationDate
            cameraInfo = metadata.cameraInfo
        }
        
        return DetailedImageMetadata(
            basic: basicMetadata,
            exifData: exifData,
            gpsData: gpsData,
            creationDate: creationDate,
            cameraInfo: cameraInfo
        )
    }
    
    func extractMetadataFromData(_ data: Data) -> (exifData: [String: Any], gpsData: GPSData?, creationDate: Date?, cameraInfo: CameraInfo?) {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return ([:], nil, nil, nil)
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return ([:], nil, nil, nil)
        }
        
        // Extract EXIF data
        let exifData = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        
        // Extract GPS data
        let gpsData = extractGPSData(from: imageProperties)
        
        // Extract creation date
        let creationDate = extractCreationDate(from: imageProperties)
        
        // Extract camera info
        let cameraInfo = extractCameraInfo(from: exifData)
        
        return (exifData, gpsData, creationDate, cameraInfo)
    }
    
    private func extractGPSData(from properties: [String: Any]) -> GPSData? {
        guard let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        
        let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double
        let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double
        let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String
        let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String
        
        guard let lat = latitude, let lon = longitude else { return nil }
        
        // Convert to decimal degrees
        let finalLatitude = (latitudeRef == "S") ? -lat : lat
        let finalLongitude = (longitudeRef == "W") ? -lon : lon
        
        return GPSData(
            latitude: finalLatitude,
            longitude: finalLongitude,
            altitude: gpsDict[kCGImagePropertyGPSAltitude as String] as? Double,
            timestamp: gpsDict[kCGImagePropertyGPSTimeStamp as String] as? Date
        )
    }
    
    private func extractCreationDate(from properties: [String: Any]) -> Date? {
        // Try different date fields
        if let dateTime = properties[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            return parseEXIFDate(dateTime)
        }
        
        if let dateTime = properties[kCGImagePropertyExifDateTimeDigitized as String] as? String {
            return parseEXIFDate(dateTime)
        }
        
        if let dateTime = properties[kCGImagePropertyTIFFDateTime as String] as? String {
            return parseEXIFDate(dateTime)
        }
        
        return nil
    }
    
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
    
    private func extractCameraInfo(from exifData: [String: Any]) -> CameraInfo? {
        let make = exifData[kCGImagePropertyExifMake as String] as? String
        let model = exifData[kCGImagePropertyExifModel as String] as? String
        let software = exifData[kCGImagePropertyExifSoftware as String] as? String
        let lensModel = exifData[kCGImagePropertyExifLensModel as String] as? String
        
        guard make != nil || model != nil else { return nil }
        
        return CameraInfo(
            make: make,
            model: model,
            software: software,
            lensModel: lensModel
        )
    }
    
    func extractMetadataFromPHAsset(_ asset: PHAsset) -> DetailedImageMetadata {
        let basicMetadata = ImageMetadata(
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            aspectRatio: Double(asset.pixelWidth) / Double(asset.pixelHeight),
            orientation: .up, // PHAsset doesn't store orientation
            hasAlpha: false // Default assumption
        )
        
        let gpsData = GPSData(
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude,
            altitude: asset.location?.altitude,
            timestamp: asset.location?.timestamp
        )
        
        return DetailedImageMetadata(
            basic: basicMetadata,
            exifData: [:], // Would need to load image data to get EXIF
            gpsData: gpsData,
            creationDate: asset.creationDate,
            cameraInfo: nil // Would need to load image data to get camera info
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

struct OptimizedImage {
    let original: Data?
    let compressed: Data
    let thumbnail: Data
    let metadata: ImageMetadata
    
    var originalSize: Int {
        return original?.count ?? 0
    }
    
    var compressedSize: Int {
        return compressed.count
    }
    
    var thumbnailSize: Int {
        return thumbnail.count
    }
    
    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(compressedSize) / Double(originalSize)
    }
    
    var sizeReduction: Double {
        guard originalSize > 0 else { return 0 }
        return 1.0 - compressionRatio
    }
    
    var sizeReductionPercentage: Int {
        return Int(sizeReduction * 100)
    }
}

struct DetailedImageMetadata {
    let basic: ImageMetadata
    let exifData: [String: Any]
    let gpsData: GPSData?
    let creationDate: Date?
    let cameraInfo: CameraInfo?
    
    var hasLocation: Bool {
        return gpsData != nil
    }
    
    var hasCreationDate: Bool {
        return creationDate != nil
    }
    
    var hasCameraInfo: Bool {
        return cameraInfo != nil
    }
    
    var locationDescription: String? {
        guard let gps = gpsData else { return nil }
        return String(format: "%.6f, %.6f", gps.latitude, gps.longitude)
    }
    
    var formattedCreationDate: String? {
        guard let date = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var cameraDescription: String? {
        guard let camera = cameraInfo else { return nil }
        var components: [String] = []
        
        if let make = camera.make {
            components.append(make)
        }
        
        if let model = camera.model {
            components.append(model)
        }
        
        return components.isEmpty ? nil : components.joined(separator: " ")
    }
}

struct GPSData {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date?
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation? {
        guard let altitude = altitude else { return nil }
        return CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: timestamp ?? Date()
        )
    }
}

struct CameraInfo {
    let make: String?
    let model: String?
    let software: String?
    let lensModel: String?
    
    var fullDescription: String {
        var components: [String] = []
        
        if let make = make {
            components.append(make)
        }
        
        if let model = model {
            components.append(model)
        }
        
        if let lens = lensModel {
            components.append(lens)
        }
        
        return components.joined(separator: " ")
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
