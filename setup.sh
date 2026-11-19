#!/usr/bin/env bash
# Generates the remaining Flutter platform files (Gradle, Xcode project, icons)
# WITHOUT overwriting lib/, AndroidManifest.xml, MainActivity.kt or Info.plist.
set -euo pipefail
cd "$(dirname "$0")"
flutter create --org com.sample --project-name romdoul_bank --platforms=android,ios .
# iOS: mobile_scanner needs iOS 15.5+
if [ -f ios/Podfile ]; then
  sed -i.bak "s/^# platform :ios.*/platform :ios, '15.5'/" ios/Podfile && rm -f ios/Podfile.bak
fi
flutter pub get
echo "Ready. Try: flutter run   (Settings ⚙ in the app to set base URL + token)"
