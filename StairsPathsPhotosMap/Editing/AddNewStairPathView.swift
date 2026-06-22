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

    @State private var name = ""
    @State private var type: StairPathType = .stairs

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Complete Path")
                    .font(.headline)
                
                if let inProgress = stairPathInProgress.first {
                    Text("\(inProgress.points.count) points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                        guard let inProgress = stairPathInProgress.first, let start = inProgress.points.first, let end = inProgress.points.last else { return }
                        
                        // We serialize the points into pathData JSON string
                        let pathDataArr = inProgress.points.map { [$0.latitude, $0.longitude] }
                        let pathDataStr: String?
                        if let data = try? JSONEncoder().encode(pathDataArr), let str = String(data: data, encoding: .utf8) {
                            pathDataStr = str
                        } else {
                            pathDataStr = nil
                        }

                        let newPath = StairPath(
                            id: Int.random(in: 1...1000000), // temp id
                            name: name,
                            startLatitude: start.latitude,
                            startLongitude: start.longitude,
                            endLatitude: end.latitude,
                            endLongitude: end.longitude,
                            pathData: pathDataStr
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
            }
            Spacer()
        }
    }
}

#Preview {
    AddNewStairPathView(apiService: APIService())
}
