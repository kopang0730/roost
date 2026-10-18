# Changelog

## 1.0.0

首个可分发版本。

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
