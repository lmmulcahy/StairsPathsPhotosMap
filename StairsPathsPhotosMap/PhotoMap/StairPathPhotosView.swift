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

    @State private var showingNearbyPicker = false

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
            if stairPathFull.photos.isEmpty {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle", description: Text("To get started, select some photos above"))
                    .frame(height: 300)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack {
                        ForEach(0..<stairPathFull.photos.count, id: \.self) { index in
                            let uiImage = UIImage(data: stairPathFull.photos[index])
                            if let uiImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                                    .padding(.horizontal, 20)
                                    .containerRelativeFrame(.horizontal)
                            }
                        }
                        
                    }
                }
                .frame(height: 300)
            }
        }
        .sheet(isPresented: $showingNearbyPicker) {
            NearbyPhotosPickerView(coordinate: stairPathFull.centerCoordinate) { photosData in
                Task {
                    for data in photosData {
                        if let downsized = Self.downsized(data) {
                            stairPathFull.photos.append(downsized)
                        }
                    }
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
