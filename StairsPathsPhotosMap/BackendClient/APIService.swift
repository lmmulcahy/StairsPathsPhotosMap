//
//  APIService.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 12/8/24.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lukemulcahy.StairsPathsPhotosMap", category: "APIService")

@MainActor
class APIService: ObservableObject {
    @Published var stairPaths: [StairPath] = []
    /// True while the path list is being (re)loaded from the backend.
    @Published var isLoading = false
    /// Set when a network operation fails; views can present this to the user and clear it.
    @Published var errorMessage: String?
    /// Set after a successful contribution (path or photo) so the UI can confirm that it
    /// was submitted for review rather than published immediately.
    @Published var infoMessage: String?

    private let baseURL = "https://stairs-paths-api.luke-mulcahy.workers.dev"

    func fetchStairPaths() async {
        guard let url = URL(string: "\(baseURL)/stairpaths") else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try Self.validate(response)
            stairPaths = try JSONDecoder().decode([StairPath].self, from: data)
        } catch {
            logger.error("Failed to fetch stairPaths: \(error.localizedDescription)")
            errorMessage = "Couldn't load paths. Please check your connection and try again."
        }
    }

    /// The JSON body for a new-path submission. pathData is sent as an array so the
    /// backend stringifies it exactly once.
    private struct PathSubmission: Encodable {
        let kind: String
        let name: String
        let startLatitude: Double
        let startLongitude: Double
        let endLatitude: Double
        let endLongitude: Double
        let pathData: [[Double]]
    }

    /// Submits a new path to the review queue. It is not added to the live list; it
    /// becomes visible only after an admin approves it. `points` are `[latitude, longitude]`
    /// pairs. Returns whether it succeeded.
    @discardableResult
    func submitNewPath(name: String, points: [[Double]]) async -> Bool {
        guard let url = URL(string: "\(baseURL)/submissions"),
              let start = points.first, start.count >= 2,
              let end = points.last, end.count >= 2 else { return false }

        let body = PathSubmission(
            kind: "create",
            name: name,
            startLatitude: start[0],
            startLongitude: start[1],
            endLatitude: end[0],
            endLongitude: end[1],
            pathData: points
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response)
            infoMessage = "Thanks! Your path was submitted for review."
            return true
        } catch {
            logger.error("Failed to submit path: \(error.localizedDescription)")
            errorMessage = "Couldn't submit your path. Please try again."
            return false
        }
    }

    /// Uploads a single JPEG for a path as a pending submission. Returns whether it
    /// succeeded; the photo is not shown until an admin approves it.
    @discardableResult
    func uploadPhoto(data: Data, for stairPathId: Int) async -> Bool {
        guard let url = URL(string: "\(baseURL)/stairpaths/\(stairPathId)/photos") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response)
            return true
        } catch {
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            errorMessage = "Couldn't upload a photo. Please try again."
            return false
        }
    }

    func fetchPhotos(for stairPathId: Int) async -> [URL] {
        guard let url = URL(string: "\(baseURL)/stairpaths/\(stairPathId)/photos") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try Self.validate(response)
            if let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return items.compactMap { item in
                    guard let id = item["id"] as? String else { return nil }
                    return URL(string: "\(baseURL)/photos/\(id)")
                }
            }
        } catch {
            logger.error("Failed to fetch photos: \(error.localizedDescription)")
        }
        return []
    }

    /// Throws if the response is not a 2xx HTTP status.
    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
