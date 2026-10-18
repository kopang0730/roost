# 工作原理

这份文档说明 ExoLocal 在二进制/系统层面做了什么，方便二次开发或排错。

## 1. 组成

```
ExoLocal.app (SwiftUI, ~41 MB)
 ├─ Contents/Resources/epmulti          核心逻辑（Python 单文件）
 ├─ Contents/Resources/python/          内置 CPython 3.12（arm64，裁剪版）
 └─ Contents/Resources/helper/CookieJar.app   预编译的 cookie 写入器
```

界面通过 JSON-over-stdio 调 Python：

```
swift  →  /usr/bin/env python3  epmulti  api <verb>
          stdin: JSON 参数   stdout: 一行 JSON 结果   stderr: 实时日志
```

好处是业务逻辑只有一份，CLI、GUI、原生界面共用。

## 2. 多开：为什么需要副本

Roblox.app 的 `Info.plist` 里有 `LSMultipleInstancesProhibited = true`，同一 bundle id 只能跑一个实例。
所以每个账号一份副本：

1. `cp -cR`（APFS clonefile，写时复制，几乎不占额外空间）
2. `CFBundleIdentifier` → `com.roblox.RobloxPlayer.ep<sha1(name)[:8]>`
3. `LSMultipleInstancesProhibited` → `false`
4. 写入该账号的 FFlags
5. `codesign --force --deep -s -`（ad-hoc 重签，约 2 秒）

副本路径：`~/Library/Application Support/epmulti/instances/<slug>/Roblox.app`。
Roblox 版本变了（比对 `CFBundleVersion`）会自动重建。

## 3. 会话怎么进去

Roblox 客户端从 `~/Library/HTTPStorages/<bundle-id>.binarycookies` 读会话。
`binarycookies` 的页头/偏移表/尾部 bplist 格式很碎，手写极易写坏，所以：

- 编一个 ~100 KB 的 `CookieJar.app`（Objective-C，`NSHTTPCookieStorage setCookie:`）
- 把它的 `CFBundleIdentifier` 改成目标副本的 id 并重签
- 运行它 → **CFNetwork 自己**把 cookie 写进 `~/Library/HTTPStorages/<副本 bid>.binarycookies`

写出来的文件就是 CFNetwork 的产物，副本一定认识。实测写入 987 字符 → 读回 987 字符。

## 4. 登录怎么拿到的

`LoginPanel` 里是一个 `WKWebView`：

- `WKWebsiteDataStore.nonPersistent()`：每次添加都是干净环境，关窗即销毁，不残留上一个号的会话
- 自定义 UA 伪装成普通 Safari
- 每 0.8 秒 `httpCookieStore.getAllCookies` 找 `.ROBLOSECURITY`（HttpOnly 也读得到）
- 抓到后交给 Python：`users.roblox.com/v1/users/authenticated` 拿用户名 → 自动命名 → 写 Keychain

同一个 Roblox 账号重复添加会按 `user_id` 去重，变成"刷新会话"。

## 5. 启动：票据 + 深链

```
POST https://auth.roblox.com/v1/authentication-ticket/
  Cookie: .ROBLOSECURITY=...
  Referer / Origin: https://www.roblox.com
  body: {}
403 时用响应头 x-csrf-token 重试一次

→ 取响应头 rbx-authentication-ticket
→ 拼深链：
  roblox-player:1+launchmode:play+gameinfo:<票>+launchtime:<ms>
  +placelauncherurl:<PlaceLauncher.ashx?...>&browsertrackerid:<id>
  +robloxLocale:en_us+gameLocale:en_us
→ open -n -a <副本> <深链>
```

## 6. FFlags 写在哪

副本内的 `Contents/Resources/ClientSettings/ClientAppSettings.json`（Roblox 官方读取位置）。
写完重新 ad-hoc 签名，避免签名与资源不一致。

帧率用 `DFIntTaskSchedulerTargetFps` 写进副本，**不动**全局 `GlobalBasicSettings_13.xml`，
所以不会影响你自己正常开的 Roblox。

## 7. 状态与凭据

| 内容 | 位置 |
|---|---|
| 会话串 | Keychain，`svce=epmulti`，`acct=<账号名>` |
| 账号元数据 / FFlags / prefs | `~/Library/Application Support/epmulti/state.json` |
| 副本 | `~/Library/Application Support/epmulti/instances/<slug>/` |
| 副本 cookie | `~/Library/HTTPStorages/com.roblox.RobloxPlayer.ep<slug>.binarycookies` |
| 头像缓存 | `~/Library/Application Support/epmulti/avatars/<uid>.png` |

## 8. 分发

`make-dmg.sh` 把 app、`Applications` 快捷方式和说明文本装进 DMG（UDZO，约 21 MB）。

内置运行时解决了两件事：
- 朋友的 Mac 不用装 Xcode 命令行工具（内置 Python）
- 不用 clang 现场编译（helper 预编译进包）

未解决：没有 Developer ID 证书 → 不能公证 → 首次打开要手动放行。
