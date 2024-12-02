//
//  AddNewStairPathView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftData
import SwiftUI

struct AddNewStairPathView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query() private var stairPathInProgress: [StairPathInProgress]

    var latitude: Double
    var longitude: Double
    
    @State private var name = ""
    @State private var type: StairPathType = .stairs

    var body: some View {
        VStack {
            Text("Lat: " + String(latitude))
            Text("Long: " + String(longitude))
            Spacer()
            if (stairPathInProgress.count > 0) {
                HStack {
                    Text("Name: ")
                    TextField("...", text: $name).padding()
                }
                Picker("Type: ", selection: $type) {
                    ForEach(StairPathType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Spacer()
                Button("End stairway or path", systemImage: "globe") {
                    modelContext.insert(StairPath(
                        name: name, type: type, startLatitude: stairPathInProgress[0].start.latitude,
                        startLongitude: stairPathInProgress[0].start.longitude, endLatitude: latitude, endLongitude: longitude))
                    modelContext.delete(stairPathInProgress[0])
                    do {
                        try modelContext.save()
                    } catch { }
                    dismiss()
                }.disabled(name.isEmpty)
            } else {
                Button() {
                    modelContext.insert(StairPathInProgress(start: MapLocation(latitude: latitude, longitude: longitude)))
                    dismiss()
                } label: { Label("Start stairway or path", systemImage: "globe") }
            }
        }
    }
}

#Preview {
    AddNewStairPathView(latitude: 10, longitude: 389)
}
