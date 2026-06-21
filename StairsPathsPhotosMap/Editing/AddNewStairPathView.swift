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

    @ObservedObject var apiService: APIService
    var latitude: Double
    var longitude: Double

    @State private var name = ""
    @State private var type: StairPathType = .stairs

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text(stairPathInProgress.isEmpty ? "Start New Path" : "Complete Path")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label(String(format: "%.5f", latitude), systemImage: "arrow.left.and.right")
                    Label(String(format: "%.5f", longitude), systemImage: "arrow.up.and.down")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top)

            if !stairPathInProgress.isEmpty {
                VStack(spacing: 16) {
                    TextField("Name your path...", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Picker("Type", selection: $type) {
                        ForEach(StairPathType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        modelContext.delete(stairPathInProgress[0])
                        do { try modelContext.save() } catch { }
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)

                    Button {
                        let newPath = StairPath(
                            id: Int.random(in: 1...1000000), // temp id
                            name: name,
                            startLatitude: stairPathInProgress[0].start.latitude,
                            startLongitude: stairPathInProgress[0].start.longitude,
                            endLatitude: latitude,
                            endLongitude: longitude
                        )
                        
                        Task {
                            await apiService.addStairPath(newPath)
                        }
                        
                        modelContext.delete(stairPathInProgress[0])
                        do {
                            try modelContext.save()
                        } catch { }
                        dismiss()
                    } label: {
                        Label("Save Path", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.isEmpty)
                }
                .padding(.horizontal)
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        modelContext.insert(StairPathInProgress(start: MapLocation(latitude: latitude, longitude: longitude)))
                        dismiss()
                    } label: {
                        Label("Start Path Here", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }
}

#Preview {
    AddNewStairPathView(apiService: APIService(), latitude: 37.7749, longitude: -122.4194)
}
