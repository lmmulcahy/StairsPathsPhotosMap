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
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Search...")
                }.padding()
            }
            .sheet(item: $selectedPath) { selectedPath in
                StairPathPhotosView(stairPath: selectedPath).presentationDetents([.fraction(0.5)])
            }
        }
    }
}

#Preview {
    PhotoMapView().modelContainer(StairPath.preview)
}
