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
    @StateObject private var apiService = APIService()
    
    private let locationManager = CLLocationManager()
    var body: some View {
        MapReader { proxy in
            Map(selection: $selectedPathId) {
                ForEach(apiService.stairPaths) { stairPath in
                    let stairPathFull = StairPathFull(stairPath: stairPath)
                    Group {
                        MapPolyline(coordinates: [stairPathFull.startCoordinate, stairPathFull.endCoordinate])
                            .stroke(.blue, lineWidth: 3)
                        Marker(coordinate: stairPathFull.centerCoordinate) {
                            Label(stairPath.name, systemImage: "star")}
                    }.tag(stairPath.id)
                }
            }
            .onAppear {
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Search...")
                }.padding()
            }
            .sheet(isPresented: Binding(
                get: { selectedPathId != nil },
                set: { if !$0 { selectedPathId = nil } }
            )) {
                if let id = selectedPathId, let path = apiService.stairPaths.first(where: { $0.id == id }) {
                    StairPathPhotosView(stairPathId: id, stairPath: path, stairPathFull: StairPathFull(stairPath: path))
                        .presentationDetents([.fraction(0.5)])
                }
            }
        }
    }
}

#Preview {
    PhotoMapView()
}
