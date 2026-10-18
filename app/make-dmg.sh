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
1. 首次打开按权限清单设置辅助功能、屏幕录制和自动化，也可选择稍后设置
2. 点「去授权」后，系统设置下方会浮出授权助手，可将 Roost 图标拖入支持的权限列表
3. 完成设置后播放烟花并进入六步教程；可跳过，在「设置 → 新手引导」重新播放
4. 点「添加账号」，在 Roblox 官方页面登录（支持两步验证），账号会自动加入
5. 设置 placeId / 窗口大小 / fps，点「启动」；工具栏「预览」查看运行中的窗口

升级后如权限开关已开启但 Roost 仍提示未授权，请在系统设置中移除旧 Roost 条目，
重新添加 /Applications/Roost.app 并授权。系统提示重新打开时，请按提示操作。

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
1. First launch shows Accessibility, Screen Recording and Automation setup; you can also set up later
2. Grant access opens System Settings with a floating helper; drag Roost into supported permission lists
3. Finishing setup plays a celebration and a six-step tour. Skip it or replay from Settings > Onboarding
4. Click Add account and sign in on Roblox's official page (2FA supported); the account is added automatically
5. Set placeId / window size / fps, then Launch. Preview shows running game windows

If an update leaves a permission enabled in macOS but unrecognized in Roost, remove the old Roost entry,
add /Applications/Roost.app again and grant access. Reopen the app when macOS asks.

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
# 不用 -srcfolder：在 CI runner 上会偶发 "Resource busy"。
# 改成：建空镜像 → 挂载 → 拷贝 → 卸载 → 压缩。
TMP_DMG="$(mktemp -d)/roost-tmp.dmg"
MNT="$(mktemp -d)"
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 40 ))
hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "Roost $VERSION" -ov "$TMP_DMG" >/dev/null
hdiutil attach "$TMP_DMG" -mountpoint "$MNT" -nobrowse -quiet
cp -R "$STAGE"/. "$MNT"/
sync
hdiutil detach "$MNT" -quiet
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG" >/dev/null
rm -rf "$STAGE" "$MNT" "$(dirname "$TMP_DMG")"
echo "✓ $DMG"
ls -lh "$DMG" | awk '{print "  体积: "$5}'
