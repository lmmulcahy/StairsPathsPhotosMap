//
//  SettingsView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 4/21/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredMapType") private var preferredMapType: MapType = .apple

    var body: some View {
        Form {
            Section(header: Text("Map Preference")) {
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