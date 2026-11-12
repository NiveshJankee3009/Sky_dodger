#!/usr/bin/env bash
# Prepares the android/ or ios/ folder in CI.
#   tool/ci/prepare_platform.sh android
#   tool/ci/prepare_platform.sh ios
# - generates the platform folder with `flutter create` if it isn't committed
# - sets the app's display name to "Sky Dodger"
# - iOS: registers the Google Sign-In URL scheme from firebase/GoogleService-Info.plist
set -euo pipefail

PLATFORM="$1"
ORG="com.github.skydodger"
NAME="sky_dodger"
DISPLAY="Sky Dodger"

if [ ! -d "$PLATFORM" ]; then
  flutter create --platforms="$PLATFORM" --org "$ORG" --project-name "$NAME" .
fi

if [ "$PLATFORM" = "android" ]; then
  MANIFEST=android/app/src/main/AndroidManifest.xml
  sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$DISPLAY\"/" "$MANIFEST"
  rm -f "$MANIFEST.bak"

  # App icon (legacy + adaptive + Android 13 themed), see tool/make_icons.py
  if [ -d assets/icon/android/res ]; then
    cp -R assets/icon/android/res/. android/app/src/main/res/
  fi
fi

if [ "$PLATFORM" = "ios" ]; then
  PLIST=ios/Runner/Info.plist
  plutil -replace CFBundleDisplayName -string "$DISPLAY" "$PLIST"

  # App icon, see tool/make_icons.py
  ICONSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
  if [ -d assets/icon/ios/AppIcon.appiconset ]; then
    rm -rf "$ICONSET"
    cp -R assets/icon/ios/AppIcon.appiconset "$ICONSET"
  fi

  FIREBASE_PLIST=firebase/GoogleService-Info.plist
  if [ -f "$FIREBASE_PLIST" ]; then
    REVERSED=$(plutil -extract REVERSED_CLIENT_ID raw "$FIREBASE_PLIST" 2>/dev/null || true)
    if [ -n "$REVERSED" ]; then
      plutil -replace CFBundleURLTypes -xml \
        "<array><dict><key>CFBundleTypeRole</key><string>Editor</string><key>CFBundleURLSchemes</key><array><string>$REVERSED</string></array></dict></array>" \
        "$PLIST"
      echo "Registered Google Sign-In URL scheme: $REVERSED"
    fi
  else
    echo "No $FIREBASE_PLIST - Google Sign-In won't work on iOS until it's added."
  fi
fi
