//
//  StartTab.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftUI

struct StartTab: View {
    var body: some View {
        TabView {
            Group {
                ContentView()
                    .tabItem {
                        Label("StairsPathsMap", systemImage: "map")
                    }
                StairPathsListView()
                    .tabItem {
                        Label("List", systemImage: "globe")
                    }
            }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
    }
}

#Preview {
    StartTab().modelContainer(StairPath.preview)
}
