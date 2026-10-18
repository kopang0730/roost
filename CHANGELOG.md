# Changelog

## 1.0.2

### 新增
- **权限引导**：首次需要调整窗口时，详情页会出现橙色提示条，点「去授权」会
  通过 `AXIsProcessTrustedWithOptions` 让 Roost 以自己的图标出现在系统设置的列表里，
  并直接打开对应的隐私面板；设置里新增「系统权限」区块，可随时查看/跳转

### 修复
- 之前窗口操作走 `osascript`，系统把权限算在 `osascript` 头上，Roost 不出现在列表——现在主动注册

## 1.0.1

### 新增
- **一键修复 / 更新 Roblox**：检测到本机版本落后（或 Roblox 缺失）时，直接下载官方 150 MB 包并替换 `/Applications/Roblox.app`，带进度；装完自动重新检查版本
- **窗口聚焦**：右键账号 →「聚焦窗口」，把该实例提到最前
- **一键平铺**：工具栏「平铺」，把所有运行中的实例重新铺成网格
- **应用内检查更新**：启动时读 GitHub Releases，有新版本就在详情页顶部提示并给下载链接

### 文档
- README 分为英文（默认）与简体中文，顶部可切换；架构文档同样双语

## 1.0.0

首个可分发版本。项目更名为 **Roost**（原 ExoLocal）。

- 应用名 `Roost.app`，bundle id `com.roost.app`
- 命令行入口 `roost`（README 里的 `./roost`）
- 内部存储路径与 Keychain 服务仍沿用 `epmulti`，老账号不受影响

### 功能
- 内嵌 Roblox 官方登录页，登录完成自动抓取会话并入库，无需手动找 cookie
- 多开：每个账号一份 APFS clonefile 副本，独立 bundle id，ad-hoc 重签
- 会话存 macOS 钥匙串（`svce=epmulti`），账号元数据存 `~/Library/Application Support/epmulti`
- 账号管理：重命名（自动迁移 Keychain / cookie 库 / 副本 bundle id）、删除、右键菜单
- FFlag 预设 9 项（中文/英文），支持手写、一键性能优先、恢复默认
- 每账号记住 placeId / 窗口尺寸 / fps，启动自动带出
- 运行中实例检测、逐个停止、全部关闭
- 窗口实时预览（ScreenCaptureKit，需要屏幕录制权限）
- Roblox 版本检测（对比官方最新版本）
- placeId → 游戏名解析（带缓存）
- 中英文界面切换、浅色/深色/跟随系统、5 种强调色
- 菜单栏常驻、悬停提示、窗口自动排列

### 分发
- DMG 打包脚本，内置 Python 运行时与预编译 cookie 助手
- GitHub Actions：打 tag 自动构建并发布 DMG
