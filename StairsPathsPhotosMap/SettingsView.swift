//
//  SettingsView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 4/21/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredMapType") private var preferredMapType: MapType = .apple

    private var hasGoogleMapsAPIKey: Bool {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String, !apiKey.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            Section(header: Text("Map Preference"), footer: Text(hasGoogleMapsAPIKey ? "" : "Google Maps is currently unavailable because the API key is missing. The app will gracefully fall back to Apple Maps.")) {
                Picker("Preferred Map", selection: $preferredMapType) {
                    Text("Apple Maps").tag(MapType.apple)
                    Text("Google Maps").tag(MapType.google)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}