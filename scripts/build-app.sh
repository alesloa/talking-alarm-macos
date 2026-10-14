#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
# Distribution binaries should not retain the builder's source/debug paths.
swift build -c release -Xswiftc -gnone
APP="$(pwd)/dist/Talking Alarm.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TalkingAlarm "$APP/Contents/MacOS/TalkingAlarm"
strip -S "$APP/Contents/MacOS/TalkingAlarm"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.talking-alarm.app</string>
<key>CFBundleName</key><string>Talking Alarm</string>
<key>CFBundleExecutable</key><string>TalkingAlarm</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
