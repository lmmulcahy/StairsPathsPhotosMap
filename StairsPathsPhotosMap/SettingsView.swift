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

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Picker("Preferred Map", selection: $preferredMapType) {
                    Text("Apple Maps").tag(MapType.apple)
                    Text("Google Maps").tag(MapType.google)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Map Preference")
            } footer: {
                if !hasGoogleMapsAPIKey {
                    Text("Google Maps is currently unavailable because no API key is configured. The app falls back to Apple Maps.")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Text("Discover and share photos of San Francisco's stairways and walking paths.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
