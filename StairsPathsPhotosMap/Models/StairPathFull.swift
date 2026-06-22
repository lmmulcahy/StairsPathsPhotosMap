//
//  StairPathFull.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 12/8/24.
//

import MapKit
import SwiftUI

class StairPathFull: ObservableObject {
    var stairPath: StairPath
    @Published var photoUrls: [URL]
    
    init (stairPath: StairPath) {
        self.stairPath = stairPath
        self.photoUrls = []
    }
    
    var startCoordinate: CLLocationCoordinate2D {
        .init(latitude: stairPath.startLatitude, longitude: stairPath.startLongitude)
    }
    
    var endCoordinate: CLLocationCoordinate2D {
        .init(latitude: stairPath.endLatitude, longitude: stairPath.endLongitude)
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        .init(latitude: (stairPath.startLatitude + stairPath.endLatitude) / 2, longitude: (stairPath.startLongitude + stairPath.endLongitude) / 2)
    }
}

/*
#Preview {
    StairPath(name: "Pacheco Stairs", type: .stairs, startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0)
}
 */

/*
extension StairPath {
    @MainActor static var preview: ModelContainer {
        let container = try! ModelContainer(
            for: StairPath.self, StairPathInProgress.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true), ModelConfiguration(isStoredInMemoryOnly: true))
        
        let pachecoStairs: StairPath = .init(name: "Pacheco Stairs", type: .stairs, startLatitude: 37.746190, startLongitude: -122.462162, endLatitude: 37.746720, endLongitude: -122.462828)
        container.mainContext.insert(pachecoStairs)
        let filbertSteps: StairPath = .init(name: "Filbert St Steps", type: .stairs, startLatitude: 37.801889, startLongitude: -122.405264, endLatitude: 37.802134, endLongitude: -122.403372)
        container.mainContext.insert(filbertSteps)
        let moreSteps: StairPath = .init(name: "More St Steps", type: .stairs, startLatitude: 37.785889, startLongitude: -122.425264, endLatitude: 37.79134, endLongitude: -122.403372)
        container.mainContext.insert(moreSteps)
        /*
        let inProgress: StairPathInProgress = .init(name: "blahhh!!!!", start: MapLocation(latitude: 37.785, longitude: -122.427), end: MapLocation(latitude: 37.800, longitude: -122.427))
        container.mainContext.insert(inProgress)
         */
        return container
    }
}
 */
