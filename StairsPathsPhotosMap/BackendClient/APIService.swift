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

    /// Posts a new path and, on success, appends the server's version (with its real id
    /// and normalized pathData) to the local list. Returns whether it succeeded.
    @discardableResult
    func addStairPath(_ stairPath: StairPath) async -> Bool {
        guard let url = URL(string: "\(baseURL)/stairpaths") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(stairPath)
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response)
            // Prefer the server's representation so we pick up the real id; fall back to
            // the local object if the response can't be decoded.
            let created = (try? JSONDecoder().decode(StairPath.self, from: data)) ?? stairPath
            stairPaths.append(created)
            return true
        } catch {
            logger.error("Failed to add stairPath: \(error.localizedDescription)")
            errorMessage = "Couldn't save your path. Please try again."
            return false
        }
    }

    /// Uploads a single JPEG for a path and returns the URL to fetch it back, or nil on failure.
    func uploadPhoto(data: Data, for stairPathId: Int) async -> URL? {
        guard let url = URL(string: "\(baseURL)/stairpaths/\(stairPathId)/photos") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response)
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            if let photoId = json?["id"] as? String {
                return URL(string: "\(baseURL)/photos/\(photoId)")
            }
            return nil
        } catch {
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            errorMessage = "Couldn't upload a photo. Please try again."
            return nil
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
