//
//  StairsPathsPhotosMapApp.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/29/24.
//

import SwiftData
import SwiftUI

@main
struct StairsPathsPhotosMapApp: App {
    var container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: StairPathInProgress.self, StairPath.self/*, configurations: ModelConfiguration(isStoredInMemoryOnly: true), ModelConfiguration(isStoredInMemoryOnly: true)*/)
        } catch {
            fatalError("Couldn't set up SwiftData container")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            StartTab()
        }.modelContainer(container)
    }
}
