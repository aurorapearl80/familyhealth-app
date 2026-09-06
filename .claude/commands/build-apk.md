# Build Android APK

Generates a release APK for the Flutter app, for direct install/sideloading.

## Command to execute

```
flutter build apk --release
```

Output location: `build/app/outputs/flutter-apk/app-release.apk`

Note: signing uses `android/key.properties` + the release keystore if present
(see `android/app/build.gradle.kts`), otherwise falls back to debug signing.

Run the command and report the final output path and any errors.
