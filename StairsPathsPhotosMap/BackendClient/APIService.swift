//
//  APIService.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 12/8/24.
//

import Foundation

@MainActor
class APIService: ObservableObject {
    @Published var stairPaths: [StairPath] = []

    func fetchStairPaths() async {
        guard let url = URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/stairpaths") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print(data)
            let decodedStairPaths = try JSONDecoder().decode([StairPath].self, from: data)
            DispatchQueue.main.async {
                self.stairPaths = decodedStairPaths
            }
        } catch {
            print("Failed to fetch stairPaths: \(error)")
        }
    }
    func addStairPath(_ stairPath: StairPath) async {
        guard let url = URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/stairpaths") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let data = try JSONEncoder().encode(stairPath)
            request.httpBody = data
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.stairPaths.append(stairPath)
                }
            }
        } catch {
            print("Failed to add stairPath: \(error)")
        }
    }
    
    func uploadPhoto(data: Data, for stairPathId: Int) async -> URL? {
        guard let url = URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/stairpaths/\(stairPathId)/photos") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any]
                if let photoId = json?["id"] as? String {
                    return URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/photos/\(photoId)")
                }
            }
        } catch {
            print("Failed to upload photo: \(error)")
        }
        return nil
    }

    func fetchPhotos(for stairPathId: Int) async -> [URL] {
        guard let url = URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/stairpaths/\(stairPathId)/photos") else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let items = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                return items.compactMap { item in
                    if let id = item["id"] as? String {
                        return URL(string: "https://stairs-paths-api.luke-mulcahy.workers.dev/photos/\(id)")
                    }
                    return nil
                }
            }
        } catch {
            print("Failed to fetch photos: \(error)")
        }
        return []
    }
}
