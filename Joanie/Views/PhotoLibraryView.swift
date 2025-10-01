import SwiftUI
import Photos
import PhotosUI

// MARK: - Photo Library View

struct PhotoLibraryView: View {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    @State private var showingPermissionAlert = false
    @State private var permissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedAssets: [PHAsset] = []
    @State private var allPhotos: [PHAsset] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if permissionStatus == .authorized || permissionStatus == .limited {
                    PhotoGridView(
                        allPhotos: allPhotos,
                        selectedAssets: $selectedAssets,
                        onSelectionChanged: { assets in
                            loadImages(from: assets)
                        }
                    )
                } else if permissionStatus == .denied || permissionStatus == .restricted {
                    PermissionDeniedView {
                        showingPermissionAlert = true
                    }
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    isPresented = false
                }
                .disabled(selectedImages.isEmpty)
            )
        }
        .onAppear {
            checkPermission()
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo library access in Settings to select photos.")
        }
    }
    
    private func checkPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus()
        
        if permissionStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    permissionStatus = status
                    if status == .authorized || status == .limited {
                        loadPhotos()
                    }
                }
            }
        } else if permissionStatus == .authorized || permissionStatus == .limited {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1000 // Limit for performance
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var photoAssets: [PHAsset] = []
        
        assets.enumerateObjects { asset, _, _ in
            photoAssets.append(asset)
        }
        
        DispatchQueue.main.async {
            allPhotos = photoAssets
            isLoading = false
        }
    }
    
    private func loadImages(from assets: [PHAsset]) {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        
        var loadedImages: [UIImage] = []
        let group = DispatchGroup()
        
        for asset in assets {
            group.enter()
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                if let image = image {
                    loadedImages.append(image)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            selectedImages = loadedImages
        }
    }
}

// MARK: - Photo Grid View

struct PhotoGridView: View {
    let allPhotos: [PHAsset]
    @Binding var selectedAssets: [PHAsset]
    let onSelectionChanged: ([PHAsset]) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(allPhotos, id: \.localIdentifier) { asset in
                    PhotoThumbnailView(
                        asset: asset,
                        isSelected: selectedAssets.contains(asset)
                    ) {
                        toggleSelection(for: asset)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private func toggleSelection(for asset: PHAsset) {
        if selectedAssets.contains(asset) {
            selectedAssets.removeAll { $0.localIdentifier == asset.localIdentifier }
        } else {
            selectedAssets.append(asset)
        }
        onSelectionChanged(selectedAssets)
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
            
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            // Selection overlay
            if isSelected {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: requestOptions
        ) { image, _ in
            DispatchQueue.main.async {
                thumbnail = image
            }
        }
    }
}

// MARK: - Permission Denied View

struct PermissionDeniedView: View {
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Text("Photo Library Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Joanie needs access to your photo library to select and organize your child's artwork.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onRequestPermission) {
                Text("Open Settings")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading photos...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Multi-Photo Picker (iOS 14+)

@available(iOS 14.0, *)
struct MultiPhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 10 // Allow up to 10 photos
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiPhotoPicker
        
        init(_ parent: MultiPhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard !results.isEmpty else { return }
            
            var loadedImages: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage {
                            loadedImages.append(image)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.parent.selectedImages = loadedImages
            }
        }
    }
}

// MARK: - Photo Library Helper

class PhotoLibraryHelper: ObservableObject {
    @Published var permissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus()
        isAuthorized = permissionStatus == .authorized || permissionStatus == .limited
    }
    
    func requestPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        await MainActor.run {
            permissionStatus = status
            isAuthorized = status == .authorized || status == .limited
        }
        
        return isAuthorized
    }
    
    func getRecentPhotos(limit: Int = 50) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var photoAssets: [PHAsset] = []
        
        assets.enumerateObjects { asset, _, _ in
            photoAssets.append(asset)
        }
        
        return photoAssets
    }
    
    func loadImage(from asset: PHAsset, targetSize: CGSize = CGSize(width: 1024, height: 1024)) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = false
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.resizeMode = .exact
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
