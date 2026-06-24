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
    @State private var localPoints: [CLLocationCoordinate2D] = []

    var body: some View {
        let _ = refreshTrigger // Read state to force body re-evaluation on tap
        MapReader { proxy in
            Map(selection: $selectedPathId) {
                ForEach(apiService.stairPaths) { stairPath in
                    let stairPathFull = StairPathFull(stairPath: stairPath)
                    Group {
                        MapPolyline(coordinates: stairPathFull.coordinates)
                            .stroke(Color.accentColor, lineWidth: 4)
                        Annotation(stairPath.name, coordinate: stairPathFull.centerCoordinate, anchor: .center) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }.tag(stairPath.id)
                }
                ForEach(Array(localPoints.enumerated()), id: \.offset) { index, coord in
                    Annotation(index == 0 ? "Start" : "Point \(index + 1)", coordinate: coord, anchor: .center) {
                        Circle()
                            .fill(.red)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                if localPoints.count > 1 {
                    MapPolyline(coordinates: localPoints)
                        .stroke(.red, lineWidth: 4)
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
                            localPoints = []
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
                let count = stairPathInProgress.first?.points.count ?? 0
                VStack(spacing: 4) {
                    Text(count == 0 ? "Tap to set the start point" : "Keep tapping to add points")
                        .font(.headline)
                    if count > 0 {
                        Text("\(count) \(count == 1 ? "point" : "points") added")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top)
            }
            .onAppear {
                if let inProgress = stairPathInProgress.first {
                    localPoints = inProgress.points.map { $0.coordinate }
                }
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            .onChange(of: stairPathInProgress.count) { old, newCount in
                if newCount == 0 {
                    localPoints = []
                }
            }
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    if selectedPathId == nil {
                        let newTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        modelContext.insert(newTap)
                        if let inProgress = stairPathInProgress.first {
                            inProgress.points.append(newTap)
                        } else {
                            let newInProgress = StairPathInProgress(points: [newTap])
                            modelContext.insert(newInProgress)
                        }
                        localPoints.append(coordinate)
                        try? modelContext.save()
                        refreshTrigger += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
