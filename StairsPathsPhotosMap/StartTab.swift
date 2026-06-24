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
    @EnvironmentObject var apiService: APIService

    var body: some View {
        TabView {
            Group {
                photoMap
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }

                editMap
                    .tabItem {
                        Label("Contribute", systemImage: "plus.circle")
                    }

                StairPathsListView()
                    .tabItem {
                        Label("Paths", systemImage: "list.bullet")
                    }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .toolbarBackground(.visible, for: .tabBar)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { apiService.errorMessage != nil },
                set: { if !$0 { apiService.errorMessage = nil } }
            ),
            presenting: apiService.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { apiService.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .alert(
            "Submitted for review",
            isPresented: Binding(
                get: { apiService.infoMessage != nil },
                set: { if !$0 { apiService.infoMessage = nil } }
            ),
            presenting: apiService.infoMessage
        ) { _ in
            Button("OK", role: .cancel) { apiService.infoMessage = nil }
        } message: { message in
            Text(message)
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
    StartTab().environmentObject(APIService())
}
