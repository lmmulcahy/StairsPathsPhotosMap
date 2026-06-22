//
//  StairPathPhotosView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import PhotosUI
import SwiftUI

struct StairPathPhotosView: View {
    var stairPathId: Int
    var stairPath: StairPath
    @ObservedObject var stairPathFull: StairPathFull
    @EnvironmentObject var apiService: APIService

    @State private var showingNearbyPicker = false
    @State private var isUploading = false

    var body: some View {
        VStack {
            Text(stairPath.name)
                .font(.headline)
            
            Button {
                showingNearbyPicker = true
            } label: {
                Label("Add Nearby Photos", systemImage: "location.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 8)
            
            if isUploading {
                ProgressView("Uploading...")
                    .frame(height: 300)
            } else if stairPathFull.photoUrls.isEmpty {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle", description: Text("To get started, select some photos above"))
                    .frame(height: 300)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack {
                        ForEach(stairPathFull.photoUrls, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 250, height: 250)
                            }
                            .padding(.horizontal, 20)
                            .containerRelativeFrame(.horizontal)
                        }
                        
                    }
                }
                .frame(height: 300)
            }
        }
        .task {
            stairPathFull.photoUrls = await apiService.fetchPhotos(for: stairPathId)
        }
        .sheet(isPresented: $showingNearbyPicker) {
            NearbyPhotosPickerView(coordinate: stairPathFull.centerCoordinate) { photosData in
                isUploading = true
                Task {
                    for data in photosData {
                        if let downsized = Self.downsized(data),
                           let newUrl = await apiService.uploadPhoto(data: downsized, for: stairPathId) {
                            stairPathFull.photoUrls.append(newUrl)
                        }
                    }
                    isUploading = false
                }
            }
        }
    }

    /// Downscales and re-encodes picked photos so we don't persist full-resolution
    /// originals, which would bloat the store and memory.
    static func downsized(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
