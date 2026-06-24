//
//  StairPath.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftUI

/// The wire model for a path. Note the asymmetry the backend imposes on `pathData`:
/// it is *returned* as a JSON string (e.g. `"[[37.7,-122.4],[37.71,-122.41]]"`) but must
/// be *sent* as a real JSON array, which the Worker then `JSON.stringify`s once for
/// storage. The custom `Codable` conformance below bridges that: we keep `pathData` as a
/// string in memory, decode tolerantly (string or array), and always encode it as an array.
class StairPath: Codable, Identifiable {
    var id: Int
    var name: String
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var pathData: String?

    init(id: Int, name: String, startLatitude: Double, startLongitude: Double, endLatitude: Double, endLongitude: Double, pathData: String? = nil) {
        self.id = id
        self.name = name
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.pathData = pathData
    }

    enum CodingKeys: String, CodingKey {
        case id, name, startLatitude, startLongitude, endLatitude, endLongitude, pathData
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        startLatitude = try c.decode(Double.self, forKey: .startLatitude)
        startLongitude = try c.decode(Double.self, forKey: .startLongitude)
        endLatitude = try c.decode(Double.self, forKey: .endLatitude)
        endLongitude = try c.decode(Double.self, forKey: .endLongitude)
        // The backend returns pathData as a string, but tolerate an array too and
        // normalize it to the string form we use everywhere else.
        if let s = try? c.decode(String.self, forKey: .pathData) {
            pathData = s
        } else if let arr = try? c.decode([[Double]].self, forKey: .pathData),
                  let data = try? JSONEncoder().encode(arr) {
            pathData = String(data: data, encoding: .utf8)
        } else {
            pathData = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(startLatitude, forKey: .startLatitude)
        try c.encode(startLongitude, forKey: .startLongitude)
        try c.encode(endLatitude, forKey: .endLatitude)
        try c.encode(endLongitude, forKey: .endLongitude)
        // Send pathData as a JSON array so the backend stringifies it exactly once.
        if let pathData, let data = pathData.data(using: .utf8),
           let arr = try? JSONDecoder().decode([[Double]].self, from: data) {
            try c.encode(arr, forKey: .pathData)
        } else {
            try c.encodeNil(forKey: .pathData)
        }
    }
}

enum StairPathType: String, Codable, CaseIterable {
    case stairs = "Stairs"
    case path = "Path"
}
