//
//  StairPath.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftData

@Model
class StairPath {
    var name: String
    var type: StairPathType
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    
    init (name: String, type: StairPathType, startLatitude: Double, startLongitude: Double, endLatitude: Double, endLongitude: Double) {
        self.name = name
        self.type = type
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
    }
    
    var startCoordinate: CLLocationCoordinate2D {
        .init(latitude: startLatitude, longitude: startLongitude)
    }
    
    var endCoordinate: CLLocationCoordinate2D {
        .init(latitude: endLatitude, longitude: endLongitude)
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        .init(latitude: (startLatitude + endLatitude) / 2, longitude: (startLongitude + endLongitude) / 2)
    }
}

enum StairPathType: String, Codable, CaseIterable {
    case stairs = "Stairs"
    case path = "Path"
}

extension StairPath {
    @MainActor static var preview: ModelContainer {
        let container = try! ModelContainer(
            for: StairPath.self, StairPathInProgress.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
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
