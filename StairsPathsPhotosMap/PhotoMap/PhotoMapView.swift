//
//  PhotoMapView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftData
import SwiftUI

struct PhotoMapView: View {
    @State var selectedPathId: Int?
    @EnvironmentObject var apiService: APIService

    var body: some View {
        MapReader { proxy in
            Map(selection: $selectedPathId) {
                ForEach(apiService.stairPaths) { stairPath in
                    let stairPathFull = StairPathFull(stairPath: stairPath)
                    Group {
                        MapPolyline(coordinates: stairPathFull.coordinates)
                            .stroke(Color.accentColor, lineWidth: 4)
                        Marker(coordinate: stairPathFull.centerCoordinate) {
                            Label(stairPath.name, systemImage: "figure.stairs")
                        }
                    }
                    .tag(stairPath.id)
                }
            }
            .overlay {
                if apiService.stairPaths.isEmpty {
                    if apiService.isLoading {
                        ProgressView("Loading paths…")
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ContentUnavailableView(
                            "No Paths Yet",
                            systemImage: "figure.stairs",
                            description: Text("Stairways and paths will appear here once they're added.")
                        )
                    }
                }
            }
            .task {
                if apiService.stairPaths.isEmpty {
                    await apiService.fetchStairPaths()
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedPathId != nil },
                set: { if !$0 { selectedPathId = nil } }
            )) {
                if let id = selectedPathId, let path = apiService.stairPaths.first(where: { $0.id == id }) {
                    StairPathPhotosView(stairPathId: id, stairPath: path, stairPathFull: StairPathFull(stairPath: path))
                        .presentationDetents([.fraction(0.5), .large])
                }
            }
        }
    }
}

#Preview {
    PhotoMapView().environmentObject(APIService())
}
