# Roost

**本地 Roblox 多开器** — 内嵌官方登录、多账号隔离、逐号 FFlag、窗口预览。
纯本地运行，没有账号体系，不联网校验授权。

📦 [下载最新版本](../../releases/latest) · 📖 [工作原理](docs/ARCHITECTURE.md) · 📝 [更新日志](CHANGELOG.md)

> 非官方工具，与 Roblox Corporation 无关联。多开属于 Roblox 不鼓励的行为，风险自负。

---

## 下载安装

1. 到 [Releases](../../releases/latest) 下载 `Roost-x.y.z.dmg`
2. 打开 DMG，把 `Roost.app` 拖进 `Applications`
3. **第一次打开会被系统拦**（本仓库没有 Apple 开发者签名），任选一种：
   - 在「应用程序」里右键 → 打开 → 再点「打开」
   - 或终端执行 `xattr -dr com.apple.quarantine /Applications/Roost.app`
   - 或 系统设置 → 隐私与安全性 → 底部「仍要打开」

**要求**：macOS 13+，Apple 芯片（M1/M2/M3/M4）。Intel Mac 暂不支持。

---

## 能做什么

| | |
|---|---|
| **内嵌登录** | 点 `+` 直接弹出 Roblox 官方登录页，登录完（含两步验证）自动抓取会话入库，不用找 cookie |
| **多开** | 每个账号一份 APFS 副本，独立 bundle id、独立 cookie 库、独立设置 |
| **账号管理** | 右键：启动 / 检查登录 / 重命名 / 在 Finder 显示 / 删除 |
| **FFlags** | 9 项中文预设（MSAA、纹理、光照、帧率、渲染分辨率、灰天空、去草、最低画质、DPI）+ 手写 |
| **每号配置** | placeId / 窗口尺寸 / fps 跟着账号保存 |
| **实例管理** | 运行中标记、逐个停止、全部关闭 |
| **窗口预览** | 每个运行实例的实时缩略图（需要屏幕录制权限） |
| **版本检测** | 对比本机 Roblox 与官方最新版本 |
| **游戏名** | placeId 自动解析成游戏名 |
| **外观** | 中英双语、浅色/深色/跟随系统、5 种强调色、菜单栏常驻、悬停提示 |

---

## 怎么用

```
1. 点工具栏 +  →  在弹出的窗口里正常登录 Roblox
2. 登录完成 → 自动添加账号，窗口自动关闭
3. 选中账号 → 填 placeId（可留空只开首页）、窗口尺寸、fps
4. 点「启动」；多开就逐个启动，或「全部启动」
```

想看每个窗口在干什么：点工具栏「预览」（首次会要求屏幕录制权限）。

---

## 隐私

- 会话存在 **macOS 钥匙串**（`svce=epmulti`），账号元数据在 `~/Library/Application Support/epmulti`
- 没有 Roost 账号，没有服务器，不上传任何数据
- 登录页就是 Roblox 官方页面，密码不经过本程序

---

## 开发

```
roost                    # 核心逻辑：账号 / 多开 / 会话 / FFlag / JSON API（Python）
app/
  Roost/*.swift       # SwiftUI 界面
  build.sh               # 编译 + 打包 + 签名
  make-dmg.sh            # 出 DMG
  make_icon.swift        # 现场画图标
scripts/fetch-python.sh  # 拉取内置 Python 运行时（裁剪版）
.github/workflows/       # 打 tag 自动构建并发 Release
```

本地构建：

```bash
./scripts/fetch-python.sh     # 只需一次，约 25 MB 下载
cd app && ./build.sh          # 编译 + 打包 + 签名
./make-dmg.sh 1.0.0           # → app/build/Roost-1.0.0.dmg
```

> 构建产物默认放在 `$TMPDIR/roost-build/`（路径会写进 `app/build/app-path.txt`），
> 不放在仓库里。因为仓库常在 iCloud Drive 下，fileprovider 会反复给 `.app` 写
> `com.apple.FinderInfo`，导致 `codesign --deep --strict` 校验失败。
> 想改目录：`ROOST_BUILD_DIR=/some/path ./build.sh`。

命令行直接用（不装 app 也行）：

```bash
./roost doctor
./roost accounts add --name main --from-local
./roost launch main --place 13127800756 --fps 60
```

架构细节（克隆、改 bundle id、cookie 注入、票据交换、FFlag 路径）见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

---

## 发布新版本（维护者）

```bash
# 1. 改 CHANGELOG.md，提交
git commit -am "release 1.0.1"

# 2. 打 tag 并推送，GitHub Actions 会自动构建 DMG 并创建 Release
git tag v1.0.1
git push origin main --tags
```

Workflow 会跑：拉取内置 Python → 编译 → 打 DMG → 自检签名与挂载 → 上传 Release 附件。
也可以在 Actions 页面手动 `workflow_dispatch` 输版本号构建（不会自动发 Release）。

## 已知限制

- 未公证（ad-hoc 签名），首次打开需要手动放行
- 仅 arm64；Intel Mac 需要自行编译
- 窗口尺寸/排列需要「辅助功能」权限；预览需要「屏幕录制」权限
- 不做宏录制/回放（刻意没有实现）
- 不包含任何绕过 Roblox 风控的功能

## 免责声明

本项目仅用于在**你自己的电脑**上管理**你自己的** Roblox 账号。使用多开、自动化可能违反
Roblox 服务条款，由此产生的账号风险由使用者承担。作者不对任何封号、数据丢失负责。

## License

[MIT](LICENSE)。内置的 CPython 运行时遵循 PSF License，详见 [NOTICE](NOTICE)。
