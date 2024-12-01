//
//  ContentView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/29/24.
//

import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]

    @State private var selectedTap: MapLocation?
    @State var startedStairPath: MapLocation?
    
    var body: some View {
        MapReader { proxy in
            Map {
                ForEach(stairPaths) { stairPath in
                    MapPolyline(coordinates: [stairPath.startCoordinate, stairPath.endCoordinate])
                        .stroke(.blue, lineWidth: 3)
                    Annotation(stairPath.name, coordinate: stairPath.centerCoordinate, anchor: .bottom) {
                    }
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
                    selectedTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Search...")
                }.padding()
            }
            .sheet(item: $selectedTap) { selectedTap in
                TapView(latitude: selectedTap.latitude, longitude: selectedTap.longitude).presentationDetents([.height(250)]) }
        }
    }
}

#Preview {
    ContentView().modelContainer(StairPath.preview)
}
