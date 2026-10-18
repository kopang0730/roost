# How it works

What Roost does at the binary / system level — useful for contributing or debugging.

## 1. Pieces

```
Roost.app (SwiftUI, ~41 MB)
 ├─ Contents/Resources/roost                core logic (single-file Python)
 ├─ Contents/Resources/python/              bundled CPython 3.12 (arm64, trimmed)
 └─ Contents/Resources/helper/CookieJar.app prebuilt cookie writer
```

The UI talks to Python over JSON-on-stdio:

```
swift  →  /usr/bin/env python3  roost  api <verb>
          stdin: JSON args   stdout: one JSON line   stderr: live log
```

One implementation, shared by the CLI, the native UI and the optional browser UI.

## 2. Multi-instance: why clones

`Roblox.app/Contents/Info.plist` sets `LSMultipleInstancesProhibited = true`, so a single
bundle id can only run once. Each account therefore gets its own copy:

1. `cp -cR` — APFS clonefile, copy-on-write, essentially free on disk
2. `CFBundleIdentifier` → `com.roblox.RobloxPlayer.ep<sha1(name)[:8]>`
3. `LSMultipleInstancesProhibited` → `false`
4. write that account's FFlags
5. `codesign --force --deep -s -` — ad-hoc re-sign, about 2 seconds

Clones live in `~/Library/Application Support/epmulti/instances/<slug>/Roblox.app`
and are rebuilt automatically when the installed Roblox `CFBundleVersion` changes.

## 3. How the session gets in

The Roblox client reads its session from `~/Library/HTTPStorages/<bundle-id>.binarycookies`.
That file's page headers, offset tables and trailing bplist are fiddly; a hand-written file
is easy to corrupt. So Roost does this instead:

- builds a ~100 KB `CookieJar.app` (Objective-C, `NSHTTPCookieStorage setCookie:`)
- rewrites its `CFBundleIdentifier` to the target clone's id and re-signs it
- runs it — **CFNetwork itself** writes `~/Library/HTTPStorages/<clone bid>.binarycookies`

The file is produced by CFNetwork, so the clone always understands it.
Measured: 987 chars written, 987 read back.

## 4. Where the login comes from

`LoginPanel` hosts a `WKWebView`:

- `WKWebsiteDataStore.nonPersistent()` — every add starts clean, destroyed on close,
  no leftover session from the previous account
- custom user agent posing as regular Safari
- every 0.8 s, `httpCookieStore.getAllCookies` looks for `.ROBLOSECURITY` (HttpOnly included)
- on capture, Python calls `users.roblox.com/v1/users/authenticated` for the username,
  names the account, and stores the session in the Keychain

Re-adding the same Roblox account dedupes by `user_id` and refreshes the session instead.

## 5. Launching: ticket + deep link

```
POST https://auth.roblox.com/v1/authentication-ticket/
  Cookie: .ROBLOSECURITY=...
  Referer / Origin: https://www.roblox.com
  body: {}
retry once with x-csrf-token from the 403 response

→ read rbx-authentication-ticket from the response headers
→ build the deep link:
  roblox-player:1+launchmode:play+gameinfo:<ticket>+launchtime:<ms>
  +placelauncherurl:<PlaceLauncher.ashx?...>&browsertrackerid:<id>
  +robloxLocale:en_us+gameLocale:en_us
→ open -n -a <clone> <deep link>
```

## 6. Where FFlags live

`Contents/Resources/ClientSettings/ClientAppSettings.json` inside the clone — the location
Roblox itself reads. The bundle is re-signed afterwards so signature and resources agree.

Frame rate is written as `DFIntTaskSchedulerTargetFps` into the clone and **never** touches
the global `GlobalBasicSettings_13.xml`, so your own Roblox install is unaffected.

## 7. State and credentials

> Internal paths still use `epmulti` for historical reasons; everything user-facing is Roost.
> That is why renaming the app does not orphan existing accounts.

| Data | Location |
|---|---|
| Session string | Keychain, `svce=epmulti`, `acct=<account name>` |
| Account metadata / FFlags / prefs | `~/Library/Application Support/epmulti/state.json` |
| Clones | `~/Library/Application Support/epmulti/instances/<slug>/` |
| Clone cookies | `~/Library/HTTPStorages/com.roblox.RobloxPlayer.ep<slug>.binarycookies` |
| Avatar cache | `~/Library/Application Support/epmulti/avatars/<uid>.png` |

## 8. Distribution

`make-dmg.sh` packs the app, an `Applications` symlink and the bilingual first-run notes
into a UDZO DMG (~21 MB).

The bundled runtime solves two problems:
- users do not need Xcode Command Line Tools (Python is inside the app)
- no clang at runtime (the cookie helper is prebuilt into the bundle)

Unresolved: no Developer ID certificate → no notarization → users must bypass Gatekeeper once.

> Build output deliberately goes to `$TMPDIR/roost-build/`, not the repo: when the checkout
> lives in iCloud Drive, fileprovider keeps re-adding `com.apple.FinderInfo` to the `.app`,
> which makes `codesign --deep --strict` fail.
