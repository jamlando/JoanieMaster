import SwiftUI
import UIKit

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.capturedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.capturedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Photo Capture View

struct PhotoCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Capture Artwork")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Take a photo or select from your library")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Button("Cancel") {
                isPresented = false
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .sheet(isPresented: $showingCamera) {
            CameraView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $capturedImage, sourceType: .photoLibrary)
        }
        .onChange(of: capturedImage) { _ in
            if capturedImage != nil {
                isPresented = false
            }
        }
    }
}

// MARK: - Photo Preview View

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingCropView = false
    @State private var croppedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image Preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                
                // Image Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Size:")
                        Spacer()
                        Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    }
                    
                    HStack {
                        Text("File Size:")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(image.jpegData(compressionQuality: 0.8)?.count ?? 0), countStyle: .file))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingActionSheet = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retake")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // TODO: Implement crop functionality
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
                    
                    Button(action: {
                        isPresented = false
                    }) {
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
            .padding()
            .navigationTitle("Photo Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
            )
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
            // TODO: Implement crop view
            Text("Crop functionality coming soon")
        }
    }
}

// MARK: - Camera Permission Helper

class CameraPermissionManager: ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus()
    }
    
    func requestCameraPermission() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        return status
    }
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus()
        }
        return status == .authorized || status == .limited
    }
    
    var hasCameraPermission: Bool {
        return cameraPermissionStatus == .authorized
    }
    
    var hasPhotoLibraryPermission: Bool {
        return photoLibraryPermissionStatus == .authorized || photoLibraryPermissionStatus == .limited
    }
    
    var canUseCamera: Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera) && hasCameraPermission
    }
    
    var canUsePhotoLibrary: Bool {
        return UIImagePickerController.isSourceTypeAvailable(.photoLibrary) && hasPhotoLibraryPermission
    }
}

// MARK: - Permission Request View

struct PermissionRequestView: View {
    let permissionType: PermissionType
    let onGranted: () -> Void
    let onDenied: () -> Void
    
    enum PermissionType {
        case camera
        case photoLibrary
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: permissionType == .camera ? "camera.fill" : "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text(permissionType == .camera ? "Camera Access Required" : "Photo Library Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(permissionType == .camera ? 
                     "Joanie needs camera access to capture your child's artwork and creative works." :
                     "Joanie needs photo library access to save and organize your child's artwork.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        let granted = await requestPermission()
                        if granted {
                            onGranted()
                        } else {
                            onDenied()
                        }
                    }
                }) {
                    Text("Grant Permission")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: onDenied) {
                    Text("Not Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
    
    private func requestPermission() async -> Bool {
        switch permissionType {
        case .camera:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .photoLibrary:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return status == .authorized || status == .limited
        }
    }
}

// MARK: - Import Statements

import AVFoundation
import Photos
