# ARCHITECTURE

## Overview

QRToGo is an iOS/iPadOS SwiftUI application for generating QR codes and exporting them to Photos. The repository currently contains two runtime targets:

- `QRToGo`: the main app, centered around three tabs for generation, favorites, and settings.
- `QRCodeGenerator`: a share extension that turns shared URLs, text, and vCards into QR exports using the same rendering and persistence code as the main app.

The codebase is feature-oriented at the UI layer and pragmatic rather than heavily layered. Most business logic lives in small services, stores, and payload builders. Shared code is kept in the top-level `Shared/` folder and compiled into both targets.

## Repository Structure

```text
QRToGo/
├── QRToGo.xcodeproj/              Xcode project with app target and share extension target
├── QRToGo/                        Main app target
│   ├── Services/                  Quick action routing and shortcut updates
│   ├── Views/
│   │   ├── Main/                  Tab root
│   │   ├── Generate/              QR content editing, preview, location/contact helpers
│   │   ├── Favorites/             Saved QR list, detail, rename, quick action presentation
│   │   ├── Settings/              Appearance, logo, language, export album settings
│   │   ├── About/                 App metadata screen
│   │   ├── Launch/                Initial loading view
│   │   └── Shared/                Reusable app-only view pieces
│   ├── QRToGoApp.swift            SwiftUI app entry point
│   ├── QRToGoAppDelegate.swift    App and scene delegate bridge for quick actions
│   └── AppNavigationState.swift   Cross-tab navigation and launch-mode state
├── QRCodeGenerator/               Share extension target
│   ├── ShareRootView.swift        Extension UI
│   ├── ShareRootViewController.swift
│   ├── ShareViewModel.swift
│   └── ShareExportMetadataBuilder.swift
├── Shared/                        Code compiled into both targets
│   ├── QRCodeGeneratorService.swift
│   ├── QRCodeSettings*.swift
│   ├── QRCodeExport*.swift
│   ├── PhotoAlbumSaver.swift
│   ├── SharedInputReader.swift
│   ├── ContactVCardPayloadBuilder.swift
│   └── localization files
└── README.md                      Currently just `WIP`
```

## Main Runtime Components

### Main app shell

- `QRToGoApp` launches `ContentView`.
- `ContentView` owns the app-wide state objects:
  - `AppNavigationState`
  - `SettingsViewModel`
  - `GenerateViewModel`
  - `FavoritesViewModel`
- Initial loading is intentionally centralized in `ContentView`. It loads settings and favorites once, connects the quick-action router, and generates the first QR preview before showing the tab UI.

### Navigation and launch handling

- `AppNavigationState` tracks the selected tab and the current launch mode.
- `FavoriteShortcutRouter` is a singleton that translates home-screen quick actions into navigation state.
- `QRToGoAppDelegate` and `QRToGoSceneDelegate` exist mainly to forward quick-action events into that router.
- A quick action can bypass the normal tab shell and present `FavoriteQuickActionRootView`.

### Generate feature

The Generate tab is the primary QR authoring flow.

- `GenerateView` is the SwiftUI form and preview screen.
- `GenerateViewModel` owns the in-progress draft, preview image, export state, and favorite creation flow.
- `GenerateContentDraft` and related enums model the supported QR payload types:
  - website
  - contact
  - Wi-Fi
  - email
  - SMS
  - call
  - event
  - location
- `GeneratePayloadBuilder` converts the draft into the final QR payload string.
- `GenerateExportMetadataBuilder` produces export-card metadata and filename/search metadata used when saving an image.

Platform-specific bridges inside this feature are kept local:

- `ContactPickerView` bridges to `CNContactPickerViewController`.
- `CurrentLocationProvider` uses `CLLocationManager` and still relies on `ObservableObject`/`@Published`, unlike the rest of the feature which uses Observation.
- `LocationMapPickerView` and related view files handle map-based location selection.

### Favorites feature

Favorites are saved QR definitions, not rendered image snapshots.

- `FavoritesViewModel` loads, mutates, and previews saved favorites.
- `FavoriteQRCodeStore` persists favorites as JSON in `UserDefaults.standard`.
- `FavoriteQuickActionService` derives up to four home-screen quick actions from the saved favorites.
- `FavoriteDetailView` and the quick-action presentation flow regenerate the QR image on demand from the stored payload and saved settings.

### Settings feature

- `SettingsViewModel` manages app language and QR export settings.
- `QRCodeSettingsStore` persists settings through the shared app-group `UserDefaults`.
- `AppLanguageStore` persists the selected language separately in the same app-group defaults.
- `SettingsView` exposes color, center-logo, language, and album-name configuration, plus image picking and cropping for the center logo.

### Share extension

The share extension is a thin UI and orchestration layer over shared code.

- `ShareRootViewController` is the extension principal class and embeds SwiftUI.
- `ShareViewModel` reads incoming content from the extension context, loads current settings, regenerates a preview, and saves the export card to Photos.
- `SharedInputReader` parses supported incoming content into `SharedInputCandidate` values.
- `ShareExportMetadataBuilder` adapts the shared candidate into export-card metadata and a filename.

The extension supports shared items conforming to URL, text, contact, and vCard types according to `QRCodeGenerator/Info.plist`.

