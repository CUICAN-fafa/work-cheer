#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
python3 check_localization.py
APP="build/上班鼓励器.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj
for ARCH in arm64 x86_64; do
  xcrun swiftc main.swift Records.swift Localization.swift -O -framework Cocoa -target "$ARCH-apple-macosx12.0" -o "build/obj/WorkCheer-$ARCH"
done
lipo -create build/obj/WorkCheer-arm64 build/obj/WorkCheer-x86_64 -output "$APP/Contents/MacOS/WorkCheer"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/zh-Hans.lproj"
cp InfoPlist.en.strings "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
cp InfoPlist.zh-Hans.strings "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
cp en.json zh-Hans.json NOTICE.txt AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/WorkCheer" --self-test
"$APP/Contents/MacOS/WorkCheer" --self-test --english
ditto -c -k --sequesterRsrc --keepParent "$APP" build/Work-Cheer-Mac.zip
printf 'Built: %s/build/Work-Cheer-Mac.zip\n' "$PROJECT_DIR"
