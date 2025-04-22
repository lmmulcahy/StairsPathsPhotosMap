//
//  StartTab.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftUI

struct StartTab: View {
    @AppStorage("preferredMapType") private var preferredMapType: String = "Apple"

    var body: some View {
        TabView {
            Group {
                // Main map view
                if preferredMapType == "Apple" {
                    PhotoMapView()
                        .tabItem {
                            Label("StairsPathsMap", systemImage: "map")
                        }
                } else {
                    GooglePhotoMapViewContainer()
                        .tabItem {
                            Label("StairsPathsMap", systemImage: "map")
                        }
                }

                // Editing map view
                if preferredMapType == "Apple" {
                    MapEditView()
                        .tabItem {
                            Label("Edit Map", systemImage: "map")
                        }
                } else {
                    GoogleMapEditViewContainer()
                        .tabItem {
                            Label("Edit Map", systemImage: "map")
                        }
                }

                // List view
                StairPathsListView()
                    .tabItem {
                        Label("List", systemImage: "globe")
                    }

                // Settings view
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
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
