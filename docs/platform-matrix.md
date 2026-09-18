# Platform build matrix

Verification date: 2026-09-19. Flutter 3.47.1 / Dart 3.13.1.

| Platform | Platform directory | Verification command | Result | Artifact or note |
| --- | --- | --- | --- | --- |
| macOS | `packages/besprotoritsa_app/macos/` | `flutter build macos --debug` | Blocked by environment | The command reached the Xcode stage but failed because `xcodebuild` is not installed or selected. Install the full Xcode package, run `xcode-select --switch /Applications/Xcode.app/Contents/Developer`, then rerun the command. |
| Web | `packages/besprotoritsa_app/web/` | `flutter build web` | Passed | `packages/besprotoritsa_app/build/web/index.html` |
| Android | `packages/besprotoritsa_app/android/` | `flutter build apk --debug` | Passed | `packages/besprotoritsa_app/build/app/outputs/flutter-apk/app-debug.apk` |

Additional verification: `flutter test` and `flutter analyze` both pass for `packages/besprotoritsa_app`.
