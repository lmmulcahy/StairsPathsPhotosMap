//
//  StairPathInProgress.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftData

@Model
class StairPathInProgress {
    var points: [MapLocation]
    
    init(points: [MapLocation] = []) {
        self.points = points
    }
}
