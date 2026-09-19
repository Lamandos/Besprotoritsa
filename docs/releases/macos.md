# macOS release

## Build artifact

- Command: `flutter build macos --release`
- Artifact: `packages/besprotoritsa_app/build/macos/Build/Products/Release/Besprotoritsa.app`
- Version: `0.1.0` (`CFBundleVersion` `0.1.0`)
- Size measured 2026-09-20: 47 MiB (48,116 KiB)
- Architectures: `arm64`, `x86_64`
- Minimum macOS: 12.0
- Bundle identifier: `com.lamandos.besprotoritsa`
- Category: `public.app-category.board-games`

The release target has App Sandbox enabled. Saves are written atomically under
the app container's Application Support location:
`~/Library/Containers/com.lamandos.besprotoritsa/Data/Library/Application Support/game_saves/`.
No broad user-file access entitlement is granted. `get-task-allow` is disabled
for Release.

## Installation

1. Build the artifact from the repository root:

   ```sh
   cd packages/besprotoritsa_app
   flutter build macos --release
   ```

2. Copy `build/macos/Build/Products/Release/Besprotoritsa.app` to
   `/Applications` (or another directory controlled by the current user), then
   open it from Finder.

3. This build is ad-hoc signed for local verification. Before external
   distribution, sign it with a Developer ID certificate and notarize it; macOS
   Gatekeeper may otherwise require the user to explicitly approve the first
   launch.

## Verification recorded for this build

- `codesign --verify --deep --strict` passed; the embedded Release
  entitlements contain `app-sandbox = true` and `get-task-allow = false`.
- The built `Info.plist` reports the configured name, identifier and board-game
  category; `Assets.car` contains the `AppIcon` renditions from 16 through
  1024 pixels.
- The release executable was started directly with `open -n` (not through
  `flutter run`), cleanly exited, and started again successfully.
- `flutter test test/menu_navigation_test.dart test/save_system_test.dart`
  passed: it covers the New Game route plus durable file saves, including a
  fresh storage instance reopening an existing save after an interrupted
  write. `integration_test/save_resume_e2e_test.dart` was also run on macOS to
  cover save/resume across discarded session state.
