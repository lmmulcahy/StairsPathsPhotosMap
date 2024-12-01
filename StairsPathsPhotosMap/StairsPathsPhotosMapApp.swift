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
    var body: some Scene {
        WindowGroup {
            StartTab()
        }.modelContainer(for: [StairPath.self, StairPathInProgress.self])
    }
}
