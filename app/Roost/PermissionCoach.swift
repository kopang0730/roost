import AppKit
import SwiftUI
import CoreGraphics

enum PermissionKind {
    case accessibility, screen, automation

    var title: String {
        switch self {
        case .accessibility: return L.t("辅助功能", "Accessibility")
        case .screen: return L.t("屏幕录制", "Screen Recording")
        case .automation: return L.t("自动化", "Automation")
        }
    }

    var supportsAppDrop: Bool { self != .automation }
    var granted: Bool {
        switch self {
        case .accessibility: return Perm.accessibility
        case .screen: return Perm.screenRecording
        case .automation: return Perm.automation
        }
    }

    var instructions: String {
        switch self {
        case .accessibility:
            return L.t("把左侧 Roost 图标拖进上方的权限列表，再打开它的开关。", "Drag the Roost icon into the permission list above, then turn it on.")
        case .screen:
            return L.t("把 Roost 图标拖进上方列表并打开开关。如提示重新打开，请按系统提示操作。", "Drag Roost into the list above and enable it. Reopen the app if macOS asks.")
        case .automation:
            return L.t("在系统弹窗中允许 System Events 和 Finder，或在列表中打开对应开关。", "Allow System Events and Finder in the system dialogs, or enable their switches in the list.")
        }
    }
}

enum PermissionCoachLayout {
    static let size = CGSize(width: 480, height: 168)

    static func frame(below settings: CGRect?, visible: CGRect) -> CGRect {
        let size = CGSize(width: min(self.size.width, visible.width - 24), height: self.size.height)
        let x = (settings?.midX ?? visible.midX) - size.width / 2
        // Prefer outside the window; on a short display, hug its bottom edge.
        let below = (settings?.minY ?? visible.minY + size.height + 24) - size.height - 12
        return CGRect(x: min(max(x, visible.minX + 12), visible.maxX - size.width - 12),
                      y: min(max(below, visible.minY + 12), visible.maxY - size.height - 12),
                      width: size.width, height: size.height)
    }
}

/// A non-activating companion to System Settings. It never clicks system controls.
final class PermissionCoach: ObservableObject {
    static let shared = PermissionCoach()
    @Published private(set) var kind: PermissionKind = .screen
    @Published private(set) var granted = false
    private var panel: NSPanel?
    private var followTimer: Timer?
    private var visitedSettings = false

    func show(for kind: PermissionKind) {
        self.kind = kind
        visitedSettings = false
        granted = kind.granted
        if panel == nil {
            let window = PermissionCoachPanel(contentRect: CGRect(origin: .zero, size: PermissionCoachLayout.size),
                                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = L.t("Roost 授权助手", "Roost Permission Helper")
            window.isReleasedWhenClosed = false
            window.isFloatingPanel = true
            window.level = .floating
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.contentView = NSHostingView(rootView: PermissionCoachView(coach: self))
            panel = window
        }
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in self?.followSettings() }
        RunLoop.main.add(followTimer!, forMode: .common)
        followSettings()
    }

    func hide() {
        followTimer?.invalidate()
        followTimer = nil
        panel?.orderOut(nil)
    }

    func returnToRoost() {
        hide()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
    }

    func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func followSettings() {
        let current = kind.granted
        if current != granted { granted = current }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let panel, front == "com.apple.systempreferences" else {
            panel?.orderOut(nil)
            if visitedSettings && ((front == Bundle.main.bundleIdentifier && granted) || NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").isEmpty) {
                hide()
            }
            return
        }
        visitedSettings = true
        let settings = settingsWindowFrame()
        let screen = NSScreen.screens.max { a, b in
            let target = settings ?? NSScreen.main?.visibleFrame ?? .zero
            return area(a.frame.intersection(target)) < area(b.frame.intersection(target))
        } ?? NSScreen.main
        guard let screen else { return }
        let frame = PermissionCoachLayout.frame(below: settings, visible: screen.visibleFrame)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }

    private func settingsWindowFrame() -> CGRect? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first else { return nil }
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? Int) == Int(pid),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  frame.width > 350, frame.height > 300 else { continue }
            // Window-list geometry uses a top-left origin; AppKit uses bottom-left.
            return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
        }
        return nil
    }
}

private final class PermissionCoachPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct PermissionCoachView: View {
    @ObservedObject var coach: PermissionCoach

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                PermissionAppIcon(canDrag: coach.kind.supportsAppDrop)
                    .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 6) {
                    Label(coach.kind.title, systemImage: coach.granted ? "checkmark.circle.fill" : "arrow.up")
                        .font(.headline).foregroundStyle(coach.granted ? Color.green : Color.primary)
                    Text(coach.granted ? L.t("已授权，可以返回 Roost 了。", "Permission granted. You can return to Roost.") : coach.kind.instructions)
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { coach.hide() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel(L.t("关闭授权助手", "Close permission helper"))
            }
            HStack(spacing: 12) {
                if coach.kind.supportsAppDrop && !coach.granted {
                    Button(L.t("在 Finder 中显示", "Show in Finder")) { coach.revealApp() }.controlSize(.small)
                }
                Spacer()
                Button(L.t("返回 Roost", "Return to Roost")) { coach.returnToRoost() }.controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: PermissionCoachLayout.size.width, height: PermissionCoachLayout.size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.12)))
    }
}

struct PermissionAppIcon: NSViewRepresentable {
    let canDrag: Bool
    func makeNSView(context: Context) -> AppIconDragView { AppIconDragView(frame: .zero) }
    func updateNSView(_ view: AppIconDragView, context: Context) { view.canDrag = canDrag }
}

/// Native file dragging gives System Settings the same app URL as dragging from Finder.
final class AppIconDragView: NSImageView, NSDraggingSource {
    static var appURL: NSURL { Bundle.main.bundleURL as NSURL }
    var canDrag = true
    private var dragging = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        imageScaling = .scaleProportionallyUpOrDown
        setAccessibilityLabel(L.t("拖动 Roost 图标到系统权限列表", "Drag Roost into the system permission list"))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { }
    override func mouseDragged(with event: NSEvent) {
        guard canDrag, !dragging else { return }
        dragging = true
        let item = NSDraggingItem(pasteboardWriter: Self.appURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    override func resetCursorRects() {
        if canDrag { addCursorRect(bounds, cursor: .openHand) }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { dragging = false }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
