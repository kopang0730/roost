import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics

/// 系统权限：辅助功能（调窗口）与屏幕录制（预览）。
/// 主动调用授权 API，系统才会把 Roost 以自身图标登记进「隐私与安全性」列表。
enum Perm {
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func openAccessibility() {
        open("Privacy_Accessibility")
    }

    static func openScreenRecording() {
        open("Privacy_ScreenCapture")
    }

    private static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// 顶部提示条：缺权限时出现，点「授权」会触发系统弹窗并打开设置面板
struct PermissionBanner: View {
    @EnvironmentObject var store: Store
    let kind: Kind

    enum Kind { case accessibility, screen }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(L.t("去授权", "Grant")) {
                switch kind {
                case .accessibility:
                    Perm.requestAccessibility()
                    Perm.openAccessibility()
                case .screen:
                    Perm.requestScreenRecording()
                    Perm.openScreenRecording()
                }
            }
            .controlSize(.small)
            Button {
                store.dismissedPerm = kind == .accessibility ? "ax" : "screen"
            } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch kind {
        case .accessibility:
            return L.t("还差「辅助功能」权限", "Accessibility permission is missing")
        case .screen:
            return L.t("还差「屏幕录制」权限", "Screen Recording permission is missing")
        }
    }

    private var detail: String {
        switch kind {
        case .accessibility:
            return L.t("窗口大小、平铺、聚焦需要它。点「去授权」后，Roost 会出现在列表里，打开开关即可。",
                       "Needed for window resizing, tiling and focus. Click Grant, then switch Roost on in the list.")
        case .screen:
            return L.t("窗口预览需要它。点「去授权」后在列表里打开 Roost。",
                       "Needed for window previews. Click Grant, then switch Roost on.")
        }
    }
}
