import Photos
import CoreLocation
import UIKit

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var nearbyAssets: [PHAsset] = []
    @Published var isFetching = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    func requestAuthorizationAndFetch(near coordinate: CLLocationCoordinate2D, radiusMeters: Double = 150) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        
        guard status == .authorized || status == .limited else {
            return
        }
        
        self.isFetching = true
        self.nearbyAssets = []
        
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let foundAssets = await Task.detached(priority: .userInitiated) { () -> [PHAsset] in
            var matching: [PHAsset] = []
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            allAssets.enumerateObjects { (asset, index, stop) in
                if let location = asset.location {
                    let distance = location.distance(from: targetLocation)
                    if distance <= radiusMeters {
                        matching.append(asset)
                    }
                }
            }
            return matching
        }.value
        
        self.nearbyAssets = foundAssets
        self.isFetching = false
    }
    
    static func fetchImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
