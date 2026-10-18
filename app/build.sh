#!/bin/bash
# 构建 ExoLocal.app —— 原生 SwiftUI 前端，逻辑仍然走同目录的 epmulti
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
APP_NAME="ExoLocal"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD="$HERE/build"
BUNDLE="$BUILD/$APP_NAME.app"

echo "▸ 清理"
rm -rf "$BUILD"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "▸ 生成图标"
swift "$HERE/make_icon.swift" "$BUILD/icon-1024.png" >/dev/null
ICONSET="$BUILD/icon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s       "$BUILD/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png"     >/dev/null
  sips -z $((s*2)) $((s*2)) "$BUILD/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "▸ 编译 Swift"
swiftc -O -swift-version 5 \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI -framework AppKit -framework WebKit -framework ScreenCaptureKit \
  -o "$BUNDLE/Contents/MacOS/$APP_NAME" \
  "$HERE/ExoLocal/ExoLocalApp.swift" \
  "$HERE/ExoLocal/L10n.swift" \
  "$HERE/ExoLocal/Settings.swift" \
  "$HERE/ExoLocal/HoverHint.swift" \
  "$HERE/ExoLocal/LoginWeb.swift" \
  "$HERE/ExoLocal/Preview.swift" \
  "$HERE/ExoLocal/Py.swift" \
  "$HERE/ExoLocal/Avatar.swift" \
  "$HERE/ExoLocal/Store.swift" \
  "$HERE/ExoLocal/Presets.swift" \
  "$HERE/ExoLocal/Views.swift"

echo "▸ 打包"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ExoLocal</string>
  <key>CFBundleDisplayName</key><string>ExoLocal</string>
  <key>CFBundleIdentifier</key><string>com.epmulti.exolocal</string>
  <key>CFBundleExecutable</key><string>ExoLocal</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSQuitAlwaysKeepsWindows</key><false/>
  <key>NSWindowRestoresWorkspaceAtLaunch</key><false/>
  <key>NSHumanReadableCopyright</key><string>本地多开器 · 仅本机使用</string>
</dict></plist>
PLIST

cp "$ROOT/epmulti" "$BUNDLE/Contents/Resources/epmulti"
chmod +x "$BUNDLE/Contents/Resources/epmulti"

# 预编译 cookie 写入器，省掉对 clang 的依赖
"$ROOT/epmulti" api state >/dev/null 2>&1 || true
HELPER="$HOME/Library/Application Support/epmulti/bin/CookieJar.app"
if [ -d "$HELPER" ]; then
  echo "▸ 打包 cookie 助手"
  rm -rf "$BUNDLE/Contents/Resources/helper"
  mkdir -p "$BUNDLE/Contents/Resources/helper"
  cp -R "$HELPER" "$BUNDLE/Contents/Resources/helper/"
fi

# 内置 Python 运行时（arm64）：朋友的机器没装命令行工具也能跑
if [ -x "$HERE/vendor/python-arm64/bin/python3" ]; then
  echo "▸ 内置 Python 运行时"
  rm -rf "$BUNDLE/Contents/Resources/python"
  cp -R "$HERE/vendor/python-arm64" "$BUNDLE/Contents/Resources/python"
fi

echo "▸ 签名（ad-hoc）"
xattr -cr "$BUNDLE"
codesign --force --deep -s - "$BUNDLE" >/dev/null

echo "✓ 完成: $BUNDLE"
du -sh "$BUNDLE" | awk '{print "  体积: "$1}'
