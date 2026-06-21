//
//  MapEditView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftData
import SwiftUI

struct MapEditView: View {
    // @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]
    @StateObject private var apiService = APIService()

    @State private var selectedTap: MapLocation?
    @State var startedStairPath: MapLocation?
    @State var selectedPathId: Int?
    var body: some View {
        MapReader { proxy in
            Map(selection: $selectedPathId) {
                ForEach(apiService.stairPaths) { stairPath in
                    let stairPathFull = StairPathFull(stairPath: stairPath)
                    Group {
                        MapPolyline(coordinates: [stairPathFull.startCoordinate, stairPathFull.endCoordinate])
                            .stroke(.blue, lineWidth: 3)
                        Annotation(stairPath.name, coordinate: stairPathFull.centerCoordinate, anchor: .bottom) {
                            Circle().fill(.blue).frame(width: 8, height: 8)
                        }
                    }.tag(stairPath.id)
                }
                ForEach(stairPathInProgress) { stairPathInProgress in
                    Annotation("Start", coordinate: stairPathInProgress.start.coordinate, anchor: .bottom) {
                        Image(systemName: "mappin").foregroundStyle(.blue)
                    }
                }
                if let selectedTap {
                    let selectedCoordinate = CLLocationCoordinate2D(
                        latitude: selectedTap.latitude, longitude: selectedTap.longitude)
                    Annotation("", coordinate: selectedCoordinate, anchor: .bottom) {
                        Image(systemName: "mappin").foregroundStyle(.yellow)
                    }
                }
            }
            .overlay(alignment: .top) {
                Text(stairPathInProgress.isEmpty ? "Tap the map to set the start location" : "Tap the map to set the end location")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top)
            }
            .onAppear {
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    if selectedPathId == nil {
                        selectedTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    } else {
                        selectedTap = nil
                        selectedPathId = nil
                    }
                }
            }
            .sheet(item: $selectedTap) { selectedTap in
                if selectedPathId == nil {
                    AddNewStairPathView(apiService: apiService, latitude: selectedTap.latitude, longitude: selectedTap.longitude)
                        .presentationDetents([.height(250)])
                }
            }
        }
    }
}

#Preview {
    MapEditView()
}
