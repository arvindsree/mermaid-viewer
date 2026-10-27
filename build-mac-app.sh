#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Mermaid Viewer"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
INSTALL_DIR="${1:-$HOME/Applications}"

cd "$ROOT_DIR"
WEB_DIR="$ROOT_DIR/build/web"
if ! "$ROOT_DIR/node_modules/.bin/parcel" build src/index.html --dist-dir "$WEB_DIR" --public-url ./; then
    if [[ ! -f "$ROOT_DIR/dist/index.html" ]]; then
        echo "Parcel build failed and no existing dist/index.html is available." >&2
        exit 1
    fi
    echo "Parcel build failed; packaging the existing dist/ build instead." >&2
    WEB_DIR="$ROOT_DIR/dist"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/Web"
cp -R "$WEB_DIR/"* "$APP_BUNDLE/Contents/Resources/Web/"
# The committed web build targets a hosted subpath. Make its entry-point URLs
# relative so the same asset set works from the app's bundled file URL.
sed -i '' -e 's|":"/|":"./|g' \
    -e 's|src="/mermaid-viewer\.|src="./mermaid-viewer.|g' \
    "$APP_BUNDLE/Contents/Resources/Web/index.html"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MermaidViewer</string>
    <key>CFBundleIdentifier</key><string>com.newmo.mermaid-viewer</string>
    <key>CFBundleName</key><string>Mermaid Viewer</string>
    <key>CFBundleDisplayName</key><string>Mermaid Viewer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

xcrun swiftc -parse-as-library "$ROOT_DIR/macos/MermaidViewerApp.swift" \
    -framework AppKit -framework WebKit \
    -o "$APP_BUNDLE/Contents/MacOS/MermaidViewer"

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
printf 'Installed %s\n' "$INSTALL_DIR/$APP_NAME.app"
