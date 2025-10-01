import SwiftUI
import UIKit
import AVFoundation
import Photos

// MARK: - Photo Capture Flow View

struct PhotoCaptureFlowView: View {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    @State private var currentStep: CaptureStep = .permission
    @State private var permissionManager = CameraPermissionManager()
    @State private var showingPermissionAlert = false
    @State private var permissionType: PermissionType = .camera
    
    enum CaptureStep {
        case permission
        case capture
        case preview
        case processing
    }
    
    enum PermissionType {
        case camera
        case photoLibrary
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                switch currentStep {
                case .permission:
                    PermissionStepView(
                        permissionManager: permissionManager,
                        onPermissionGranted: {
                            currentStep = .capture
                        },
                        onPermissionDenied: {
                            showingPermissionAlert = true
                        }
                    )
                    
                case .capture:
                    CaptureStepView(
                        permissionManager: permissionManager,
                        onImageCaptured: { image in
                            capturedImage = image
                            currentStep = .preview
                        },
                        onBack: {
                            isPresented = false
                        }
                    )
                    
                case .preview:
                    if let image = capturedImage {
                        PreviewStepView(
                            image: image,
                            onRetake: {
                                currentStep = .capture
                            },
                            onUse: {
                                currentStep = .processing
                            },
                            onBack: {
                                currentStep = .capture
                            }
                        )
                    }
                    
                case .processing:
                    ProcessingStepView(
                        image: capturedImage,
                        onComplete: {
                            isPresented = false
                        },
                        onBack: {
                            currentStep = .preview
                        }
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Please enable camera and photo library access in Settings to capture artwork.")
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let permissionManager: CameraPermissionManager
    let onPermissionGranted: () -> Void
    let onPermissionDenied: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 16) {
                    Text("Camera & Photo Access")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Joanie needs access to your camera and photo library to capture and organize your child's artwork.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                if !permissionManager.hasCameraPermission || !permissionManager.hasPhotoLibraryPermission {
                    Button(action: {
                        Task {
                            let cameraGranted = await permissionManager.requestCameraPermission()
                            let photoGranted = await permissionManager.requestPhotoLibraryPermission()
                            
                            if cameraGranted && photoGranted {
                                onPermissionGranted()
                            } else {
                                onPermissionDenied()
                            }
                        }
                    }) {
                        Text("Grant Permissions")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: onPermissionGranted) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: onPermissionDenied) {
                    Text("Skip for Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Capture Step View

struct CaptureStepView: View {
    let permissionManager: CameraPermissionManager
    let onImageCaptured: (UIImage) -> Void
    let onBack: () -> Void
    
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Capture Artwork")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Capture Options
            VStack(spacing: 20) {
                Text("How would you like to capture your child's artwork?")
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    if permissionManager.canUseCamera {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Take Photo")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Use your device's camera")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                        }
                    }
                    
                    if permissionManager.canUsePhotoLibrary {
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Choose from Library")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Select from your photos")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Tips
            VStack(spacing: 12) {
                Text("💡 Tips for better photos:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(icon: "lightbulb", text: "Use good lighting")
                    TipRow(icon: "viewfinder", text: "Keep the artwork flat")
                    TipRow(icon: "crop", text: "Fill the frame with the artwork")
                    TipRow(icon: "hand.raised", text: "Hold the camera steady")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: .constant(nil))
                .onDisappear {
                    // Check if image was captured
                    if let image = capturedImage {
                        onImageCaptured(image)
                    }
                }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: .constant(nil), sourceType: .photoLibrary)
                .onDisappear {
                    // Check if image was selected
                    if let image = selectedImage {
                        onImageCaptured(image)
                    }
                }
        }
    }
    
    // These would be passed from parent or managed differently in a real implementation
    @State private var capturedImage: UIImage?
    @State private var selectedImage: UIImage?
}

// MARK: - Preview Step View

struct PreviewStepView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onUse: () -> Void
    let onBack: () -> Void
    
    @State private var showingCropView = false
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Image Preview
            ScrollView {
                VStack(spacing: 20) {
                    // Main Image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                        .padding(.horizontal)
                    
                    // Image Info
                    VStack(spacing: 12) {
                        HStack {
                            Text("Dimensions:")
                            Spacer()
                            Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("File Size:")
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(image.jpegData(compressionQuality: 0.8)?.count ?? 0), countStyle: .file))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Format:")
                            Spacer()
                            Text("JPEG")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingCropView = true
                        }) {
                            HStack {
                                Image(systemName: "crop")
                                Text("Crop & Edit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onUse) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Use This Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Retake Photo"),
                message: Text("Choose how you'd like to capture a new photo"),
                buttons: [
                    .default(Text("Camera")) {
                        showingCamera = true
                    },
                    .default(Text("Photo Library")) {
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: .constant(nil))
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: .constant(nil), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCropView) {
            CropView(image: image) { croppedImage in
                // Handle cropped image
                if let cropped = croppedImage {
                    // Update the image
                    // This would need to be handled by the parent view
                }
            }
        }
    }
}

// MARK: - Processing Step View

struct ProcessingStepView: View {
    let image: UIImage?
    let onComplete: () -> Void
    let onBack: () -> Void
    
    @State private var processingProgress: Double = 0.0
    @State private var processingStep: String = "Processing image..."
    @State private var isProcessingComplete = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                if isProcessingComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                } else {
                    ProgressView(value: processingProgress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(2.0)
                }
                
                VStack(spacing: 16) {
                    Text(isProcessingComplete ? "Processing Complete!" : "Processing Image")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(processingStep)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            if isProcessingComplete {
                Button(action: onComplete) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            startProcessing()
        }
    }
    
    private func startProcessing() {
        // Simulate processing steps
        let steps = [
            ("Validating image...", 0.2),
            ("Compressing image...", 0.4),
            ("Creating thumbnail...", 0.6),
            ("Extracting metadata...", 0.8),
            ("Finalizing...", 1.0)
        ]
        
        for (index, (step, progress)) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                processingStep = step
                processingProgress = progress
                
                if index == steps.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessingComplete = true
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Crop View (Placeholder)

struct CropView: View {
    let image: UIImage
    let onCropComplete: (UIImage?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Crop functionality coming soon")
                    .font(.title2)
                    .padding()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    onCropComplete(image)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
