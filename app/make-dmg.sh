#!/bin/bash
# 打包成可分发的 DMG（ad-hoc 签名，未公证）
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-${VERSION:-1.0.0}}"
export VERSION
DMG="$HERE/build/Roost-$VERSION.dmg"
mkdir -p "$HERE/build"

"$HERE/build.sh"
echo "▸ 组装 DMG 内容"
STAGE="$(mktemp -d)"
APP_PATH="$(cat "$HERE/build/app-path.txt")"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/第一次打开看这里（中文）.txt" <<'TXT'
Roost —— 本地 Roblox 多开器
==============================

安装
----
把 Roost.app 拖到右边的 Applications 文件夹里。

第一次打开会被系统拦住（这个 app 没有苹果开发者签名）
--------------------------------------------------------
出现「无法打开，因为无法验证开发者」时，任选一种：

  1) 在「应用程序」里右键 Roost.app → 打开 → 再点「打开」
  2) 或者打开「终端」，执行：
       xattr -dr com.apple.quarantine /Applications/Roost.app
     然后再双击打开

  系统设置 → 隐私与安全性 → 底部「仍要打开」也可以。

使用
----
1. 点右上角 + ，在弹出的窗口里正常登录 Roblox（支持两步验证）
2. 登录完会自动添加账号
3. 需要多开时，设置好 placeId / 窗口大小 / fps，点「启动」
4. 想看每个窗口的画面，点「预览」（首次会要求「屏幕录制」权限）
5. 窗口大小/自动排列需要「辅助功能」权限（系统设置 → 隐私与安全性）

要求
----
- macOS 13 或更新
- Apple 芯片（M1/M2/M3/M4）。Intel Mac 暂不支持。
- 首次启动会在 ~/Library/Application Support/epmulti 建立配置目录

说明
----
- 会话保存在 macOS 钥匙串（svce=epmulti），不会上传到任何地方
- 不联网校验授权，没有账号体系，纯本地工具
- 多开属于 Roblox 不鼓励的行为，使用风险自负
TXT

cat > "$STAGE/Read me first (English).txt" <<'TXT'
Roost — a local Roblox multi-instance launcher
==============================================

Install
-------
Drag Roost.app into the Applications folder on the right.

First launch will be blocked by macOS (this app is not notarized)
-----------------------------------------------------------------
If you see "cannot be opened because the developer cannot be verified",
choose one:

  1) In Applications, right-click Roost.app → Open → Open again
  2) Or open Terminal and run:
       xattr -dr com.apple.quarantine /Applications/Roost.app
  3) Or System Settings → Privacy & Security → "Open Anyway" at the bottom

Usage
-----
1. Click + in the toolbar, then sign in to Roblox in the window (2FA supported)
2. The account is added automatically once you are signed in
3. Set placeId / window size / fps, then click Launch
4. Click Preview to see live thumbnails of every running instance
   (requires Screen Recording permission the first time)
5. Window size and auto-arrange need Accessibility permission

Requirements
------------
- macOS 13 or later
- Apple Silicon (M1/M2/M3/M4). Intel Macs are not supported.
- First run creates ~/Library/Application Support/epmulti

Notes
-----
- Sessions live in the macOS Keychain (svce=epmulti) and are never uploaded
- No account system, no servers, no licensing checks — fully local
- Multi-instancing is not endorsed by Roblox; use at your own risk
- Source code and issue tracker: the GitHub repository for this project
TXT

rm -f "$DMG"
echo "▸ 生成 DMG"
hdiutil create -volname "Roost $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "✓ $DMG"
ls -lh "$DMG" | awk '{print "  体积: "$5}'
