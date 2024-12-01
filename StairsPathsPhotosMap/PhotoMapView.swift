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
    @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]

    @State private var selectedTap: MapLocation?
    @State var startedStairPath: MapLocation?
    @State var selectedPath: StairPath?
    var body: some View {
        MapReader { proxy in
            Map(selection: $selectedPath) {
                ForEach(stairPaths) { stairPath in
                    Group {
                        MapPolyline(coordinates: [stairPath.startCoordinate, stairPath.endCoordinate])
                            .stroke(.blue, lineWidth: 3)
                        Marker(coordinate: stairPath.centerCoordinate) {
                            Label(stairPath.name, systemImage: "star")}
                    }.tag(stairPath)
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
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Search...")
                }.padding()
            }
            .sheet(item: $selectedPath) { selectedPath in
                Text(selectedPath.name).presentationDetents([.height(250)])
            }
        }
    }
}

#Preview {
    PhotoMapView().modelContainer(StairPath.preview)
}
