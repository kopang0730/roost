**English** · [简体中文](README.zh-CN.md)

# Roost

**A local multi-instance launcher for Roblox** — embedded official sign-in, per-account
isolation, per-account FFlags, live window previews.
Runs entirely on your Mac: no account system, no servers, no licensing checks.

📦 [Download](../../releases/latest) · 📖 [How it works](docs/ARCHITECTURE.md) · 📝 [Changelog](CHANGELOG.md)

> Unofficial tool, not affiliated with Roblox Corporation. Multi-instancing is not endorsed
> by Roblox — use at your own risk.

---

## Install

1. Download `Roost-x.y.z.dmg` from [Releases](../../releases/latest)
2. Open the DMG and drag `Roost.app` into `Applications`
3. **The first launch is blocked by macOS** (this repo has no Apple Developer signature).
   Pick one:
   - In Applications, right-click → Open → Open again
   - Or run `xattr -dr com.apple.quarantine /Applications/Roost.app`
   - Or System Settings → Privacy & Security → "Open Anyway"

**Requirements**: macOS 13+, Apple Silicon (M1/M2/M3/M4). Intel Macs are not supported yet.

---

## What it does

| | |
|---|---|
| **Embedded sign-in** | Click `+`, sign in on Roblox's own page (2FA works); the session is captured and added automatically — no cookie hunting |
| **Multi-instance** | One APFS clone per account, with its own bundle id, cookie store and settings |
| **Account management** | Right-click: launch / check login / rename / reveal in Finder / delete |
| **FFlags** | 9 presets (MSAA, textures, lighting, FPS cap, render resolution, gray sky, no grass, lowest quality, DPI) plus raw editing |
| **Per-account config** | placeId / window size / fps are stored with the account |
| **Instance management** | Running indicator, stop one, stop all |
| **Window previews** | Live thumbnails of every running instance (needs Screen Recording) |
| **Version check** | Compares your local Roblox with the latest official build |
| **Game names** | placeId is resolved to a game name |
| **Appearance** | English/Chinese UI, light/dark/system, 5 accent colors, menu bar extra, hover hints |

---

## Getting started

The first launch opens a setup checklist for Accessibility, Screen Recording, and Automation (System Events / Finder). Open each permission page and enable Roost. A floating assistant appears below System Settings with a draggable app icon for supported permission lists. You can also set up later. Finishing setup plays a short celebration, followed by a six-step spotlight tour. Skip the tour any time, or replay it from Settings → Onboarding.

```
1. Click + in the toolbar → sign in to Roblox in the window
2. Once signed in, the account is added automatically and the window closes
3. Select the account → set placeId (leave empty for the home screen), window size, fps
4. Click Launch — or "Launch all" for every account
```

To see what each window is doing, click **Preview** (Screen Recording permission is asked once).

---

## Privacy

- Sessions live in the **macOS Keychain** (`svce=epmulti`); metadata in `~/Library/Application Support/epmulti`
- No Roost account, no server, nothing uploaded
- The sign-in page is Roblox's own; your password never passes through this app

---

## Development

```
roost                     # core logic: accounts / clones / sessions / FFlags / JSON API (Python)
app/
  Roost/*.swift           # SwiftUI UI
  build.sh                # compile + bundle + sign
  make-dmg.sh             # produce a DMG
  make_icon.swift         # draws the icon
scripts/fetch-python.sh   # fetch the bundled Python runtime (trimmed)
.github/workflows/        # tag → build → publish Release
```

Build locally:

```bash
./scripts/fetch-python.sh     # once, ~25 MB download
cd app && ./build.sh          # compile + bundle + sign
./make-dmg.sh 1.0.0           # → app/build/Roost-1.0.0.dmg
```

> The app is built into `$TMPDIR/roost-build/` (path written to `app/build/app-path.txt`)
> rather than into the repo: when the checkout lives in iCloud Drive, fileprovider keeps
> re-adding `com.apple.FinderInfo` to the `.app`, which breaks `codesign --deep --strict`.
> Override with `ROOST_BUILD_DIR=/some/path ./build.sh`.

Use the CLI directly (no app needed):

```bash
./roost doctor
./roost accounts add --name main --from-local
./roost launch main --place 13127800756 --fps 60
```

How cloning, bundle ids, cookie injection, ticket exchange and FFlags work:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Releasing (maintainers)

```bash
# 1. 写发布说明 docs/release-notes/v1.0.1.md，更新 CHANGELOG.md，提交
git commit -am "release 1.0.1"

# 2. tag and push — GitHub Actions builds the DMG and creates the Release
git tag v1.0.1
git push origin main --tags
```

The workflow fetches the bundled Python, builds, packages the DMG, verifies the signature and
the mount, then publishes the asset with the notes from `docs/release-notes/vX.Y.Z.md`
(falling back to auto-generated notes if that file is missing). You can also trigger it manually from the Actions tab
(`workflow_dispatch`) — that builds artifacts without creating a Release.

## Known limitations

- Not notarized (ad-hoc signature): first launch needs a manual bypass
- arm64 only; Intel Macs must build from source
- Window size / auto-arrange need Accessibility; previews need Screen Recording
- No macro recording/playback (intentionally out of scope)
- Contains no anti-detection or ban-evasion functionality

## Disclaimer

This project is meant for managing **your own** Roblox accounts on **your own** machine.
Multi-instancing and automation may violate Roblox's Terms of Service; any account risk is
yours. The authors are not responsible for bans or data loss.

## License

[MIT](LICENSE). The bundled CPython runtime is under the PSF License — see [NOTICE](NOTICE).
