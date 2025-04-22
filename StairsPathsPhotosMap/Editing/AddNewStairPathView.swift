//
//  AddNewStairPathView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

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
        GeometryReader { geometry in
            VStack() {
                // Title
                Text(stairPathInProgress.isEmpty ? "Start a New Path" : "Complete the Path")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                if !stairPathInProgress.isEmpty {
                    // Name Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.headline)
                        TextField("Enter name...", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                    }

                    // Type Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(.headline)
                        Picker("Type", selection: $type) {
                            ForEach(StairPathType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                    }

                    Button(action: {
                        modelContext.insert(StairPath(
                            name: name,
                            type: type,
                            startLatitude: stairPathInProgress[0].start.latitude,
                            startLongitude: stairPathInProgress[0].start.longitude,
                            endLatitude: latitude,
                            endLongitude: longitude
                        ))
                        modelContext.delete(stairPathInProgress[0])
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save: \(error)")
                        }
                        dismiss()
                    }) {
                        Label("End Stairway or Path", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(name.isEmpty)
                    .padding()
                } else {
                    // Action Button
                    Button(action: {
                        modelContext.insert(StairPathInProgress(start: MapLocation(latitude: latitude, longitude: longitude)))
                        dismiss()
                    }) {
                        Label("Start Stairway or Path", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .frame(height: geometry.size.height) // Ensure it fits within the available height
            .padding()
        }
    }
}

#Preview {
    AddNewStairPathView(latitude: 37.7749, longitude: -122.4194)
}
