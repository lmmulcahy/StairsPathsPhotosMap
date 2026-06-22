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
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear() // Clear existing markers and polylines

        for stairPath in stairPaths {
            let stairPathFull = StairPathFull(stairPath: stairPath)
            // Add polyline
            let path = GMSMutablePath()
            path.add(CLLocationCoordinate2D(latitude: stairPathFull.startCoordinate.latitude, longitude: stairPathFull.startCoordinate.longitude))
            path.add(CLLocationCoordinate2D(latitude: stairPathFull.endCoordinate.latitude, longitude: stairPathFull.endCoordinate.longitude))
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = .blue
            polyline.strokeWidth = 3.0
            polyline.map = mapView

            // Add marker
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: stairPathFull.centerCoordinate.latitude, longitude: stairPathFull.centerCoordinate.longitude)
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
    @EnvironmentObject var apiService: APIService
    @State private var selectedPath: StairPath?

    var body: some View {
        GooglePhotoMapView(selectedPath: $selectedPath, stairPaths: apiService.stairPaths)
            .onAppear {
                if apiService.stairPaths.isEmpty {
                    Task {
                        await apiService.fetchStairPaths()
                    }
                }
            }
            .sheet(item: $selectedPath) { selectedPath in
                StairPathPhotosView(stairPathId: selectedPath.id, stairPath: selectedPath, stairPathFull: StairPathFull(stairPath: selectedPath)).presentationDetents([.fraction(0.5)])
            }
    }
}

#Preview {
    GooglePhotoMapViewContainer().environmentObject(APIService())
}