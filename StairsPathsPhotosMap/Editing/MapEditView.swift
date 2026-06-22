//
//  MapEditView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/30/24.
//

import MapKit
import SwiftData
import SwiftUI

struct MapEditView: View {
    // @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]
    @EnvironmentObject var apiService: APIService

    @State private var showSaveSheet = false
    @State var selectedPathId: Int?
    @Environment(\.modelContext) private var modelContext
    @State private var refreshTrigger = 0

    var body: some View {
        let _ = refreshTrigger // Read state to force body re-evaluation on tap
        MapReader { proxy in
            Map(selection: $selectedPathId) {
                ForEach(apiService.stairPaths) { stairPath in
                    let stairPathFull = StairPathFull(stairPath: stairPath)
                    Group {
                        MapPolyline(coordinates: [stairPathFull.startCoordinate, stairPathFull.endCoordinate])
                            .stroke(.blue, lineWidth: 3)
                        Annotation(stairPath.name, coordinate: stairPathFull.centerCoordinate, anchor: .bottom) {
                            Circle().fill(.blue).frame(width: 8, height: 8)
                        }
                    }.tag(stairPath.id)
                }
                ForEach(stairPathInProgress) { stairPathInProgress in
                    ForEach(Array(stairPathInProgress.points.enumerated()), id: \.offset) { index, pt in
                        Annotation(index == 0 ? "Start" : "Point \(index+1)", coordinate: pt.coordinate, anchor: .bottom) {
                            Image(systemName: "mappin").foregroundStyle(.blue)
                        }
                    }
                    if stairPathInProgress.points.count > 1 {
                        MapPolyline(coordinates: stairPathInProgress.points.map { $0.coordinate })
                            .stroke(.red, lineWidth: 3)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let inProgress = stairPathInProgress.first, !inProgress.points.isEmpty {
                    VStack(spacing: 12) {
                        if inProgress.points.count >= 2 {
                            Button {
                                showSaveSheet = true
                            } label: {
                                Text("Finish Drawing Path")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.horizontal)
                        }

                        Button(role: .cancel) {
                            modelContext.delete(inProgress)
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
            .overlay(alignment: .top) {
                Text(stairPathInProgress.isEmpty ? "Tap to start location" : "Keep tapping to add points")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top)
            }
            .onAppear {
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    if selectedPathId == nil {
                        let newTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        modelContext.insert(newTap)
                        if let inProgress = stairPathInProgress.first {
                            inProgress.points.append(newTap)
                            let newPoints = inProgress.points
                            inProgress.points = newPoints
                        } else {
                            let newInProgress = StairPathInProgress(points: [newTap])
                            modelContext.insert(newInProgress)
                        }
                        try? modelContext.save()
                        refreshTrigger += 1
                    } else {
                        selectedPathId = nil
                    }
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                if selectedPathId == nil {
                    AddNewStairPathView(apiService: apiService)
                        .presentationDetents([.height(250)])
                }
            }
        }
    }
}

#Preview {
    MapEditView().environmentObject(APIService())
}
