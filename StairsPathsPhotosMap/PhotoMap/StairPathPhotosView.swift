//
//  StairPathPhotosView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import PhotosUI
import SwiftUI

struct StairPathPhotosView: View {
    var stairPath: StairPath
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [Image] = []

    var body: some View {
        VStack {
            Text(stairPath.name)
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, selectionBehavior: .continuousAndOrdered, matching: .images) {
                Label("Add photos", systemImage: "photo")
            }
            if selectedImages.isEmpty {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle", description: Text("To get started, select some photos above"))
                    .frame(height: 300)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack {
                        ForEach(0..<selectedImages.count, id: \.self) { index in
                            selectedImages[index]
                                .resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                                .padding(.horizontal, 20)
                                .containerRelativeFrame(.horizontal)
                        }
                        
                    }
                }
                .frame(height: 300)
            }
        }
        .onChange(of: selectedItems) { oldItems, newItems in
            selectedImages.removeAll()
            newItems.forEach { newItem in
                Task {
                    if let image = try? await newItem.loadTransferable(type: Image.self) {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }
}

/*
 #Preview {
 StairPathPhotosView().modelContainer(StairPath.preview)
 }
 */
