#!/usr/bin/env bash
# Package a desktop release build for GitHub: tool/package_desktop.sh linux|macos
# Run after `flutter build <target> --release`. Writes build/dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=jekyllpress                           # executable, .deb package, file names
NAME=JekyllPress                          # what the menu shows; the macOS .app
ID=com.jekyllpress.jekyllpress            # bundle id == Linux APPLICATION_ID
ICON=linux/packaging/jekyllpress_512.png  # 512x512
SUMMARY="A CMS for GitHub Pages (Jekyll) blogs"
CATEGORIES="Office;"
# From the checked-out pubspec, so the file names match the app inside them.
VERSION=$(grep '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//' | cut -d+ -f1)
OUT=build/dist
rm -rf "$OUT" && mkdir -p "$OUT"

case "${1:-}" in
linux)
  BUNDLE=build/linux/x64/release/bundle
  tar -czf "$OUT/$APP-$VERSION-linux-x64.tar.gz" -C "$(dirname "$BUNDLE")" \
    --transform "s,^bundle,$APP," bundle

  ROOT=$PWD/build/deb && rm -rf "$ROOT"
  mkdir -p "$ROOT/DEBIAN" "$ROOT/opt" "$ROOT/usr/bin" \
    "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/512x512/apps"
  cp -r "$BUNDLE" "$ROOT/opt/$APP"
  ln -s "/opt/$APP/$APP" "$ROOT/usr/bin/$APP"   # the engine resolves /proc/self/exe
  cp "$ICON" "$ROOT/usr/share/icons/hicolor/512x512/apps/$ID.png"
  # Named after APPLICATION_ID, which the runner also sets as the program name
  # (WM_CLASS), so docks match the window to this launcher on X11 and Wayland.
  cat > "$ROOT/usr/share/applications/$ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
Comment=$SUMMARY
Exec=$APP
Icon=$ID
Terminal=false
Categories=$CATEGORIES
StartupWMClass=$ID
EOF
  # Depends straight from the ELF files: right t64 package names, right glibc
  # floor (expect libc6, libgtk-3-0t64, libsecret-1-0, libglib2.0-0t64, ...).
  # dpkg-shlibdeps insists on a debian/control in its working directory.
  mkdir -p build/shlibs/debian && : > build/shlibs/debian/control
  DEPS=$(cd build/shlibs && dpkg-shlibdeps -O --ignore-missing-info \
    -l"$ROOT/opt/$APP/lib" "$ROOT/opt/$APP/$APP" "$ROOT/opt/$APP"/lib/*.so \
    | sed 's/^shlibs:Depends=//')
  cat > "$ROOT/DEBIAN/control" <<EOF
Package: $APP
Version: $VERSION
Architecture: amd64
Maintainer: ganeshapp <ganeshapp@users.noreply.github.com>
Depends: $DEPS
Description: $SUMMARY
EOF
  dpkg-deb --build --root-owner-group "$ROOT" "$OUT/$APP-$VERSION-linux-x64.deb"
  ;;
macos)
  BUNDLE="build/macos/Build/Products/Release/$NAME.app"
  lipo "$BUNDLE/Contents/MacOS/$NAME" -verify_arch x86_64 arm64   # universal
  codesign --verify --deep --strict "$BUNDLE"   # ad-hoc seal intact
  STAGE=build/dmg && rm -rf "$STAGE" && mkdir -p "$STAGE"
  ditto "$BUNDLE" "$STAGE/$NAME.app"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$NAME" -srcfolder "$STAGE" -format UDZO -ov \
    "$OUT/$APP-$VERSION-macos.dmg"
  ;;
*) echo "usage: $0 linux|macos" >&2; exit 2 ;;
esac
ls -l "$OUT"
