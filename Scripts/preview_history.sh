#!/bin/zsh
set -eu
cd "${0:A:h:h}"
preview=build/preview/TecWisperHistoryPreview.app
mkdir -p "$preview/Contents/MacOS"
sources=(TecWisper/**/*.swift)
sources=(${sources:#TecWisper/TecWisperApp.swift})
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library $sources Tests/HistoryPreview.swift -o "$preview/Contents/MacOS/HistoryPreview"
python3 - <<'PY'
import plistlib
from pathlib import Path
Path('build/preview/TecWisperHistoryPreview.app/Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'de.tecwisper.HistoryPreview','CFBundleName':'TecWisperHistoryPreview','CFBundleExecutable':'HistoryPreview','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PY
codesign --force --sign - "$preview"
"$preview/Contents/MacOS/HistoryPreview" "$PWD/build/preview"
