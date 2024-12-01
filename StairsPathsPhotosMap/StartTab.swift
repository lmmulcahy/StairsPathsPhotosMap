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
                PhotoMapView()
                    .tabItem {
                        Label("StairsPathsMap", systemImage: "map")
                    }
                MapEditView()
                    .tabItem {
                        Label("Edit Map", systemImage: "map")
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
