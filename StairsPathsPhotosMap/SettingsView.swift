//
//  SettingsView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 4/21/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredMapType") private var preferredMapType: String = "Apple"

    var body: some View {
        Form {
            Section(header: Text("Map Preference")) {
                Picker("Preferred Map", selection: $preferredMapType) {
                    Text("Apple Maps").tag("Apple")
                    Text("Google Maps").tag("Google")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}