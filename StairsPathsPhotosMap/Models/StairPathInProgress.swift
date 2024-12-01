//
//  StairPathInProgress.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftData

@Model
class StairPathInProgress {
    var start: MapLocation
    
    init(start: MapLocation) {
        self.start = start
    }
}

/*
 extension StairPathInProgress {
 @MainActor static var preview: ModelContainer {
 let container = try! ModelContainer(
 for: StairPathInProgress.self .self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
 
 let inProgress: StairPathInProgress = .init(name: "blahhh!!!!", start: MapLocation(latitude: 37.785, longitude: -122.427), end: MapLocation(latitude: 37.121, longitude: -122.327))
 container.mainContext.insert(inProgress)
 return container
 }
 }
 */
