import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import CoreServices

/// 系统权限：辅助功能、屏幕录制，以及窗口脚本使用的自动化。
/// 主动调用授权 API，系统才会把 Roost 以自身图标登记进「隐私与安全性」列表。
enum Perm {
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    // The Python backend sends Apple events to both targets for window layout.
    static let automationTargets = ["com.apple.systemevents", "com.apple.finder"]
    private static var lastKnownAutomation: [String: Bool] = [:]
    static var automation: Bool {
        let checks = automationTargets.map { target -> Bool in
            let status = automationStatus(target, ask: false)
            if status == noErr { lastKnownAutomation[target] = true }
            else if status != procNotFound { lastKnownAutomation[target] = false }
            // An idle System Events process can exit; that does not revoke consent.
            return lastKnownAutomation[target] ?? false
        }
        return checks.allSatisfy { $0 }
    }

    static func prepareAutomationChecks(onReady: @escaping () -> Void) {
        let group = DispatchGroup()
        for target in automationTargets {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) else { continue }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            group.enter()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in group.leave() }
        }
        group.notify(queue: .main, execute: onReady)
    }

    private static func automationStatus(_ bundleID: String, ask: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask)
    }

    static func requestAutomation(onDone: @escaping () -> Void = {}) {
        requestAutomationTarget(at: 0, onDone: onDone)
    }

    private static func requestAutomationTarget(at index: Int, onDone: @escaping () -> Void) {
        guard index < automationTargets.count,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: automationTargets[index]) else {
            openAutomation()
            onDone()
            return
        }
        // AE permission checks require a running target. Launch it in the background.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            guard error == nil else {
                DispatchQueue.main.async { openAutomation(); onDone() }
                return
            }
            // Prompting waits for the user; keep the main run loop responsive.
            DispatchQueue.global(qos: .userInitiated).async {
                _ = automationStatus(automationTargets[index], ask: true)
                DispatchQueue.main.async { requestAutomationTarget(at: index + 1, onDone: onDone) }
            }
        }
    }

    static func openAutomation() { open("Privacy_Automation", kind: .automation) }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private static var requestingScreen = false
    static func requestScreenRecording() {
        guard !requestingScreen else { return }
        requestingScreen = true
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CGRequestScreenCaptureAccess()
            DispatchQueue.main.async { requestingScreen = false }
        }
    }

    static func openAccessibility() {
        open("Privacy_Accessibility", kind: .accessibility)
    }

    static func openScreenRecording() {
        open("Privacy_ScreenCapture", kind: .screen)
    }

    private static func open(_ pane: String, kind: PermissionKind) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
            PermissionCoach.shared.show(for: kind)
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
