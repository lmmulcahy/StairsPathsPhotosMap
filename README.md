# StairsPathsPhotosMap

An iOS app for cataloging urban stairways and walking paths on a map and
attaching photos to each one. Built with SwiftUI and SwiftData, with a
choice of Apple Maps or Google Maps as the map backend.

## Features

- Browse stairways and paths as polylines with center markers on a map.
- Tap a path to view and add photos.
- Create a new path with a two-tap flow: tap the start point, then the end
  point, and give it a name and type (Stairs or Path).
- List view of all saved paths.
- Switch between Apple Maps and Google Maps in Settings.

## Architecture

- **UI:** SwiftUI throughout, with `UIViewRepresentable` bridges for the
  Google Maps SDK.
- **Persistence:** SwiftData (`StairPath`, `StairPathInProgress`,
  `MapLocation`). Photos are stored with external storage and downscaled
  before saving.
- **State:** Views own their `@Query` reads and `modelContext` writes
  directly; there is no separate view-model layer.

## Setup

1. Open `StairsPathsPhotosMap.xcodeproj` in Xcode (deployment target iOS
   18.1).
2. Dependencies are managed with Swift Package Manager and resolve
   automatically (Google Maps iOS SDK).
3. Configure secrets:
   - Copy `StairsPathsPhotosMap/Secrets.example.xcconfig` to
     `StairsPathsPhotosMap/Secrets.xcconfig`.
   - Set `GOOGLE_MAPS_API_KEY` to your own key if you want the Google Maps
     backend. Apple Maps works without a key.
   - `Secrets.xcconfig` is gitignored and should never be committed.
4. Build and run.

## Project layout

```
StairsPathsPhotosMap/
  StairsPathsPhotosMapApp.swift   App entry point + SwiftData container
  StartTab.swift                  Tab bar and map-backend selection
  SettingsView.swift              Map preference
  Models/                         StairPath, StairPathInProgress, MapLocation
  PhotoMap/                       Browse maps (Apple + Google) and photo sheet
  Editing/                        Edit maps and the add-path flow
  List/                           Simple list of saved paths
```
