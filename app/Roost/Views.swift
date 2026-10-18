import SwiftUI

// MARK: - 主窗口

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    @AppStorage("showLog") private var showLog = false
    @State private var showSettings = false
    @State private var renameTarget: Account? = nil
    @State private var deleteTarget: Account? = nil
    @State private var showPreview = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    store.refresh()
                } label: {
                    Label(L.t("刷新", "Refresh"), systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("重新读取账号与运行环境", "Reload accounts and environment")))
                .hoverHint(L.t("重新读取账号与运行环境（⌘R）", "Reload accounts and environment (⌘R)"), store)

                Button {
                    showAdd = true
                } label: {
                    Label(L.t("添加账号", "Add account"), systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("添加一个 Roblox 账号", "Add a Roblox account")))
                .hoverHint(L.t("添加一个 Roblox 账号：粘贴会话串，或用本机已登录的会话", "Add a Roblox account: paste a session string or use the local session"), store)

                Button {
                    store.launchAll()
                } label: {
                    Label(L.t("全部启动", "Launch all"), systemImage: "play.square.stack")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("按当前 placeId / 尺寸 / fps 启动所有账号", "Launch every account with the current placeId / size / fps")))
                .hoverHint(L.t("用当前 placeId / 窗口尺寸 / fps 启动所有账号", "Launch every account with the current placeId / size / fps"), store)
                .disabled(store.accounts.isEmpty || store.busy != nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.tileWindows()
                } label: {
                    Label(L.t("平铺", "Tile"), systemImage: "rectangle.split.3x1")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("把所有运行中的窗口重新排开", "Re-arrange every running window")))
                .hoverHint(L.t("把运行中的实例重新铺成网格（需要辅助功能权限）", "Lay out running instances in a grid (needs Accessibility permission)"), store)
                .disabled(store.running.isEmpty || store.busy != nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showPreview = true
                } label: {
                    Label(L.t("预览", "Preview"), systemImage: "rectangle.inset.filled.and.person.filled")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("看每个运行中窗口的画面", "See every running window")))
                .hoverHint(L.t("实时缩略图：每个运行中的实例一屏看全（需要屏幕录制权限）", "Live thumbnails of every running instance (needs Screen Recording permission)"), store)
                .disabled(store.running.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label(L.t("设置", "Settings"), systemImage: "gearshape")
                        .labelStyle(.titleAndIcon)
                }
                .help(Text(L.t("语言、外观、强调色", "Language, appearance, accent color")))
                .hoverHint(L.t("设置：语言 / 外观 / 强调色 / 日志面板", "Settings: language, appearance, accent color, log panel"), store)
            }
            ToolbarItem(placement: .status) {
                HStack(spacing: 8) {
                    if let b = store.busy {
                        ProgressView().controlSize(.small)
                        Text(b).font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        withAnimation { showLog.toggle() }
                    } label: {
                        Label(L.t("日志", "Log"), systemImage: "terminal")
                            .labelStyle(.titleAndIcon)
                    }
                    .help(Text(L.t("显示 / 隐藏输出", "Show / hide output")))
                    .hoverHint(L.t("展开 / 收起底部输出面板", "Show / hide the bottom output panel"), store)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            PreviewSheet().environmentObject(store)
        }
        .sheet(item: $renameTarget) { acct in
            RenameSheet(account: acct).environmentObject(store)
        }
        .confirmationDialog(
            L.t("删除 \(deleteTarget?.name ?? "")？会话与副本都会一起删掉。",
                "Delete \(deleteTarget?.name ?? "")? Its session and copy will be removed."),
            isPresented: Binding(get: { deleteTarget != nil },
                                 set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button(L.t("删除", "Delete"), role: .destructive) {
                if let t = deleteTarget { store.remove(t.name) }
                deleteTarget = nil
            }
            Button(L.t("取消", "Cancel"), role: .cancel) { deleteTarget = nil }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAdd) {
            AddAccountView().environmentObject(store)
        }
        .safeAreaInset(edge: .bottom) {
            if showLog { LogPane().environmentObject(store) }
        }
        .overlay(alignment: .bottom) {
            HoverHintBar(text: store.hoverHint).padding(.bottom, 16)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshPermissions()
        }
        .onAppear {
            store.refreshPermissions()
            store.noteLanguageChange()
            if ProcessInfo.processInfo.environment["ROOST_OPEN_ADD"] == "1" { showAdd = true }
        }
    }

    // MARK: 侧栏

    private var sidebar: some View {
        List(selection: $store.selected) {
            Section(L.t("账号", "Accounts")) {
                ForEach(store.accounts) { a in
                    AccountRow(account: a, avatar: store.avatars[a.userID ?? -1],
                               running: store.isRunning(a.name))
                        .tag(a.name)
                        .contextMenu {
                            Button(L.t("启动", "Launch")) { store.selected = a.name; store.launch(a.name) }
                            Button(L.t("聚焦窗口", "Focus window")) {
                                store.selected = a.name
                                store.focus(a.name)
                            }
                            .disabled(!store.isRunning(a.name))
                            Button(L.t("检查登录", "Check login")) { store.selected = a.name; store.check(a.name) }
                            Divider()
                            Button(L.t("重命名…", "Rename…")) { store.selected = a.name; renameTarget = a }
                            Button(L.t("在 Finder 中显示", "Reveal in Finder")) { store.selected = a.name; store.reveal(a.name) }
                            Divider()
                            Button(L.t("删除账号…", "Delete account…"), role: .destructive) {
                                store.selected = a.name
                                deleteTarget = a
                            }
                        }
                        .hoverHint("\(a.name) · \(a.username ?? "?") · \(a.uidText) · "
                                   + (a.instanceReady ? L.t("副本已就绪，点一下看详情", "copy ready — click for details")
                                                      : L.t("副本未创建，首次启动会自动准备", "no copy yet — created on first launch")),
                                   store)
                }
            }
            if store.accounts.isEmpty {
                Text(L.t("还没有账号", "No accounts yet")).font(.callout).foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: store.status.localSession ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(store.status.localSession ? .green : .red)
                    Text(store.status.localSession
                         ? L.t("本机会话 \(store.status.localSessionLen) 字符", "Local session: \(store.status.localSessionLen) chars")
                         : L.t("本机无 Roblox 会话", "No local Roblox session"))
                        .font(.caption)
                }
                Text(L.t("Roblox \(store.status.robloxVersion) · 副本 \(store.accounts.filter { $0.instanceReady }.count)/\(store.accounts.count)", "Roblox \(store.status.robloxVersion) · copies \(store.accounts.filter { $0.instanceReady }.count)/\(store.accounts.count)"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.bottom, 10)
        }
    }

    // MARK: 详情

    @ViewBuilder
    private var detail: some View {
        if let acct = store.current {
            AccountDetail(account: acct).id(acct.name)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(L.t("从右上角 + 添加一个 Roblox 账号", "Use + in the toolbar to add a Roblox account")).foregroundStyle(.secondary)
                if store.status.localSession {
                    Button(L.t("用本机会话快速添加", "Quick add from local session")) { showAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 侧栏行

struct AccountRow: View {
    let account: Account
    var avatar: NSImage?
    var running: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            avatarView(size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.name).font(.system(size: 13, weight: .medium))
                Text("\(account.username ?? "?") · \(account.uidText)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if account.instanceReady {
                Image(systemName: "shippingbox.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                    .help(Text(L.t("副本已就绪", "Copy ready")))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func avatarView(size: CGFloat) -> some View {
        if let img = avatar {
            Image(nsImage: img)
                .resizable().interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(LinearGradient(colors: [.accentColor.opacity(0.85), .blue.opacity(0.55)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(account.username?.prefix(1) ?? "?").uppercased())
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - 账号详情

struct AccountDetail: View {
    @EnvironmentObject var store: Store
    let account: Account
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !store.axOK && store.dismissedPerm != "ax" {
                    PermissionBanner(kind: .accessibility)
                }
                if let u = store.appUpdate { appUpdateBanner(u) }
                if let v = store.versionInfo, v.update || v.error != nil {
                    versionBanner(v)
                }
                launchBox
                PresetSection(account: account)
                RawFlagsEditor(account: account)
                maintenanceBox
            }
            .padding(20)
        }
        .confirmationDialog(L.t("删除 \(account.name)？会话与副本都会一起删掉。", "Delete \(account.name)? Its session and copy will be removed."),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L.t("删除", "Delete"), role: .destructive) { store.remove(account.name) }
        }
    }

    private var launchBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L.t("启动", "Launch")).font(.headline)
                    if store.isRunning(account.name) {
                        Text(L.t("运行中", "Running")).font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if store.isRunning(account.name) {
                        Button(role: .destructive) {
                            store.stop(account.name)
                        } label: {
                            Label(L.t("停止", "Stop"), systemImage: "stop.fill")
                        }
                        .help(Text(L.t("关闭这个账号的窗口", "Close this account's windows")))
                        .hoverHint(L.t("结束这个账号的所有副本进程", "Terminate every clone process of this account"), store)
                        .disabled(store.busy != nil)
                    }
                    Button {
                        store.launch(account.name)
                    } label: {
                        Label(L.t("启动", "Launch"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .help(Text(L.t("启动这个账号", "Launch this account")))
                    .hoverHint(L.t("启动这个账号（会先注入会话、再开窗口）", "Launch this account: inject session, then open the window"), store)
                    .disabled(store.busy != nil)
                }
                HStack(spacing: 10) {
                    LabeledField(title: "placeId", text: $store.place, width: 150)
                    LabeledField(title: L.t("窗口", "Window"), text: $store.size, width: 120)
                    LabeledField(title: "fps", text: $store.fps, width: 80)
                }
                Toggle(L.t("启动后自动排列窗口", "Auto-arrange windows on launch"), isOn: $store.snap)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help(Text(L.t("按网格/层叠摆放新窗口", "Tile or cascade new windows")))
                    .hoverHint(L.t("多开时自动把窗口排开，避免完全重叠", "Automatically arrange windows so they don't fully overlap"), store)
                Text(L.t("placeId 留空 = 只打开客户端首页；尺寸与排列需要“辅助功能”权限才会生效。", "Leave placeId empty to open the client home. Size & layout need Accessibility permission."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private var maintenanceBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("维护", "Maintenance")).font(.headline)
                HStack(spacing: 10) {
                    Button {
                        store.check(account.name)
                    } label: { Label(L.t("检查登录", "Check login"), systemImage: "checkmark.shield") }
                        .help(Text(L.t("用保存的登录态问一下 Roblox 还能不能登录", "Ask Roblox whether the saved session still works")))
                        .hoverHint(L.t("用保存的登录态向 Roblox 确认还能不能登录，顺手换一次启动票据；不会启动游戏", "Checks with Roblox whether the saved session still works and mints a launch ticket — does not launch the game"), store)
                        .disabled(store.busy != nil)

                    Button {
                        store.repair()
                    } label: { Label(L.t("修复 Roblox", "Repair Roblox"), systemImage: "arrow.down.circle") }
                        .help(Text(L.t("下载并安装官方 Roblox 客户端", "Download and install the official Roblox client")))
                        .hoverHint(L.t("下载官方 Roblox（约 150 MB）并替换 /Applications 里的版本；需要先退出所有实例",
                                       "Download the official Roblox (~150 MB) and replace the one in /Applications; quit all instances first"), store)
                        .disabled(store.busy != nil)

                    Button {
                        store.openInstances()
                    } label: { Label(L.t("副本目录", "Copies folder"), systemImage: "folder") }
                        .help(Text(L.t("在 Finder 打开副本目录", "Open the copies folder in Finder")))
                        .hoverHint(L.t("在 Finder 里打开每个账号的 Roblox 副本", "Open the per-account Roblox copies in Finder"), store)
                        .disabled(store.busy != nil)

                    Spacer()

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: { Label(L.t("删除账号", "Delete account"), systemImage: "trash") }
                        .help(Text(L.t("删除账号、会话与副本", "Delete the account, session and copy")))
                        .hoverHint(L.t("删除这个账号：会话、副本、配置一起清掉", "Delete this account: session, copy and settings"), store)
                        .disabled(store.busy != nil)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private func appUpdateBanner(_ u: UpdateInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("Roost \(u.latest) 已发布", "Roost \(u.latest) is available")).font(.caption)
                Text(L.t("去 Releases 下载新的 DMG 覆盖安装即可，账号数据不受影响。",
                         "Download the new DMG from Releases and replace the app — your accounts stay."))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L.t("打开下载页", "Open release")) {
                if let url = URL(string: u.url) { NSWorkspace.shared.open(url) }
            }
            .controlSize(.small)
            Button {
                store.appUpdate = nil
            } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.blue.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func versionBanner(_ v: VersionInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: v.error != nil ? "wifi.exclamationmark" : "arrow.down.circle")
                .foregroundStyle(v.error != nil ? .orange : .yellow)
            VStack(alignment: .leading, spacing: 2) {
                if let e = v.error {
                    Text(L.t("检查不到 Roblox 最新版本：\(e)", "Cannot check the latest Roblox version: \(e)"))
                        .font(.caption)
                } else {
                    Text(L.t("Roblox 有新版本：本机 \(v.installed ?? "?") → 官方 \(v.latest ?? "?")",
                             "Roblox update available: local \(v.installed ?? "?") → latest \(v.latest ?? "?")"))
                        .font(.caption)
                    Text(L.t("先打开一次原版 Roblox 让它自己更新，再回来启动账号；否则副本可能版本不一致。",
                             "Open the original Roblox once so it updates itself, then come back — otherwise the copy may be out of date."))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(L.t("修复 / 更新", "Repair / Update")) { store.repair() }
                .controlSize(.small)
                .disabled(store.busy != nil)
            Button(L.t("重新检查", "Recheck")) { store.checkVersion() }
                .controlSize(.small)
        }
        .padding(10)
        .background((v.error != nil ? Color.orange : Color.yellow).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Group {
                if let img = store.avatars[account.userID ?? -1] {
                    Image(nsImage: img).resizable().interpolation(.high)
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [.accentColor.opacity(0.9), .blue.opacity(0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text(String(account.username?.prefix(1) ?? "?").uppercased())
                            .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.system(size: 20, weight: .semibold))
                Text("@\(account.username ?? "?") · \(account.uidText)")
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    badge(account.instanceReady ? L.t("副本已就绪", "Copy ready") : L.t("副本未创建", "No copy yet"),
                          ok: account.instanceReady)
                    badge(L.t("\(account.flags.count) 个 FFlags", "\(account.flags.count) FFlags"), ok: true)
                }
            }
            Spacer()
        }
    }

    private func badge(_ text: String, ok: Bool) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(ok ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(ok ? Color.green : Color.orange)
            .clipShape(Capsule())
    }
}

struct FlagRow: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

// MARK: - 小控件

struct LabeledField: View {
    let title: String
    @Binding var text: String
    var width: CGFloat = 140
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
                .font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - 日志

struct LogPane: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(store.log.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .onChange(of: store.log.count) { _ in
                    if let last = store.log.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .frame(height: 150)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("✗") { return .red }
        if line.hasPrefix("✓") { return .green }
        if line.hasPrefix("▸") { return .accentColor }
        return .secondary
    }
}

// MARK: - 添加账号

struct AddAccountView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0            // 0 = 官方登录, 1 = 手动
    @State private var name = ""
    @State private var cookie = ""
    @State private var localIdentity: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("添加 Roblox 账号", "Add a Roblox account")).font(.headline)
                    Text(L.t("在下面直接登录 Roblox，登录完成会自动添加，不用手动找 cookie",
                             "Sign in to Roblox below — it is added automatically, no cookie hunting"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $mode) {
                    Text(L.t("官方登录", "Sign in")).tag(0)
                    Text(L.t("手动", "Manual")).tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                Button(L.t("关闭", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(14)

            Divider()

            if mode == 0 {
                LoginPanel { _ in dismiss() }
            } else {
                manual
            }
        }
        .frame(width: 860, height: 760)
        .onAppear {
            if store.status.localSession { store.localIdentity { localIdentity = $0 } }
        }
    }

    private var manual: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("1) 用本机已登录的 Roblox 会话（最快）",
                    "1) Use the session the local Roblox client already has (fastest)"))
                .font(.callout).fontWeight(.medium)
            HStack(spacing: 10) {
                TextField(L.t("账号名，如 alt", "account name, e.g. alt"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button(L.t("导入本机会话", "Import local session")) {
                    store.addLocal(name: name.isEmpty ? "main" : name)
                    dismiss()
                }
                .disabled(!store.status.localSession || store.busy != nil)
                HStack(spacing: 6) {
                    Image(systemName: store.status.localSession ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(store.status.localSession ? .green : .red)
                    Text(localIdentity ?? (store.status.localSession
                         ? L.t("本机会话可用", "local session available")
                         : L.t("本机没有 Roblox 会话", "no local Roblox session")))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            Text(L.t("2) 或者粘贴 .ROBLOSECURITY 会话串",
                    "2) Or paste a .ROBLOSECURITY session string"))
                .font(.callout).fontWeight(.medium)
            Text(L.t("Chrome：F12 → Application → Storage → Cookies → https://www.roblox.com；Safari：开发 → 显示 Web 检查器 → 存储 → Cookie",
                     "Chrome: F12 → Application → Storage → Cookies → https://www.roblox.com; Safari: Develop → Show Web Inspector → Storage → Cookies"))
                .font(.caption2).foregroundStyle(.secondary)
            TextEditor(text: $cookie)
                .font(.system(size: 10, design: .monospaced))
                .frame(minHeight: 130)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Spacer()
                Button(L.t("添加", "Add")) {
                    store.add(name: name.trimmingCharacters(in: .whitespaces),
                              cookie: cookie.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Spacer()
        }
        .padding(16)
    }
}


// MARK: - 重命名

struct RenameSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let account: Account
    @State private var name = ""
    @State private var error: String? = nil

    private var valid: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && n.range(of: "^[A-Za-z0-9._-]{1,32}$", options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("重命名账号", "Rename account")).font(.headline)
            Text(L.t("只改本机显示的名字，不影响 Roblox 用户名。副本、Keychain 会话、cookie 库都会自动迁移。",
                     "Only the local name changes — the Roblox username is untouched. Copy, Keychain session and cookie store are migrated."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit { save() }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text(L.t("允许：字母、数字、. _ -，最长 32", "Allowed: letters, digits, . _ -, up to 32"))
                .font(.caption2).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L.t("取消", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L.t("保存", "Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid || name == account.name || store.busy != nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { name = account.name }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard valid, n != account.name else { return }
        store.rename(account.name, to: n) { ok in
            if ok { dismiss() } else { error = L.t("重命名失败，看日志", "Rename failed — see the log") }
        }
    }
}
