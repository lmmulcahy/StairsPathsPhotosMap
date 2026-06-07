//
//  StairsPathsPhotosMapTests.swift
//  StairsPathsPhotosMapTests
//
//  Created by Luke Mulcahy on 11/29/24.
//

import Testing
import SwiftData
import MapKit
import UIKit
@testable import StairsPathsPhotosMap

// Runs serially: these share the app test host (which renders MapKit) and a
// SwiftData stack, which is unstable under Swift Testing's default parallelism.
@Suite(.serialized)
@MainActor
struct StairsPathsPhotosMapTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: StairPath.self, StairPathInProgress.self, MapLocation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

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

    // MARK: - Create-path flow

    @Test func completingPathCreatesStairPathAndRemovesDraft() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        StairPathEditing.startPath(at: MapLocation(latitude: 37.75, longitude: -122.45), in: context)
        let drafts = try context.fetch(FetchDescriptor<StairPathInProgress>())
        #expect(drafts.count == 1)

        let saved = try StairPathEditing.completePath(
            name: "Test Stairs",
            type: .stairs,
            endLatitude: 37.76,
            endLongitude: -122.46,
            from: drafts[0],
            in: context)

        #expect(saved.name == "Test Stairs")
        #expect(saved.type == .stairs)
        #expect(saved.startLatitude == 37.75)
        #expect(saved.startLongitude == -122.45)
        #expect(saved.endLatitude == 37.76)
        #expect(saved.endLongitude == -122.46)

        let paths = try context.fetch(FetchDescriptor<StairPath>())
        #expect(paths.count == 1)
        let remainingDrafts = try context.fetch(FetchDescriptor<StairPathInProgress>())
        #expect(remainingDrafts.isEmpty)
    }

    // MARK: - Model geometry

    @Test func centerCoordinateIsTheMidpoint() {
        let path = StairPath(
            name: "x", type: .path,
            startLatitude: 0, startLongitude: 0,
            endLatitude: 10, endLongitude: 20)
        #expect(path.centerCoordinate.latitude == 5)
        #expect(path.centerCoordinate.longitude == 10)
        #expect(path.startCoordinate.latitude == 0)
        #expect(path.endCoordinate.longitude == 20)
    }

    // MARK: - Photo picker dedup

    @Test func newlyAddedReturnsOnlyItemsNotAlreadySelected() {
        #expect(StairPathPhotosView.newlyAdded([1, 2, 3], notIn: [1, 2]) == [3])
        #expect(StairPathPhotosView.newlyAdded([1, 2], notIn: [1, 2]).isEmpty)
        #expect(StairPathPhotosView.newlyAdded([1, 2, 3, 4], notIn: [2]) == [1, 3, 4])
        #expect(StairPathPhotosView.newlyAdded([Int](), notIn: [1]).isEmpty)
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
