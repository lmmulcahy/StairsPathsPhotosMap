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
    @Binding var selectedTap: MapLocation?
    @Binding var startedStairPath: MapLocation?
    @Binding var selectedPath: StairPath?
    var stairPaths: [StairPath]
    var stairPathInProgress: [StairPathInProgress]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12) // Default to San Francisco
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear() // Clear existing markers and polylines

        // Add existing stair paths
        for stairPath in stairPaths {
            // Add polyline
            let path = GMSMutablePath()
            path.add(CLLocationCoordinate2D(latitude: stairPath.startCoordinate.latitude, longitude: stairPath.startCoordinate.longitude))
            path.add(CLLocationCoordinate2D(latitude: stairPath.endCoordinate.latitude, longitude: stairPath.endCoordinate.longitude))
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = .blue
            polyline.strokeWidth = 3.0
            polyline.map = mapView

            // Add marker
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: stairPath.centerCoordinate.latitude, longitude: stairPath.centerCoordinate.longitude)
            marker.title = stairPath.name
            marker.icon = GMSMarker.markerImage(with: .blue)
            marker.map = mapView
            marker.userData = stairPath // Attach the StairPath object for selection
        }

        // Add in-progress stair paths
        for inProgress in stairPathInProgress {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: inProgress.start.coordinate.latitude, longitude: inProgress.start.coordinate.longitude)
            marker.title = "Start"
            marker.icon = GMSMarker.markerImage(with: .blue)
            marker.map = mapView
        }

        // Add selected tap marker
        if let selectedTap = selectedTap {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: selectedTap.latitude, longitude: selectedTap.longitude)
            marker.icon = GMSMarker.markerImage(with: .yellow)
            marker.map = mapView
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
                parent.selectedTap = MapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            } else {
                parent.selectedTap = nil
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
    @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @Query() private var stairPathInProgress: [StairPathInProgress]

    @State private var selectedTap: MapLocation?
    @State private var startedStairPath: MapLocation?
    @State private var selectedPath: StairPath?

    var body: some View {
        GoogleMapEditView(
            selectedTap: $selectedTap,
            startedStairPath: $startedStairPath,
            selectedPath: $selectedPath,
            stairPaths: stairPaths,
            stairPathInProgress: stairPathInProgress
        )
        .sheet(item: $selectedTap) { selectedTap in
            if selectedPath == nil {
                AddNewStairPathView(latitude: selectedTap.latitude, longitude: selectedTap.longitude)
                    .presentationDetents([.height(250)])
            }
        }
    }
}

#Preview {
    GoogleMapEditViewContainer().modelContainer(StairPath.preview)
}