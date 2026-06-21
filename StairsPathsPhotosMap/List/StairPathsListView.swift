//
//  StairPathsListView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import Foundation
import SwiftUI
import SwiftData

struct StairPathsListView: View {
    @Query() private var stairPathInProgress: [StairPathInProgress]
    @StateObject private var apiService = APIService()

    var body: some View {
        VStack {
            List(apiService.stairPaths) { stairPath in
                HStack {
                    Text(stairPath.name)
                    Spacer()
                }
            }
            .refreshable {
                await apiService.fetchStairPaths()
            }
            .onAppear {
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            Text("Count: " + String(apiService.stairPaths.count))
            Text("isEmpty: " + String(apiService.stairPaths.isEmpty))
        }
    }
}

/*
 #Preview {
 StairPathsListView().modelContainer(StairPath.preview)
 }
 */
