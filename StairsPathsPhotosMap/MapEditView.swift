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
                        Annotation(stairPath.name, coordinate: stairPath.centerCoordinate, anchor: .bottom) {}
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
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    if selectedPath == nil {
                        selectedTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    } else {
                        selectedTap = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Search...")
                }.padding()
            }
            .sheet(item: $selectedTap) { selectedTap in
                if selectedPath == nil {
                    TapView(latitude: selectedTap.latitude, longitude: selectedTap.longitude).presentationDetents([.height(250)]) }
            }
        }
    }
}

#Preview {
    MapEditView().modelContainer(StairPath.preview)
}
