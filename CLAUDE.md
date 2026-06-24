# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A three-part project for cataloging urban stairways and walking paths on a map with attached photos:

- **`StairsPathsPhotosMap/`** — the primary iOS app (SwiftUI + SwiftData), Apple Maps or Google Maps backend.
- **`cloudflare-backend/`** — a Cloudflare Worker (D1 + R2) that is the system of record for paths and photos.
- **`web-client/`** — a React/Vite/Leaflet web client that can browse, create, and edit paths (multi-point) and view photos.

The iOS app and web client both talk to the same deployed Worker at
`https://stairs-paths-api.luke-mulcahy.workers.dev`.

## Commands

### iOS app
Build and test from the repo root (scheme `StairsPathsPhotosMap`, deployment target iOS 18.1):

```bash
# Build
xcodebuild -scheme StairsPathsPhotosMap -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -scheme StairsPathsPhotosMap -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test (Swift Testing)
xcodebuild -scheme StairsPathsPhotosMap -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:StairsPathsPhotosMapTests/StairsPathsPhotosMapTests/completingPathCreatesStairPathAndRemovesDraft
```

Tests use the **Swift Testing** framework (`import Testing`, `@Test`, `@Suite`), not XCTest. The suite is `.serialized` and `@MainActor` because the test host renders MapKit alongside a shared SwiftData stack, which is unstable under parallel execution.

Before first build, copy `StairsPathsPhotosMap/Secrets.example.xcconfig` to `Secrets.xcconfig` and set `GOOGLE_MAPS_API_KEY` (optional — only the Google Maps backend needs it; Apple Maps works without). `Secrets.xcconfig` is gitignored. Google Maps iOS SDK resolves automatically via SPM.

### Cloudflare backend (`cloudflare-backend/`)
```bash
npm run dev      # wrangler dev (local)
npm run deploy   # wrangler deploy
```
Bindings: `DB` (D1 `stairs_paths_db`), `BUCKET` (R2 `stairs-paths-photos`).

### Web client (`web-client/`)
```bash
npm run dev      # vite dev server
npm run build    # tsc -b && vite build
npm run lint     # eslint
```

## Architecture

### Data ownership — this is the key concept
Despite the README describing SwiftData persistence, **the Cloudflare Worker is the source of truth for saved paths and photos.** The iOS SwiftData container only persists `StairPathInProgress` (in-progress path drafts being drawn). Pay attention to which model you are dealing with:

- `StairPath` (`Models/StairPath.swift`) — a plain `Codable`/`Identifiable` class, **not** a SwiftData `@Model`. This is the API/wire model fetched from and posted to the Worker via `APIService`.
- `StairPathInProgress` + `MapLocation` (`Models/`) — SwiftData `@Model`s used only as local drafts during the tap-to-create flow.
- `StairPathFull` (`Models/StairPathFull.swift`) — an `ObservableObject` wrapper around a `StairPath` that also holds fetched `photoUrls` and derives `coordinates`/`centerCoordinate`.

`APIService` (`BackendClient/APIService.swift`, `@MainActor ObservableObject`) owns all network calls and is injected as an `@EnvironmentObject`. Worker endpoints:
`GET/POST /stairpaths`, `PUT /stairpaths/:id` (edit), `GET/POST /stairpaths/:id/photos`, `GET /photos/:id`.

### `pathData` encoding — multi-segment paths
A `StairPath` is more than start/end. `pathData` is a **JSON-encoded array of `[latitude, longitude]` pairs** (e.g. `"[[37.7,-122.4],[37.71,-122.41]]"`) representing the full multi-point polyline, stored in the D1 `pathData TEXT` column. `StairPathFull.coordinates` decodes it and falls back to `[start, end]` when `pathData` is nil. When creating or editing paths, the per-vertex `pathData` and the start/end columns must stay consistent.

Mind the wire-format asymmetry: the web client sends `pathData` as a raw JSON **array**, and the Worker `JSON.stringify`s it before storing (POST and PUT). The iOS `StairPath.pathData` is a `String?` that is encoded as an already-stringified JSON string. Both clients accept either a string or an array when reading.

### iOS UI structure
SwiftUI throughout with no view-model layer — views own `@Query`/`modelContext` and call `APIService` directly. Google Maps screens are `UIViewRepresentable` bridges.

- `StartTab.swift` — tab bar + Apple/Google map-backend selection.
- `PhotoMap/` — browse maps (`PhotoMapView` = Apple, `GooglePhotoMapView` = Google) + photo viewing/picking sheets and `PhotoLibraryManager`.
- `Editing/` — `AddNewStairPathView` (tap start → tap end → name/type) and the Apple/Google edit maps.
- `List/StairPathsListView.swift` — list of saved paths.

The app skips rendering `StartTab` (shows `EmptyView`) when `XCTestConfigurationFilePath` is set, to keep MapKit from destabilizing the simulator during tests.

### Backend
Single-file Worker (`cloudflare-backend/src/index.ts`) with hand-rolled routing and permissive CORS. Photos are streamed into R2 under `photos/<stairpathId>/<uuid>.jpg`; the D1 `photos` table maps photo id → object key. **Note:** nothing in the Worker runs `CREATE TABLE` — `cloudflare-backend/schema.sql` is a reference file, not an applied migration. The production schema was built/altered out-of-band (e.g. `wrangler d1 execute --command`), so when you change table structure you must apply it to D1 yourself; keep `schema.sql` in sync by hand.
