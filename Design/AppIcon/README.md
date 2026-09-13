# Guerkchen App-Icon

Quelle: `Guerkchen App Icon.dc.html` (Vektor). Alle PNGs daraus gerendert.
Ab 32 px wird eine vereinfachte Variante verwendet (kein Stiel, keine Strukturlinien, größeres Gesicht).

## Im Projekt eingebaut

Das macOS-Set liegt als `App/Resources/Assets.xcassets/AppIcon.appiconset` im Asset-Katalog
des Targets. Verdrahtet über `project.yml`:

- `settings.base.ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- `info.properties.CFBundleIconName: AppIcon`

Fürs UI liegt daneben `GuerkchenIcon.imageset` (128 px @1x, 256 px @2x) — gedacht für
Darstellung bis 128 pt. Verwendet im leeren Editor-Zustand (`App/UI/Editor/EditorView.swift`):

    Image("GuerkchenIcon")
        .resizable()
        .frame(width: 96, height: 96)

Größere Darstellung braucht größere Slots — dann `png/guerkchen-512.png` als @2x nachlegen.

Nach Änderungen am Icon `xcodegen generate` laufen lassen — der Asset-Katalog wird über
`sources: App` automatisch mitgenommen.

## Quelldateien in diesem Ordner

- `guerkchen-icon.svg` — abgerundetes Icon mit Gelb-Verlauf (Web, Docs, Dock)
- `guerkchen-icon-square.svg` — randabfallend, für Systeme die selbst maskieren (iOS, Android)
- `guerkchen-icon-small*.svg` — vereinfachte Kleinvariante
- `png/guerkchen-<größe>.png` — 1024 · 512 · 256 · 128 · 64 · 32 · 16
- `AppIcon-iOS.appiconset/` — iOS/iPadOS Single-Size 1024 (aktuell kein iOS-Target)
- `android/ic_launcher-*.png` — 432 (adaptive foreground) · 192 · 144 · 96 · 72 · 48
- `web/favicon-16.png`, `web/favicon-32.png`, `web/apple-touch-icon.png`

## Weitere Verwendung

Fenster-Icon zur Laufzeit setzen (AppKit):

    NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon")

Web / README:

    <link rel="icon" type="image/png" sizes="32x32" href="web/favicon-32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="web/favicon-16.png">
    <link rel="apple-touch-icon" href="web/apple-touch-icon.png">

    <img src="Design/AppIcon/png/guerkchen-256.png" width="128" alt="Guerkchen">

## Farben

- Verlauf Hintergrund: #FFE36B → #FFC61A → #E89A00
- Gurke: #7FC23F, Struktur #5D9C2C, Warzen #4F8A24
- Kontur: #1C2E10 · Mund #8E1026 / Zunge #E4436A · Augen #10213A
