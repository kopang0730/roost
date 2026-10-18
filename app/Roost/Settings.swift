import SwiftUI

enum AppTheme {
    static func color(_ name: String) -> Color {
        switch name {
        case "purple": return .purple
        case "green":  return .green
        case "orange": return .orange
        case "pink":   return .pink
        default:       return .blue
        }
    }

    static func scheme(_ name: String) -> ColorScheme? {
        switch name {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    static let accents: [(id: String, zh: String, en: String)] = [
        ("blue", "蓝色", "Blue"), ("purple", "紫色", "Purple"), ("green", "绿色", "Green"),
        ("orange", "橙色", "Orange"), ("pink", "粉色", "Pink"),
    ]
}

struct SettingsView: View {
    @AppStorage("lang") private var lang = "zh"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accent") private var accent = "blue"
    @AppStorage("showLog") private var showLog = false
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var store: Store

    private func permRow(_ title: String, granted: Bool,
                         grant: @escaping () -> Void, open: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title).font(.caption)
            Spacer()
            if !granted {
                Button(L.t("授权", "Grant")) { grant() }.controlSize(.small)
            }
            Button(L.t("设置", "Settings")) { open() }.controlSize(.small)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "gearshape.fill").font(.title2)
                Text(L.t("设置", "Settings")).font(.headline)
                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t("语言", "Language")).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $lang) {
                        Text("中文").tag("zh")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Divider()

                    Text(L.t("外观", "Appearance")).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $appearance) {
                        Text(L.t("跟随系统", "System")).tag("system")
                        Text(L.t("浅色", "Light")).tag("light")
                        Text(L.t("深色", "Dark")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Divider()

                    Text(L.t("强调色", "Accent color")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(AppTheme.accents, id: \.id) { a in
                            Circle()
                                .fill(AppTheme.color(a.id))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(accent == a.id ? 0.9 : 0),
                                                    lineWidth: 2)
                                )
                                .onTapGesture { accent = a.id }
                                .help(lang == "en" ? a.en : a.zh)
                        }
                    }

                    Divider()

                    Toggle(L.t("显示日志面板", "Show log panel"), isOn: $showLog)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    Divider()

                    Text(L.t("系统权限", "Permissions")).font(.caption).foregroundStyle(.secondary)
                    permRow(L.t("辅助功能（调窗口大小/平铺/聚焦）", "Accessibility (resize / tile / focus)"),
                            granted: store.axOK,
                            grant: { Perm.requestAccessibility(); Perm.openAccessibility() },
                            open: { Perm.openAccessibility() })
                    permRow(L.t("屏幕录制（窗口预览）", "Screen Recording (previews)"),
                            granted: store.screenOK,
                            grant: { Perm.requestScreenRecording(); Perm.openScreenRecording() },
                            open: { Perm.openScreenRecording() })
                }
                .padding(8)
            }

            Spacer()
            HStack {
                Spacer()
                Button(L.t("完成", "Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
    }
}
