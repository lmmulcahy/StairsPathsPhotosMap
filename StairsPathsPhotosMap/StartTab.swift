//
//  StartTab.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftUI

enum MapType: String {
    case apple = "Apple"
    case google = "Google"
}

struct StartTab: View {
    @AppStorage("preferredMapType") private var preferredMapType: MapType = .apple

    var body: some View {
        TabView {
            Group {
                photoMap
                    .tabItem {
                        Label("StairsPathsMap", systemImage: "map")
                    }

                editMap
                    .tabItem {
                        Label("Edit Map", systemImage: "map")
                    }

                StairPathsListView()
                    .tabItem {
                        Label("List", systemImage: "globe")
                    }

                NavigationStack {
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

    private var activeMapType: MapType {
        if preferredMapType == .google {
            if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !apiKey.isEmpty {
                return .google
            } else {
                return .apple
            }
        }
        return .apple
    }

    @ViewBuilder private var photoMap: some View {
        switch activeMapType {
        case .apple: PhotoMapView()
        case .google: GooglePhotoMapViewContainer()
        }
    }

    @ViewBuilder private var editMap: some View {
        switch activeMapType {
        case .apple: MapEditView()
        case .google: GoogleMapEditViewContainer()
        }
    }
}

 #Preview {
     StartTab()
 }
