//
//  StairPathsListView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import SwiftUI

struct StairPathsListView: View {
    @EnvironmentObject var apiService: APIService
    @State private var selectedPath: StairPath?

    var body: some View {
        NavigationStack {
            Group {
                if apiService.stairPaths.isEmpty {
                    if apiService.isLoading {
                        ProgressView("Loading paths…")
                    } else {
                        ContentUnavailableView(
                            "No Paths Yet",
                            systemImage: "figure.stairs",
                            description: Text("Stairways and paths will appear here once they're added.")
                        )
                    }
                } else {
                    List(apiService.stairPaths) { stairPath in
                        Button {
                            selectedPath = stairPath
                        } label: {
                            row(for: stairPath)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Paths")
            .refreshable {
                await apiService.fetchStairPaths()
            }
            .task {
                if apiService.stairPaths.isEmpty {
                    await apiService.fetchStairPaths()
                }
            }
            .sheet(item: $selectedPath) { path in
                StairPathPhotosView(stairPathId: path.id, stairPath: path, stairPathFull: StairPathFull(stairPath: path))
                    .presentationDetents([.fraction(0.5), .large])
            }
        }
    }

    private func row(for stairPath: StairPath) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.stairs")
                .foregroundStyle(Color.accentColor)
                .font(.title3)
                .frame(width: 28)
            Text(stairPath.name)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
