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
