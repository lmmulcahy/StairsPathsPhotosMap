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
        guard let url = URL(string: "http://ec2-18-204-202-106.compute-1.amazonaws.com:3000/stairpaths") else { return }
        
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
        guard let url = URL(string: "http://ec2-18-204-202-106.compute-1.amazonaws.com:3000/stairpaths") else { return }
        
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
}
