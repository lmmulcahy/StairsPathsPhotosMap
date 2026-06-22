//
//  StairPath.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftUI

class StairPath: Codable, Identifiable {
    var id: Int
    var name: String
    // var type: StairPathType
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var pathData: String?
    
    init (id: Int, name: String, startLatitude: Double, startLongitude: Double, endLatitude: Double, endLongitude: Double, pathData: String? = nil) {
        self.id = id
        self.name = name
        // self.type = type
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.pathData = pathData
    }
}

enum StairPathType: String, Codable, CaseIterable {
    case stairs = "Stairs"
    case path = "Path"
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
        return container
    }
}
 */
