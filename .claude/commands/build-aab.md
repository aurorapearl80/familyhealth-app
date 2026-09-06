# Build Android App Bundle (AAB)

Generates a release Android App Bundle for the Flutter app, for upload to the Play Store.

Play Store requires every uploaded AAB to have a strictly higher `versionCode` than the
last one uploaded, so this command auto-bumps the build number in `pubspec.yaml`
(the `+N` part of `version: X.Y.Z+N`) before building.

## Steps to execute

**Step 1 — Bump the version code in `pubspec.yaml`:**
```
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
NAME="${CURRENT%%+*}"
CODE="${CURRENT##*+}"
NEW_CODE=$((CODE + 1))
sed -i '' "s/^version: .*/version: ${NAME}+${NEW_CODE}/" pubspec.yaml
echo "Bumped version: ${CURRENT} -> ${NAME}+${NEW_CODE}"
```

**Step 2 — Build the AAB:**
```
flutter build appbundle --release
```

Output location: `build/app/outputs/bundle/release/app-release.aab`

Note: signing uses `android/key.properties` + the release keystore if present
(see `android/app/build.gradle.kts`), otherwise falls back to debug signing.

Run both steps in order. Report the old/new version code, the final output path, and any
errors. Do not commit the `pubspec.yaml` change automatically — leave it for the user to
review and commit.
