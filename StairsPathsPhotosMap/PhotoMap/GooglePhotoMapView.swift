//
//  GooglePhotoMapView.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 4/21/25.
//

import SwiftData
import SwiftUI
import GoogleMaps

struct GooglePhotoMapView: UIViewRepresentable {
    @Binding var selectedPath: StairPath?
    var stairPaths: [StairPath]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 37.7749, longitude: -122.4194, zoom: 12) // Default to San Francisco
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear() // Clear existing markers and polylines

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
            marker.icon = GMSMarker.markerImage(with: .red)
            marker.map = mapView
            marker.userData = stairPath // Attach the StairPath object for selection
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GooglePhotoMapView

        init(_ parent: GooglePhotoMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let stairPath = marker.userData as? StairPath {
                parent.selectedPath = stairPath
            }
            return true
        }
    }
}

struct GooglePhotoMapViewContainer: View {
    @Query(sort: \StairPath.name) private var stairPaths: [StairPath]
    @State private var selectedPath: StairPath?

    var body: some View {
        GooglePhotoMapView(selectedPath: $selectedPath, stairPaths: stairPaths)
            .sheet(item: $selectedPath) { selectedPath in
                StairPathPhotosView(stairPath: selectedPath).presentationDetents([.fraction(0.5)])
            }
    }
}

#Preview {
    GooglePhotoMapViewContainer().modelContainer(StairPath.preview)
}