//
//  StairPathEditing.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 6/6/26.
//

import SwiftData

/// The two-tap flow for creating a path: the first tap records a start point,
/// the second completes it. Kept out of the view so it can be unit tested.
@MainActor
enum StairPathEditing {
    static func startPath(at location: MapLocation, in context: ModelContext) {
        context.insert(StairPathInProgress(start: location))
    }

    @discardableResult
    static func completePath(
        name: String,
        type: StairPathType,
        endLatitude: Double,
        endLongitude: Double,
        from inProgress: StairPathInProgress,
        in context: ModelContext
    ) throws -> StairPath {
        let stairPath = StairPath(
            name: name,
            type: type,
            startLatitude: inProgress.start.latitude,
            startLongitude: inProgress.start.longitude,
            endLatitude: endLatitude,
            endLongitude: endLongitude
        )
        context.insert(stairPath)
        context.delete(inProgress)
        try context.save()
        return stairPath
    }
}
