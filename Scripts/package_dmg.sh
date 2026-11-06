#!/bin/zsh
set -eu
cd "${0:A:h:h}"
app_path="${1:-build/DerivedData/Build/Products/Release/TecWisper.app}"
codesign --verify --deep --strict "$app_path"
mkdir -p build
stage=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app_path" "$stage/TecWisper.app"
ln -s /Applications "$stage/Programme"
cat > "$stage/Installation.txt" <<'TEXT'
TecWisper installieren

1. Eine bereits laufende TecWisper-App vollständig beenden.
2. TecWisper.app auf den Ordner „Programme“ ziehen.
3. TecWisper anschließend aus „Programme“ starten.
4. Das Installationslaufwerk im Finder auswerfen.
TEXT
hdiutil create -volname "TecWisper installieren" -srcfolder "$stage" -format UDZO -ov build/TecWisper-macOS.dmg
hdiutil verify build/TecWisper-macOS.dmg
echo 'Fertig: build/TecWisper-macOS.dmg — App auf Programme ziehen.'
