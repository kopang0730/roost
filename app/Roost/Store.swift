import SwiftUI
import Combine

final class Store: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var status = Status()
    @Published var log: [String] = []
    @Published var busy: String? = nil
    @Published var selected: String? = nil

    @Published var place: String = ""
    @Published var size: String = "1020x640"
    @Published var fps: String = ""
    @Published var snap: Bool = true
    @Published var avatars: [Int: NSImage] = [:]
    @Published var hoverHint: String? = nil
    @Published var running: [RunningInstance] = []
    @Published var versionInfo: VersionInfo? = nil
    @Published var placeName: String? = nil
    @Published var appUpdate: UpdateInfo? = nil
    @Published var axOK = Perm.accessibility
    @Published var screenOK = Perm.screenRecording
    @Published var dismissedPerm: String? = UserDefaults.standard.string(forKey: "dismissedPerm") {
        didSet { UserDefaults.standard.set(dismissedPerm, forKey: "dismissedPerm") }
    }

    func refreshPermissions() {
        axOK = Perm.accessibility
        screenOK = Perm.screenRecording
    }
    @Published var presetGroups: [PresetGroup] = []
    @Published var managedKeys: [String] = []

    private let work = DispatchQueue(label: "roost.work", qos: .userInitiated)

    private var pollTimer: Timer?

    init() {
        refresh()
        loadPresets()
        startPolling()
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshRunning()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        refreshRunning()
        checkVersion()
        checkAppUpdate()
    }

    func refreshRunning() {
        work.async {
            let res = Py.call("instances") { _ in }
            DispatchQueue.main.async {
                guard let list = res["instances"] as? [[String: Any]] else { return }
                self.running = list.compactMap { d in
                    guard let n = d["name"] as? String else { return nil }
                    return RunningInstance(name: n,
                                           pids: (d["pids"] as? [Int]) ?? [],
                                           place: d["place"] as? String,
                                           startedAt: d["started_at"] as? Int)
                }
            }
        }
    }

    func isRunning(_ name: String) -> Bool { running.contains { $0.name == name } }

    func stop(_ name: String) {
        perform(L.t("停止 \(name)", "Stopping \(name)")) { _ in
            Py.call("stop", ["name": name]) { self.logMain($0) }
        } done: { _ in self.refreshRunning() }
    }

    func stopAll() {
        perform(L.t("关闭全部实例", "Stopping all instances")) { _ in
            Py.call("stop_all") { self.logMain($0) }
        } done: { _ in self.refreshRunning() }
    }

    func checkVersion() {
        work.async {
            let res = Py.call("version") { _ in }
            DispatchQueue.main.async {
                guard (res["ok"] as? Bool) == true else { return }
                self.versionInfo = VersionInfo(
                    installed: res["installed"] as? String,
                    latest: res["latest"] as? String,
                    update: (res["update_available"] as? Bool) ?? false,
                    error: res["error"] as? String)
            }
        }
    }

    func checkAppUpdate() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        work.async {
            let res = Py.call("update_check", ["version": current]) { _ in }
            DispatchQueue.main.async {
                guard (res["ok"] as? Bool) == true else { return }
                let info = UpdateInfo(latest: res["latest"] as? String ?? "",
                                      url: res["url"] as? String ?? "",
                                      newer: (res["newer"] as? Bool) ?? false)
                self.appUpdate = info.newer ? info : nil
            }
        }
    }

    func repair() {
        perform(L.t("修复 Roblox…", "Repairing Roblox…")) { _ in
            Py.call("repair") { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                let v = (res["version"] as? String) ?? "?"
                self.appendLog(L.t("✓ Roblox \(v) 已安装到 /Applications", "✓ Roblox \(v) installed in /Applications"))
                self.checkVersion()
                self.refresh()
            }
        }
    }

    func focus(_ name: String) {
        work.async {
            _ = Py.call("focus", ["name": name]) { _ in }
        }
    }

    func tileWindows() {
        perform(L.t("平铺窗口", "Tiling windows")) { _ in
            Py.call("tile") { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已平铺 \(res["tiled"] ?? 0) 个窗口", "✓ tiled \(res["tiled"] ?? 0) windows"))
            }
        }
    }

    func savePrefs() {
        guard let name = selected else { return }
        let p = place.trimmingCharacters(in: .whitespaces)
        let sz = size.trimmingCharacters(in: .whitespaces)
        let f = fps.trimmingCharacters(in: .whitespaces)
        work.async {
            _ = Py.call("set_prefs", ["name": name, "place": p, "size": sz, "fps": f]) { _ in }
        }
    }

    func loadPrefs() {
        guard let a = current else { return }
        place = a.place ?? ""
        size = a.size ?? "1020x640"
        fps = a.fps ?? ""
    }

    func lookupPlaceName(_ raw: String) {
        let p = raw.trimmingCharacters(in: .whitespaces)
        guard p.count >= 4, Int(p) != nil else { placeName = nil; return }
        work.async {
            let res = Py.call("place_name", ["place": p]) { _ in }
            DispatchQueue.main.async {
                self.placeName = (res["ok"] as? Bool) == true ? (res["name"] as? String) : nil
            }
        }
    }

    func loadPresets() {
        work.async {
            let res = Py.call("presets") { _ in }
            DispatchQueue.main.async {
                if let raw = res["groups"] as? [[String: Any]] {
                    self.presetGroups = PresetDecode.groups(raw)
                }
                self.managedKeys = (res["managed_keys"] as? [String]) ?? []
            }
        }
    }

    // MARK: 日志

    private var lastLang = L.lang

    /// 切语言时清掉旧日志，保证面板里只有一种语言。
    func noteLanguageChange() {
        let cur = L.lang
        guard cur != lastLang else { return }
        lastLang = cur
        log.removeAll()
        appendLog(L.t("语言已切换，日志已清空", "Language switched — log cleared"))
    }

    func appendLog(_ line: String) {
        log.append(line)
        if log.count > 600 { log.removeFirst(log.count - 600) }
    }

    private func logMain(_ line: String) {
        DispatchQueue.main.async { self.appendLog(line) }
    }

    // MARK: 通用执行

    private func perform(_ label: String,
                         _ body: @escaping ([String: Any]) -> [String: Any],
                         done: (([String: Any]) -> Void)? = nil) {
        guard busy == nil else { return }
        busy = label
        appendLog("▸ \(label)")
        work.async {
            let result = body([:])
            DispatchQueue.main.async {
                self.busy = nil
                if let err = result["error"] as? String, (result["ok"] as? Bool) != true {
                    self.appendLog("✗ \(err)")
                }
                done?(result)
            }
        }
    }

    // MARK: 刷新

    func refresh() {
        work.async {
            let res = Py.call("state") { line in self.logMain(line) }
            DispatchQueue.main.async {
                if let list = res["accounts"] as? [[String: Any]] {
                    self.accounts = list.compactMap { Account(json: $0) }
                }
                var st = Status()
                st.robloxVersion = res["roblox_version"] as? String ?? "?"
                st.robloxInstalled = res["roblox_installed"] as? Bool ?? false
                st.localSession = res["local_session"] as? Bool ?? false
                st.localSessionLen = res["local_session_len"] as? Int ?? 0
                st.clang = res["clang"] as? Bool ?? false
                st.cookieWriter = res["cookie_writer"] as? Bool ?? false
                self.status = st
                self.loadAvatars()
                if self.selected == nil { self.selected = self.accounts.first?.name }
                if self.selected != nil,
                   !self.accounts.contains(where: { $0.name == self.selected }) {
                    self.selected = self.accounts.first?.name
                }
            }
        }
    }

    private func loadAvatars() {
        for a in accounts {
            guard let id = a.userID else { continue }
            if avatars[id] != nil { continue }
            AvatarStore.shared.load(id) { img in
                if let img { self.avatars[id] = img }
            }
        }
    }

    var current: Account? {
        guard let s = selected else { return accounts.first }
        return accounts.first { $0.name == s }
    }

    // MARK: 账号

    func add(name: String, cookie: String) {
        let args: [String: Any] = ["name": name, "cookie": cookie]
        perform(L.t("添加账号 \(name)", "Adding account \(name)")) { _ in
            Py.call("add", args) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已添加 u\(res["user_id"] ?? "?") (\(res["username"] as? String ?? "?"))", "✓ added u\(res["user_id"] ?? "?") (\(res["username"] as? String ?? "?"))"))
                self.selected = name
                self.refresh()
            }
        }
    }

    /// 从内嵌官方登录页抓到的会话直接添加（账号名由 Roblox 用户名自动生成）
    func addAuto(_ cookie: String, done: @escaping (String?) -> Void) {
        guard busy == nil else { return }
        busy = L.t("添加账号…", "Adding account…")
        appendLog("▸ " + L.t("从登录窗口添加账号", "Adding an account from the login window"))
        work.async {
            let res = Py.call("add_auto", ["cookie": cookie]) { self.logMain($0) }
            DispatchQueue.main.async {
                self.busy = nil
                if res["ok"] as? Bool == true, let n = res["name"] as? String {
                    let u = (res["username"] as? String) ?? ""
                    let updated = (res["updated"] as? Bool) == true
                    self.appendLog(updated
                        ? L.t("✓ 已刷新 \(n)（\(u)）", "✓ refreshed \(n) (\(u))")
                        : L.t("✓ 已添加 \(n)（\(u)）", "✓ added \(n) (\(u))"))
                    self.selected = n
                    self.refresh()
                    done(n)
                } else {
                    self.appendLog("✗ " + ((res["error"] as? String) ?? "unknown"))
                    done(nil)
                }
            }
        }
    }

    func addLocal(name: String) {
        let args: [String: Any] = ["name": name]
        perform(L.t("导入本机会话 → \(name)", "Importing local session → \(name)")) { _ in
            Py.call("add_local", args) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已导入 u\(res["user_id"] ?? "?") (\(res["username"] as? String ?? "?"))", "✓ imported u\(res["user_id"] ?? "?") (\(res["username"] as? String ?? "?"))"))
                self.selected = name
                self.refresh()
            }
        }
    }

    func check(_ name: String) {
        perform(L.t("检查登录：\(name)", "Checking login: \(name)")) { _ in
            Py.call("check", ["name": name]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 登录态有效，已换到启动票据（\(res["ticket_len"] ?? "?") 字符）", "✓ session valid, launch ticket minted (\(res["ticket_len"] ?? "?") chars)"))
            }
        }
    }

    func rename(_ old: String, to new: String, done: @escaping (Bool) -> Void) {
        perform(L.t("重命名账号", "Renaming account")) { _ in
            Py.call("rename", ["old": old, "new": new]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                let n = (res["name"] as? String) ?? new
                self.appendLog(L.t("✓ 已重命名为 \(n)", "✓ renamed to \(n)"))
                if self.selected == old { self.selected = n }
                self.refresh()
                done(true)
            } else {
                done(false)
            }
        }
    }

    func reveal(_ name: String) {
        perform(L.t("打开副本目录", "Opening copies folder")) { _ in
            Py.call("reveal", ["name": name]) { self.logMain($0) }
        }
    }

    func remove(_ name: String) {
        perform(L.t("删除 \(name)", "Removing \(name)")) { _ in
            Py.call("rm", ["name": name]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已删除 \(name)", "✓ removed \(name)"))
                if self.selected == name { self.selected = nil }
                self.refresh()
            }
        }
    }

    // MARK: 启动

    private func launchArgs(_ name: String?) -> [String: Any] {
        var a: [String: Any] = [:]
        a["snap"] = snap
        if let n = name {
            a["name"] = n
            let names = accounts.map { $0.name }.sorted()
            a["slot"] = names.firstIndex(of: n) ?? 0
            a["total"] = max(1, names.count)
        }
        // 右键启动别的账号时，用那个账号自己存的配置，而不是当前界面上的
        if let n = name, n != selected, let acct = accounts.first(where: { $0.name == n }) {
            if let p = acct.place, !p.isEmpty { a["place"] = p }
            if let s = acct.size, !s.isEmpty { a["size"] = s }
            if let f = acct.fps, !f.isEmpty { a["fps"] = f }
        }
        let p = place.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { a["place"] = p }
        let s = size.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty { a["size"] = s }
        let f = fps.trimmingCharacters(in: .whitespaces)
        if !f.isEmpty { a["fps"] = f }
        return a
    }

    func launch(_ name: String) {
        if name == selected { savePrefs() }
        let args = launchArgs(name)
        perform(L.t("启动 \(name)", "Launching \(name)")) { _ in
            Py.call("launch", args) { self.logMain($0) }
        } done: { res in
            guard res["ok"] as? Bool == true else { return }
            let pid = res["pid"].map { "\($0)" } ?? "-"
            let injected = (res["injected"] as? Bool) == true
            self.appendLog(L.t("✓ \(name) 已启动 pid=\(pid) \(injected ? "会话已注入" : "注入失败: \(res["inject_detail"] ?? "-")")", "✓ \(name) launched pid=\(pid) \(injected ? "session injected" : "inject failed: \(res["inject_detail"] ?? "-")")"))
            if let r = res["resized"] as? [String: Any], (r["ok"] as? Bool) != true {
                self.appendLog(L.t("  窗口尺寸未生效: \(r["detail"] ?? "")", "  window size not applied: \(r["detail"] ?? "")"))
            }
            self.refresh()
        }
    }

    func launchAll() {
        let args = launchArgs(nil)
        perform(L.t("启动全部账号", "Launching all accounts")) { _ in
            Py.call("launch_all", args) { self.logMain($0) }
        } done: { res in
            if let results = res["results"] as? [[String: Any]] {
                for r in results {
                    if let n = r["account"] as? String {
                        self.appendLog((r["ok"] as? Bool) == true
                                       ? "✓ \(n) pid=\(r["pid"] ?? "-")"
                                       : "✗ \(n): \(r["error"] ?? "")")
                    }
                }
            }
            self.refresh()
        }
    }

    // MARK: FFlags

    func saveFlags(_ name: String, _ flags: [String: String]) {
        perform(L.t("保存 FFlags", "Saving FFlags")) { _ in
            Py.call("flags_set", ["name": name, "flags": flags]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ FFlags 已保存（\(flags.count) 项）", "✓ FFlags saved (\(flags.count) entries)"))
                self.refresh()
            }
        }
    }

    func applyPerf(_ name: String) {
        perform(L.t("一键性能优先", "Applying performance preset")) { _ in
            Py.call("apply_perf", ["name": name]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已应用「性能优先」预设", "✓ Performance preset applied"))
                self.refresh()
            }
        }
    }

    func resetFlags(_ name: String) {
        perform(L.t("恢复默认 FFlags", "Resetting FFlags")) { _ in
            Py.call("reset_flags", ["name": name]) { self.logMain($0) }
        } done: { res in
            if res["ok"] as? Bool == true {
                self.appendLog(L.t("✓ 已清掉预设管理的 FFlags", "✓ preset flags cleared"))
                self.refresh()
            }
        }
    }

    func openInstances() {
        perform(L.t("打开副本目录", "Opening copies folder")) { _ in
            Py.call("open_instances") { self.logMain($0) }
        }
    }

    // MARK: 本机身份

    func localIdentity(_ done: @escaping (String?) -> Void) {
        work.async {
            let res = Py.call("local_identity") { line in self.logMain(line) }
            DispatchQueue.main.async {
                if let u = res["username"] as? String, let id = res["user_id"] {
                    done("\(u) (u\(id))")
                } else {
                    done(nil)
                }
            }
        }
    }
}

// MARK: - 运行态模型

struct RunningInstance: Identifiable, Equatable {
    let name: String
    var pids: [Int]
    var place: String?
    var startedAt: Int?
    var id: String { name }
    var pid: Int { pids.first ?? 0 }
}

struct UpdateInfo {
    var latest: String
    var url: String
    var newer: Bool
}

struct VersionInfo {
    var installed: String?
    var latest: String?
    var update: Bool
    var error: String?
}
