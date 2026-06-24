//
//  GoogleMapEditView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 4/21/25.
//

import SwiftData
import SwiftUI
import GoogleMaps

struct GoogleMapEditView: UIViewRepresentable {
    @Binding var selectedPath: StairPath?
    var stairPaths: [StairPath]
    var stairPathInProgress: [StairPathInProgress]
    var refreshTrigger: Int
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12) // Default to San Francisco
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear() // Clear existing markers and polylines

        // Add existing stair paths
        for stairPath in stairPaths {
            let stairPathFull = StairPathFull(stairPath: stairPath)
            // Add polyline
            let path = GMSMutablePath()
            for coord in stairPathFull.coordinates {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = UIColor(Color.accentColor)
            polyline.strokeWidth = 4.0
            polyline.map = mapView

            // Add marker
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: stairPathFull.centerCoordinate.latitude, longitude: stairPathFull.centerCoordinate.longitude)
            marker.title = stairPath.name
            marker.icon = GMSMarker.markerImage(with: UIColor(Color.accentColor))
            marker.map = mapView
            marker.userData = stairPath // Attach the StairPath object for selection
        }

        // Add in-progress stair paths
        for inProgress in stairPathInProgress {
            if inProgress.points.isEmpty { continue }

            if inProgress.points.count > 1 {
                let path = GMSMutablePath()
                for pt in inProgress.points {
                    path.add(CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude))
                }
                let polyline = GMSPolyline(path: path)
                polyline.strokeColor = .red
                polyline.strokeWidth = 4.0
                polyline.map = mapView
            }

            for (index, pt) in inProgress.points.enumerated() {
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude)
                marker.title = index == 0 ? "Start" : (index == inProgress.points.count - 1 ? "End" : "Point \(index + 1)")
                marker.icon = GMSMarker.markerImage(with: .red)
                marker.map = mapView
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapEditView

        init(_ parent: GoogleMapEditView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if parent.selectedPath == nil {
                parent.onMapTap?(coordinate)
            }
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let stairPath = marker.userData as? StairPath {
                parent.selectedPath = stairPath
            }
            return true
        }
    }
}

struct GoogleMapEditViewContainer: View {
    @EnvironmentObject var apiService: APIService
    @Query() private var stairPathInProgress: [StairPathInProgress]
    @Environment(\.modelContext) private var modelContext

    @State private var showSaveSheet = false
    @State private var selectedPath: StairPath?
    @State private var refreshTrigger = 0

    var body: some View {
        GoogleMapEditView(
            selectedPath: $selectedPath,
            stairPaths: apiService.stairPaths,
            stairPathInProgress: stairPathInProgress,
            refreshTrigger: refreshTrigger,
            onMapTap: { coordinate in
                let newTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                modelContext.insert(newTap)
                if let inProgress = stairPathInProgress.first {
                    inProgress.points.append(newTap)
                } else {
                    let newInProgress = StairPathInProgress(points: [newTap])
                    modelContext.insert(newInProgress)
                }
                try? modelContext.save()
                refreshTrigger += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        )
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
            if apiService.stairPaths.isEmpty {
                Task {
                    await apiService.fetchStairPaths()
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            AddNewStairPathView(apiService: apiService)
                .presentationDetents([.height(250)])
        }
        .sheet(item: $selectedPath) { selectedPath in
            StairPathPhotosView(stairPathId: selectedPath.id, stairPath: selectedPath, stairPathFull: StairPathFull(stairPath: selectedPath))
                .presentationDetents([.fraction(0.5)])
        }
    }
}

#Preview {
    GoogleMapEditViewContainer().environmentObject(APIService())
}