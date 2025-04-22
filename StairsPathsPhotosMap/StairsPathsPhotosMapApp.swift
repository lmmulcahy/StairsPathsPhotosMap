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

        // 2. Set your Google Maps API key here
        // Retrieve the API key from the Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
            GMSServices.provideAPIKey(apiKey)
            print("Google Maps SDK initialized with API key") // Optional: Add a print to confirm
        } else {
            fatalError("Google Maps API key is missing. Please check your configuration.")
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
            container = try ModelContainer(for: StairPathInProgress.self, StairPath.self/*, configurations: ModelConfiguration(isStoredInMemoryOnly: true), ModelConfiguration(isStoredInMemoryOnly: true)*/)
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
