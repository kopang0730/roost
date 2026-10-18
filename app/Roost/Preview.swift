import SwiftUI
import ScreenCaptureKit
import CoreGraphics

/// 运行中实例的实时缩略图。用 SCScreenshotManager 定时抓单帧（比常驻 SCStream 省资源）。
@MainActor
final class PreviewModel: ObservableObject {
    @Published var images: [String: NSImage] = [:]
    @Published var denied = false
    @Published var note: String? = nil
    var targets: [(name: String, pid: Int)] = []

    private var timer: Timer?
    private var busy = false

    func start() {
        stop()
        guard CGPreflightScreenCaptureAccess() else {
            denied = true
            note = L.t("需要「屏幕录制」权限才能预览窗口", "Screen Recording permission is required for previews")
            return
        }
        denied = false
        note = nil
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        Task { await tick() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func requestPermission() {
        Perm.requestScreenRecording()
        Perm.openScreenRecording()
    }

    private func tick() async {
        guard !busy, !targets.isEmpty else { return }
        busy = true
        defer { busy = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            for target in targets {
                guard let win = content.windows.first(where: {
                    (($0.owningApplication?.processID).map(Int.init) ?? -1) == target.pid
                        && $0.frame.width > 200 && $0.isOnScreen
                }) else { continue }
                if let img = try? await capture(win) {
                    images[target.name] = img
                }
            }
        } catch {
            note = L.t("预览失败：", "Preview failed: ") + error.localizedDescription
        }
    }

    private func capture(_ window: SCWindow) async throws -> NSImage? {
        guard #available(macOS 14.0, *) else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let cfg = SCStreamConfiguration()
        let w = CGFloat(320)
        cfg.width = Int(w)
        cfg.height = max(1, Int(w * window.frame.height / max(1, window.frame.width)))
        cfg.showsCursor = false
        let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
        return NSImage(cgImage: cg, size: NSSize(width: cfg.width, height: cfg.height))
    }
}

struct PreviewSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PreviewModel()

    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.inset.filled.and.person.filled").font(.caption)
                Text(L.t("窗口预览", "Window previews")).font(.headline)
                if let note = model.note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.denied {
                    Button(L.t("授权屏幕录制", "Grant Screen Recording")) { model.requestPermission() }
                        .controlSize(.small)
                }
                Button(L.t("关闭", "Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)

            if store.running.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 40, weight: .light)).foregroundStyle(.tertiary)
                    Text(L.t("现在没有运行中的实例", "No instances are running")).foregroundStyle(.secondary)
                    Text(L.t("启动账号后，这里会显示每个窗口的实时画面", "Launch an account and its live window shows up here"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.running) { inst in
                            card(inst)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 920, height: 640)
        .onAppear {
            syncTargets()
            model.start()
        }
        .onChange(of: store.running) { _ in syncTargets() }
        .onDisappear { model.stop() }
    }

    private func syncTargets() {
        model.targets = store.running.map { ($0.name, $0.pid) }
    }

    private func card(_ inst: RunningInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text(inst.name).font(.system(size: 13, weight: .semibold))
                Text("pid \(inst.pid)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(L.t("停止", "Stop")) { store.stop(inst.name) }
                    .controlSize(.mini)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25))
                if let img = model.images[inst.name] {
                    Image(nsImage: img).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(model.denied ? L.t("等待授权", "Waiting for permission") : L.t("截图中…", "Capturing…"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 170)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
