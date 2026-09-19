# Android release

## Build artifact

- APK: `packages/besprotoritsa_app/build/app/outputs/flutter-apk/app-release.apk`
- Android App Bundle: `packages/besprotoritsa_app/build/app/outputs/bundle/release/app-release.aab`
- Version: `0.1.0-dev` (version code `1`)
- Application ID: `ru.besprotoritsa.game`
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34

Both artifacts are built with the release signing configuration. The launcher
uses an Android 8+ adaptive icon with a dedicated foreground asset and navy
background; density-specific PNGs provide the Android 5–7 fallback.

## Signing setup

The private configuration is deliberately excluded from Git. Copy the template
before a release build and replace every placeholder with a protected signing
key:

```sh
cd packages/besprotoritsa_app/android
cp key.properties.example key.properties
```

`key.properties` and `*.jks` are ignored. Preserve the corresponding keystore
outside the repository (for example, in the team's secret storage): losing the
release key prevents publishing updates under the same Android application ID.

The current Flutter toolchain validates a higher minSdk by default; the project
sets `skipDependencyChecks=true` solely to keep the explicit API 21 release
requirement. Revalidate Android 5 compatibility when upgrading Flutter or its
plugins.

## SHA-256 checksums

Recorded on 2026-09-20 after the final release build:

```text
9ad1034a125141454c89d7453310173cee0f011d9317d616fed5bff8b074e1d4  app-release.apk
87885534c3aae37f7c2db05b248c6c6157a7b28f878a1545ab2a9830d9d116c4  app-release.aab
```

Verify an APK after transfer with:

```sh
shasum -a 256 app-release.apk
```

## Verification recorded for this build

- `flutter build apk --release` and `flutter build appbundle --release`
  completed successfully.
- `aapt` reports the configured application ID, minSdk 21, targetSdk 34 and
  `Besprotoritsa` label. `apksigner` verifies the APK's v1 and v2 signatures.
- Widget lifecycle coverage in `test/game_session_lifecycle_test.dart` verifies
  that system Back saves before the game route is disposed, and that
  pause/resume keeps the game screen active while persisting the autosave.
- The connected Android 13 device rejected local APK installation with
  `INSTALL_FAILED_USER_RESTRICTED`; no device-policy bypass was attempted.
