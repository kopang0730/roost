import SwiftUI

@main
struct ExoLocalApp: App {
    @StateObject private var store = Store()
    @AppStorage("lang") private var lang = "zh"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accent") private var accent = "blue"

    var body: some Scene {
        WindowGroup("ExoLocal", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 940, minHeight: 600)
                .id(lang)
                .tint(AppTheme.color(accent))
                .preferredColorScheme(AppTheme.scheme(appearance))
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .toolbar) {
                Button(L.t("刷新账号", "Refresh accounts")) { store.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarContent().environmentObject(store).id(lang)
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - 菜单栏常驻

struct MenuBarContent: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.accounts.isEmpty {
            Text(L.t("还没有账号", "No accounts yet"))
            Button(L.t("打开窗口添加…", "Open window to add…")) { showWindow() }
        } else {
            ForEach(store.accounts) { a in
                Button {
                    store.launch(a.name)
                } label: {
                    Text(L.t("启动 \(a.name)  ·  \(a.username ?? "")", "Launch \(a.name)  ·  \(a.username ?? "")"))
                }
            }
            Divider()
            Button(L.t("全部启动", "Launch all")) { store.launchAll() }
            Divider()
            Button(L.t("打开 ExoLocal 窗口", "Open ExoLocal window")) { showWindow() }
        }
        Divider()
        Button(L.t("退出 ExoLocal", "Quit ExoLocal")) { NSApplication.shared.terminate(nil) }
    }

    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }
}
