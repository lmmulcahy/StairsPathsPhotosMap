import SwiftUI
import Photos
import CoreLocation

struct NearbyPhotosPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = PhotoLibraryManager()
    
    var coordinate: CLLocationCoordinate2D
    var onPhotosSelected: ([Data]) -> Void
    
    @State private var selectedAssets: Set<PHAsset> = []
    @State private var isSaving = false
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if manager.authorizationStatus == .notDetermined {
                    ProgressView()
                } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                    ContentUnavailableView("Access Denied", systemImage: "photo.badge.exclamationmark", description: Text("Please enable photo access in Settings to automatically find nearby photos."))
                } else if manager.isFetching {
                    ProgressView("Finding nearby photos...")
                } else if manager.nearbyAssets.isEmpty {
                    ContentUnavailableView("No Nearby Photos", systemImage: "photo.on.rectangle", description: Text("We couldn't find any photos taken near this location."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(manager.nearbyAssets, id: \.localIdentifier) { asset in
                                AssetThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .overlay(
                                        ZStack {
                                            if selectedAssets.contains(asset) {
                                                Color.black.opacity(0.3)
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title)
                                                    .foregroundColor(.blue)
                                                    .padding(4)
                                            } else {
                                                Image(systemName: "circle")
                                                    .font(.title)
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .padding(4)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                    )
                                    .onTapGesture {
                                        if selectedAssets.contains(asset) {
                                            selectedAssets.remove(asset)
                                        } else {
                                            selectedAssets.insert(asset)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nearby Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Add (\(selectedAssets.count))") {
                            saveSelectedPhotos()
                        }
                        .disabled(selectedAssets.isEmpty)
                    }
                }
            }
            .task {
                await manager.requestAuthorizationAndFetch(near: coordinate)
            }
        }
    }
    
    private func saveSelectedPhotos() {
        isSaving = true
        Task {
            var dataArray: [Data] = []
            for asset in selectedAssets {
                if let data = await PhotoLibraryManager.fetchImageData(for: asset) {
                    dataArray.append(data)
                }
            }
            await MainActor.run {
                onPhotosSelected(dataArray)
                dismiss()
            }
        }
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .onAppear {
                let size = CGSize(width: geometry.size.width * 2, height: geometry.size.height * 2)
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .opportunistic
                
                PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
                    if let result = result {
                        self.image = result
                    }
                }
            }
        }
    }
}
