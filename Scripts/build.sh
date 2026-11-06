#!/bin/zsh
set -eu
cd "${0:A:h:h}"
xcodebuild -project TecWisper.xcodeproj -scheme TecWisper -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
Scripts/package_dmg.sh build/DerivedData/Build/Products/Release/TecWisper.app
