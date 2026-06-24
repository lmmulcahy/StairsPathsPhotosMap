//
//  StairsPathsPhotosMapTests.swift
//  StairsPathsPhotosMapTests
//
//  Created by Luke Mulcahy on 11/29/24.
//

import Testing
import Foundation
import MapKit
import UIKit
@testable import StairsPathsPhotosMap

// Runs serially: the app test host renders MapKit, which is unstable under Swift
// Testing's default parallelism.
@Suite(.serialized)
@MainActor
struct StairsPathsPhotosMapTests {

    private func jpegData(width: Int, height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 1)!
    }

    // MARK: - pathData wire encoding

    /// Regression test: the backend expects pathData as a JSON array and stringifies it
    /// once. Sending it as a string would double-encode it, so our encoder must emit an
    /// array even though we hold pathData as a string in memory.
    @Test func pathDataEncodesAsArrayNotString() throws {
        let path = StairPath(
            id: 0, name: "Test",
            startLatitude: 1, startLongitude: 2,
            endLatitude: 3, endLongitude: 4,
            pathData: "[[1.0,2.0],[3.0,4.0]]")

        let data = try JSONEncoder().encode(path)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["pathData"] is [Any])
        let arr = try #require(json["pathData"] as? [[Double]])
        #expect(arr == [[1.0, 2.0], [3.0, 4.0]])
    }

    /// The backend returns pathData as a JSON *string*; decoding must keep it as a string.
    @Test func decodesServerPathDataString() throws {
        let payload = """
        {"id":7,"name":"Pacheco","startLatitude":37.74,"startLongitude":-122.46,"endLatitude":37.75,"endLongitude":-122.46,"pathData":"[[37.74,-122.46],[37.75,-122.46]]"}
        """.data(using: .utf8)!

        let path = try JSONDecoder().decode(StairPath.self, from: payload)
        #expect(path.id == 7)
        #expect(path.pathData == "[[37.74,-122.46],[37.75,-122.46]]")
    }

    @Test func decodesNullPathData() throws {
        let payload = """
        {"id":1,"name":"x","startLatitude":0,"startLongitude":0,"endLatitude":1,"endLongitude":1,"pathData":null}
        """.data(using: .utf8)!
        let path = try JSONDecoder().decode(StairPath.self, from: payload)
        #expect(path.pathData == nil)
    }

    // MARK: - Geometry

    @Test func centerCoordinateIsMidpointForStartEndOnlyPath() {
        let path = StairPath(
            id: 1, name: "x",
            startLatitude: 0, startLongitude: 0,
            endLatitude: 10, endLongitude: 20)
        let full = StairPathFull(stairPath: path)
        #expect(full.centerCoordinate.latitude == 5)
        #expect(full.centerCoordinate.longitude == 10)
        #expect(full.startCoordinate.latitude == 0)
        #expect(full.endCoordinate.longitude == 20)
    }

    @Test func coordinatesDecodeMultiSegmentPathData() {
        let path = StairPath(
            id: 1, name: "x",
            startLatitude: 0, startLongitude: 0,
            endLatitude: 9, endLongitude: 9,
            pathData: "[[0.0,0.0],[1.0,1.0],[2.0,2.0]]")
        let coords = StairPathFull(stairPath: path).coordinates
        #expect(coords.count == 3)
        #expect(coords[1].latitude == 1)
        #expect(coords[1].longitude == 1)
    }

    @Test func coordinatesFallBackToStartEndWhenPathDataMissing() {
        let path = StairPath(
            id: 1, name: "x",
            startLatitude: 3, startLongitude: 4,
            endLatitude: 5, endLongitude: 6)
        let coords = StairPathFull(stairPath: path).coordinates
        #expect(coords.count == 2)
        #expect(coords.first?.latitude == 3)
        #expect(coords.last?.longitude == 6)
    }

    // MARK: - Photo downsizing

    @Test func downsizingShrinksLargeImages() throws {
        let data = jpegData(width: 4000, height: 3000)
        let result = try #require(StairPathPhotosView.downsized(data, maxDimension: 1000))
        let image = try #require(UIImage(data: result))
        #expect(max(image.size.width, image.size.height) <= 1000)
        #expect(result.count < data.count)
    }

    @Test func downsizingDoesNotUpscaleSmallImages() throws {
        let data = jpegData(width: 200, height: 100)
        let result = try #require(StairPathPhotosView.downsized(data, maxDimension: 1000))
        let image = try #require(UIImage(data: result))
        #expect(max(image.size.width, image.size.height) <= 200)
    }
}
