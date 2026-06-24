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
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 6)
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
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(manager.nearbyAssets, id: \.localIdentifier) { asset in
                                let isSelected = selectedAssets.contains(asset)
                                AssetThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.accentColor, lineWidth: 3)
                                        }
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, isSelected ? Color.accentColor : Color.black.opacity(0.4))
                                            .shadow(radius: 2)
                                            .padding(6)
                                    }
                                    .onTapGesture {
                                        if isSelected {
                                            selectedAssets.remove(asset)
                                        } else {
                                            selectedAssets.insert(asset)
                                        }
                                    }
                                    .accessibilityLabel(isSelected ? "Selected photo" : "Photo")
                                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                        .padding(6)
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
