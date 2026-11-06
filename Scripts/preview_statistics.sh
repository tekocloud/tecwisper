#!/bin/zsh
set -eu
cd "${0:A:h:h}"
preview=build/preview/TecWisperStatisticsPreview.app
mkdir -p "$preview/Contents/MacOS"
sources=(TecWisper/**/*.swift)
sources=(${sources:#TecWisper/TecWisperApp.swift})
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library $sources Tests/StatisticsPreview.swift -o "$preview/Contents/MacOS/StatisticsPreview"
python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('build/preview/TecWisperStatisticsPreview.app/Contents/Info.plist')
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'de.tecwisper.StatisticsPreview','CFBundleName':'TecWisperStatisticsPreview','CFBundleExecutable':'StatisticsPreview','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PY
codesign --force --sign - "$preview"
# The preview uses only synthetic metadata in build/preview, never the real database.
"$preview/Contents/MacOS/StatisticsPreview" "$PWD/build/preview"
