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
    
    var coordinates: [CLLocationCoordinate2D] {
        if let pathDataStr = stairPath.pathData,
           let data = pathDataStr.data(using: .utf8),
           let points = try? JSONDecoder().decode([[Double]].self, from: data) {
            return points.compactMap {
                if $0.count >= 2 { return CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
                return nil
            }
        }
        return [startCoordinate, endCoordinate]
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        let coords = coordinates
        // For a multi-segment path, anchor the marker on the middle vertex. For a simple
        // two-point path, use the true geometric midpoint so the marker doesn't land on
        // the endpoint.
        if coords.count >= 3 {
            return coords[coords.count / 2]
        }
        let first = coords.first ?? startCoordinate
        let last = coords.last ?? endCoordinate
        return .init(latitude: (first.latitude + last.latitude) / 2, longitude: (first.longitude + last.longitude) / 2)
    }
}