### Shared rendering and export services

These files are the actual cross-target core of the product:

- `QRCodeGeneratorService` validates settings, selects an error-correction level, builds an `EFQRCode` style, and renders QR PNG output.
- `QRCodeErrorCorrectionPolicy` adjusts correction level based on payload size and whether a center icon is enabled.
- `QRCodeExportCardRenderer` wraps the raw QR image in a branded export card and can attach PNG metadata.
- `PhotoAlbumSaver` requests Photos permission, creates the target album if needed, and writes the PNG asset.
- `ContactVCardPayloadBuilder`, `VCardPayloadSanitizer`, and related helpers normalize contacts into safer QR payloads.
- `QRCodeSettings`, `QRValidationResult`, and related helpers define the shared settings and validation model.

## Data Flow

### Main app flow

1. `QRToGoApp` launches `ContentView`.
2. `ContentView` loads persisted settings and favorites, then asks `GenerateViewModel` to build the initial preview.
3. The Generate tab updates `GenerateContentDraft` as the user edits fields.
4. `GenerateViewModel.refreshPreview()` uses `GeneratePayloadBuilder` to produce the content string, then calls `QRCodeGeneratorService.generate()`.
5. Saving to Photos uses the current settings plus `GenerateExportMetadataBuilder` and `QRCodeExportCardRenderer`, then `PhotoAlbumSaver`.
6. Adding a favorite stores the payload string plus the normalized settings snapshot in `FavoriteQRCodeStore`.

### Favorites flow

1. `FavoritesViewModel` loads favorites from `UserDefaults.standard`.
2. The list and detail screens read from that in-memory array.
3. When a favorite needs a preview or presentation image, `FavoritesViewModel` regenerates it through `QRCodeGeneratorService` rather than loading a cached bitmap.
4. Any favorite mutation triggers `FavoriteQuickActionService` to rebuild the app’s quick actions.

### Share extension flow

1. The system launches `ShareRootViewController` for matching shared content.
2. `ShareViewModel` loads app-group settings and uses `SharedInputReader` to parse incoming `NSExtensionContext` items into candidates.
3. The selected candidate’s content string is rendered by `QRCodeGeneratorService`.
4. `ShareExportMetadataBuilder` and `QRCodeExportCardRenderer` build the saved image.
5. `PhotoAlbumSaver` writes the PNG into the configured album.

## Key Design Decisions

### Shared business logic lives in `Shared/`

The main app and share extension reuse the same QR generation, export rendering, localization, and settings code. That avoids reimplementing QR behavior separately per target and keeps both surfaces visually and functionally aligned.

### UI state is mostly feature-local

There is no central app store. `ContentView` owns a small set of long-lived feature models and passes them into tabs. That matches the current app size and keeps most feature logic close to its screen.

### Favorites store payloads and settings, not images

Saved favorites persist the logical QR definition instead of a rendered asset. The benefit is that the app can regenerate a clean preview at any time and carry the original QR payload forward. The tradeoff is that opening a favorite always depends on live rendering.

### Shared settings use the app group, favorites do not

Settings and language are stored in app-group defaults so the share extension can use the same configuration. Favorites are currently stored in `UserDefaults.standard`, which means the extension does not appear to share the favorites list directly and the quick-action presentation path remains app-local.

### Settings are normalized toward scan-safe defaults

`QRCodeSettings.normalized()` currently forces several values back to default values, including error correction, output size, quiet zone, module style, and visual effect. This means the settings model is more permissive than the effective renderer configuration. That behavior is important to understand because it limits how much saved or edited settings can diverge from the scan-safe defaults.

## External Dependencies and Integrations

- `EFQRCode` Swift package: the only external package dependency, used for QR rendering and styling.
- Photos framework: saving PNG exports into a named album.
- Contacts / ContactsUI: picking contacts in the main app and converting them to vCard payloads.
- Core Location: filling location QR content from the current device position.
- Share extension APIs: receiving URLs, text, and contacts from other apps.
- App Group: `group.com.krusty84.QRToGo` is used for shared settings, language selection, and imported temporary files for the extension.

## Build / Validation Notes

- The Xcode project contains two targets: `QRToGo` and `QRCodeGenerator`.
- Both targets are configured for `iphoneos` and `iphonesimulator` only.
- Both targets use an iOS deployment target of `18.6` at the target level.
- Mac Catalyst and “Designed for iPad/iPhone on Mac” are disabled in build settings.
- The project uses generated Info.plist values plus checked-in per-target plist files.
- I did not run `xcodebuild`; this document is based on repository inspection only.

## Known Constraints

- There is no `ARCHITECTURE.md` or substantive `README.md` history to reconcile against; this document reflects only the current code.
- There is no test target in the repository today, so the architecture has no automated verification layer to point to.
- The codebase is not cleanly layered in a strict architectural sense. Views, view models, stores, and services are separated enough to be navigable, but the structure is intentionally lightweight.
- The share extension reuses settings and export infrastructure, but not the favorites store.
- Some files still use legacy UIKit / Combine patterns where platform APIs require bridging.
- A few build settings at the project level still show generated defaults that differ from the target-level deployment settings; the target settings are the meaningful ones for the shipped targets.
