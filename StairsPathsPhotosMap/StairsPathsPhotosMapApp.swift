//
//  StairsPathsPhotosMapApp.swift
//  StairsPathsPhotosMap
//
//  Created by Luke Mulcahy on 11/29/24.
//

import GoogleMaps
import SwiftData
import SwiftUI

class StairsPathsPhotosMapAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // The Google Maps key is optional: it is only needed when the user picks
        // the Google Maps backend. If it is missing we skip SDK setup rather than
        // crash, so the Apple Maps experience still works.
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String,
           !apiKey.isEmpty {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("Google Maps API key is missing; Google Maps backend will be unavailable.")
        }

        return true
    }

    // You can implement other UIApplicationDelegate methods here if needed
}

@main
struct StairsPathsPhotosMapApp: App {
    var container: ModelContainer
    
    @UIApplicationDelegateAdaptor(StairsPathsPhotosMapAppDelegate.self) var appDelegate

    init() {
        do {
            container = try ModelContainer(for: StairPathInProgress.self, StairPath.self)
        } catch {
            fatalError("Couldn't set up SwiftData container")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            StartTab()
        }.modelContainer(container)
    }
}
