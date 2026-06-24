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
    @State private var isLoadingPhotos = true

    private let galleryHeight: CGFloat = 260
    private let photoCornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
            Text(stairPath.name)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button {
                showingNearbyPicker = true
            } label: {
                Label("Add Nearby Photos", systemImage: "location.magnifyingglass")
            }
            .buttonStyle(.bordered)

            photoContent
        }
        .padding(.top, 8)
        .task {
            isLoadingPhotos = true
            stairPathFull.photoUrls = await apiService.fetchPhotos(for: stairPathId)
            isLoadingPhotos = false
        }
        .sheet(isPresented: $showingNearbyPicker) {
            NearbyPhotosPickerView(coordinate: stairPathFull.centerCoordinate) { photosData in
                isUploading = true
                Task {
                    var submitted = 0
                    for data in photosData {
                        if let downsized = Self.downsized(data),
                           await apiService.uploadPhoto(data: downsized, for: stairPathId) {
                            submitted += 1
                        }
                    }
                    isUploading = false
                    // Uploaded photos are pending review, so they aren't shown in the
                    // gallery yet; confirm the submission instead.
                    if submitted > 0 {
                        apiService.infoMessage = submitted == 1
                            ? "Thanks! Your photo was submitted for review."
                            : "Thanks! Your \(submitted) photos were submitted for review."
                    }
                }
            }
        }
    }

    @ViewBuilder private var photoContent: some View {
        if isUploading {
            ProgressView("Uploading…")
                .frame(height: galleryHeight)
        } else if isLoadingPhotos {
            ProgressView()
                .frame(height: galleryHeight)
        } else if stairPathFull.photoUrls.isEmpty {
            ContentUnavailableView(
                "No Photos",
                systemImage: "photo.on.rectangle",
                description: Text("Tap “Add Nearby Photos” to add the first one.")
            )
            .frame(height: galleryHeight)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(stairPathFull.photoUrls, id: \.self) { url in
                        photo(for: url)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: galleryHeight)
            .padding(.horizontal, 8)
        }
    }

    private func photo(for url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ContentUnavailableView("Couldn't load photo", systemImage: "photo.badge.exclamationmark")
            @unknown default:
                Color.clear
            }
        }
        .frame(height: galleryHeight)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius))
        .accessibilityLabel("Photo of \(stairPath.name)")
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
