//
//  AddNewStairPathView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lukemulcahy.StairsPathsPhotosMap", category: "AddNewStairPath")

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

                    Picker("Path Type", selection: $type) {
                        ForEach(StairPathType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .accessibilityLabel("Path type")
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        discardDraft()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)

                    Button {
                        guard let inProgress = stairPathInProgress.first, let start = inProgress.points.first, let end = inProgress.points.last else { return }

                        // Serialize the points into a pathData JSON string. StairPath's
                        // encoder re-emits this as a real array for the backend.
                        let pathDataArr = inProgress.points.map { [$0.latitude, $0.longitude] }
                        let pathDataStr = (try? JSONEncoder().encode(pathDataArr)).flatMap { String(data: $0, encoding: .utf8) }

                        // id 0 is a placeholder; the backend assigns the real id and we
                        // adopt the server's response in APIService.addStairPath.
                        let newPath = StairPath(
                            id: 0,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            startLatitude: start.latitude,
                            startLongitude: start.longitude,
                            endLatitude: end.latitude,
                            endLongitude: end.longitude,
                            pathData: pathDataStr
                        )

                        Task {
                            await apiService.addStairPath(newPath)
                        }

                        discardDraft()
                        dismiss()
                    } label: {
                        Label("Save Path", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }

    /// Deletes the in-progress draft and persists the change, logging any failure.
    private func discardDraft() {
        guard let draft = stairPathInProgress.first else { return }
        modelContext.delete(draft)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to discard draft path: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AddNewStairPathView(apiService: APIService())
}
