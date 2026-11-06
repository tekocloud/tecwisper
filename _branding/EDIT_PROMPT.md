# TecWisper-Logo · 30.10.2026

Original: `Sprachwelle trifft Textstriche.png` im Projektverzeichnis, unverändert erhalten.

Bearbeitung mit dem eingebauten ImageGen-Werkzeug (`transparent_background: true`). Als freigegebene Projektgrundlage wird ausschließlich `tecwisper-icon-master.png` verwendet. Die technische Größenkonvertierung erfolgt anschließend mit AppKit in `Scripts/make_icon.swift`.

## Verwendeter Prompt für den eingebundenen Master

> Use case: background-extraction. Edit target: supplied image of the TecWisper application logo. Prepare a production macOS app icon, square 1024x1024 PNG with real alpha transparency outside the icon tile. Preserve the supplied exact recognizable symbol: on the left three rounded vertical blue waveform pills increasing in height, then a fourth blue vertical stem smoothly branching into the top rounded horizontal text line on the right, with two separate rounded horizontal blue lines below. Preserve the reference silhouette, proportions, gradient from saturated azure to cyan, and dark anthracite squircle tile. Remove ONLY the extraneous dark square background outside the rounded tile and the excessive margin. Center the entire rounded tile front-on, with a conventional macOS icon safe margin of about 50px on each side of a 1024px canvas. Keep entire tile within frame. Refine the tile to a clean crisp #252526 charcoal with subtle original edge highlight, reduce diffuse fog and heavy cast shadow so it reads at 32px. Logo should fill roughly 72 percent of tile width, like reference. No new symbols, no text, no initials, no extra bars or lines, no checkerboard drawn into image. Preserve reference identity faithfully. Actual transparent background outside tile.

## Ausgaben

- `tecwisper-icon-master.png`: bearbeiteter Master, 1254 × 1254 Pixel, transparenter Außenrand.
- `TecWisper-Icon-1024.png`: normalisierter 1024-Pixel-Export zum Weiterverwenden.
- `../TecWisper/Resources/TecWisperIcon.icns`: macOS-Icon mit Größen von 16 bis 1024 Pixel.
- `../TecWisper/Resources/Brand/AppLogo.png` und `AppLogo@2x.png`: Oberfläche.
- `../TecWisper/Resources/Brand/MenuBarLogo.png` und `MenuBarLogo@2x.png`: Menüleiste, farbig mit demselben Motiv.
