import SwiftUI
import AppKit
import Combine

// Resolve bounds anchors in the overlay, including native split-view offsets.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func tourAnchor(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

struct TourStep: Identifiable {
    let id: String
    let anchor: String
    let title: String
    let body: String
}

enum TourScript {
    static var steps: [TourStep] {
        [
            TourStep(id: "accounts", anchor: "sidebar",
                     title: L.t("你的账号，都在这里", "Your accounts live here"),
                     body: L.t("左侧选择账号，右侧查看配置。每个账号有独立的会话和客户端副本；右键账号可以聚焦窗口、检查登录或重命名。",
                               "Select an account on the left to see its settings. Each has its own session and client copy. Right-click an account to focus its window, check sign-in or rename it.")),
            TourStep(id: "add", anchor: "add",
                     title: L.t("从添加账号开始", "Start by adding an account"),
                     body: L.t("点这里或顶部「添加账号」，在 Roblox 官方页面登录，账号就会自动加入。顶部工具栏还可以全部启动、平铺窗口、查看预览和展开日志。",
                               "Click Add account here or in the toolbar and sign in on Roblox’s official page. Your account is added automatically. The toolbar also launches all accounts, tiles windows, opens previews and shows logs.")),
            TourStep(id: "launch", anchor: "launch",
                     title: L.t("选择游戏，启动窗口", "Choose a game and launch"),
                     body: L.t("placeId 填游戏 ID，留空会打开客户端首页。窗口尺寸和 fps 会按账号保存；「启动」打开当前账号，「停止」关闭它的实例。",
                               "Enter a game ID in placeId, or leave it empty for the client home. Window size and fps are saved per account. Launch opens this account; Stop closes its instances.")),
            TourStep(id: "presets", anchor: "presets",
                     title: L.t("按需要调整性能", "Tune performance"),
                     body: L.t("这里管理画质、帧率和显示选项，修改后下次启动使用。「性能优先」套用节省资源的组合，「恢复默认」清除预设管理的选项。",
                               "Manage graphics, frame rate and display options here. Changes apply on the next launch. Performance applies a resource-saving combination; Reset clears the preset-managed options.")),
            TourStep(id: "maintenance", anchor: "maintenance",
                     title: L.t("遇到问题，从这里检查", "Troubleshoot here"),
                     body: L.t("「检查登录」验证保存的会话；「修复 Roblox」重新下载安装官方客户端。操作结果可以在顶部「日志」中查看。",
                               "Check login verifies the saved session. Repair Roblox downloads and installs the official client. Open Log in the toolbar to see the results.")),
            TourStep(id: "help", anchor: "help",
                     title: L.t("随时回来看看", "Come back any time"),
                     body: L.t("在设置中可以重新播放教程、打开权限引导，也可以切换语言、外观和强调色。准备好了，就添加你的第一个账号吧。",
                               "Settings lets you replay this tour, reopen permission setup and change language, appearance and accent color. You are ready to add your first account."))
        ]
    }

    static var exampleAccount: Account {
        Account(json: ["name": L.t("示例账号 · 仅供教程展示", "Example account · tutorial only"),
                       "username": "Roost", "flags": [String: String]()])!
    }
}

// MARK: - First-run permissions

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating = false
    private let permissionPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var grantedCount: Int { (store.axOK ? 1 : 0) + (store.screenOK ? 1 : 0) + (store.automationOK ? 1 : 0) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable().frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("让 Roost 准备就绪", "Get Roost ready")).font(.title2).bold()
                        Text(L.t("先设置权限，再带你熟悉软件。", "Set up permissions, then take a quick tour."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(grantedCount) / 3").monospacedDigit().font(.headline)
                        .foregroundStyle(grantedCount == 3 ? Color.green : Color.secondary)
                }
                ProgressView(value: Double(grantedCount), total: 3).tint(.accentColor)
                    .accessibilityLabel(L.t("已授权 \(grantedCount) 项，共 3 项", "\(grantedCount) of 3 permissions granted"))

                VStack(spacing: 10) {
                    permissionRow(icon: "cursorarrow.rays", title: L.t("辅助功能", "Accessibility"),
                                  detail: L.t("调整窗口大小、自动排列和聚焦窗口。", "Resize, arrange and focus game windows."),
                                  granted: store.axOK, action: {
                        Perm.requestAccessibility()
                        Perm.openAccessibility()
                    })
                    permissionRow(icon: "rectangle.on.rectangle", title: L.t("屏幕录制", "Screen Recording"),
                                  detail: L.t("为运行中的游戏窗口显示实时预览。", "Show live previews of running game windows."),
                                  granted: store.screenOK, action: {
                        Perm.requestScreenRecording()
                        Perm.openScreenRecording()
                    })
                    permissionRow(icon: "gearshape.2", title: L.t("自动化", "Automation"),
                                  detail: L.t("允许 System Events 与 Finder 配合排列、聚焦窗口。", "Allow System Events and Finder for window layout and focus."),
                                  granted: store.automationOK, action: { store.requestAutomation() },
                                  waiting: store.requestingAutomation)
                }

                Text(L.t("点「去授权」后，系统权限页下方会浮出 Roost 图标，直接拖入列表即可。自动化请按系统弹窗操作。",
                         "Click Grant access to open System Settings with a floating Roost icon below it. Drag the icon into the list. For Automation, follow the system dialogs."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                Text(L.t("授权状态会自动更新。系统如提示重新打开 App，请按提示操作；引导会在下次打开时继续。",
                         "Permission status updates automatically. If macOS asks you to reopen the app, follow its prompt; setup resumes on the next launch."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button(L.t("稍后设置", "Set up later")) { store.finishOnboarding() }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        celebrating = true
                    } label: {
                        Label(L.t("完成设置", "Finish setup"), systemImage: "sparkles")
                            .frame(minWidth: 116)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(grantedCount != 3)
                }
            }
            .padding(26)
            .frame(width: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.08)))
            .shadow(radius: 30, y: 10)
            .disabled(celebrating)
            .accessibilityHidden(celebrating)

            if celebrating {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    if !reduceMotion { FireworksView() }
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(.green)
                        Text(L.t("准备就绪！", "You’re all set!")).font(.largeTitle).bold()
                        Text(L.t("接下来，带你认识 Roost", "Let’s get to know Roost")).foregroundStyle(.secondary)
                    }
                    .padding(36)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
                .task {
                    do { try await Task.sleep(nanoseconds: reduceMotion ? 500_000_000 : 2_000_000_000) }
                    catch { return }
                    store.finishOnboarding()
                }
            }
        }
        .onAppear { store.refreshPermissions() }
        .onReceive(permissionPoll) { _ in store.refreshPermissions() }
    }

    private func permissionRow(icon: String, title: String, detail: String, granted: Bool,
                               action: @escaping () -> Void, waiting: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 22)).frame(width: 30)
                .foregroundStyle(granted ? Color.green : Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text(L.t("已授权", "Granted")).font(.callout).foregroundStyle(.green)
            } else {
                Button(waiting ? L.t("等待授权…", "Waiting…") : L.t("去授权", "Grant access"), action: action)
                    .controlSize(.regular).disabled(waiting)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Celebration (particles remain stable across animation frames)

struct FireworksView: View {
    @State private var start = Date()
    private struct Particle {
        let burst: Int
        let angle: Double
        let speed: Double
        let color: Color
        let size: CGFloat
    }
    @State private var particles: [Particle] = (0..<90).map { i in
        Particle(burst: i / 30, angle: Double(i % 30) * 2 * .pi / 30,
                 speed: Double.random(in: 90...250),
                 color: [Color.blue, .purple, .pink, .orange, .yellow, .green][i % 6],
                 size: CGFloat.random(in: 3...7))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let local = t - Double(p.burst) * 0.22
                    guard local > 0, local < 1.5 else { continue }
                    let center = CGPoint(x: size.width / 3 + CGFloat(p.burst - 1) * 160,
                                         y: size.height * 0.4 - CGFloat(p.burst) * 35)
                    let point = CGPoint(x: center.x + cos(p.angle) * p.speed * local,
                                        y: center.y + sin(p.angle) * p.speed * local + local * local * 60)
                    let rect = CGRect(x: point.x, y: point.y, width: p.size, height: p.size)
                    context.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(max(0, 1 - local / 1.5))))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Spotlight tour

enum TourLayout {
    static func highlight(_ raw: CGRect?, in size: CGSize) -> CGRect? {
        guard let raw, raw.width > 0, raw.height > 0 else { return nil }
        let visible = raw.insetBy(dx: -5, dy: -5)
            .intersection(CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6))
        return visible.isNull || visible.isEmpty ? nil : visible
    }

    static func cardOrigin(hole: CGRect?, card: CGSize, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 16
        let maxX = max(margin, size.width - card.width - margin)
        let maxY = max(margin, size.height - card.height - margin)
        guard let hole else { return CGPoint(x: maxX, y: maxY) }
        let candidates = [CGPoint(x: hole.midX - card.width / 3, y: hole.maxY + margin),
                          CGPoint(x: hole.maxX + margin, y: hole.midY - card.height / 3),
                          CGPoint(x: hole.midX - card.width / 3, y: hole.minY - card.height - margin),
                          CGPoint(x: hole.minX - card.width - margin, y: hole.midY - card.height / 3)]
        for candidate in candidates {
            let clamped = CGPoint(x: min(max(candidate.x, margin), maxX),
                                  y: min(max(candidate.y, margin), maxY))
            if !CGRect(origin: clamped, size: card).intersects(hole) { return clamped }
        }
        return CGPoint(x: maxX, y: maxY)
    }
}

private struct TourCardSizeKey: PreferenceKey {
    static var defaultValue = CGSize(width: 340, height: 240)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

struct TourOverlay: View {
    @EnvironmentObject var store: Store
    let anchors: [String: Anchor<CGRect>]
    @State private var cardSize = TourCardSizeKey.defaultValue

    var body: some View {
        GeometryReader { geometry in
            let steps = TourScript.steps
            let step = steps[min(max(0, store.tourStep), steps.count - 1)]
            let raw = anchors[step.anchor].map { geometry[$0] }
            let hole = TourLayout.highlight(raw, in: geometry.size)
            let origin = TourLayout.cardOrigin(hole: hole, card: cardSize, in: geometry.size)
            ZStack(alignment: .topLeading) {
                // A separate hit surface also blocks controls inside the spotlight hole.
                Color.clear.contentShape(Rectangle()).onTapGesture { }
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    if let hole { path.addRoundedRect(in: hole, cornerSize: CGSize(width: 10, height: 10)) }
                }
                .fill(Color.black.opacity(0.57), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                if let hole {
                    RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: hole.width, height: hole.height)
                        .offset(x: hole.minX, y: hole.minY).allowsHitTesting(false)
                }
                card(step: step, count: steps.count)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: TourCardSizeKey.self, value: proxy.size)
                    })
                    .offset(x: origin.x, y: origin.y)
            }
        }
        .onPreferenceChange(TourCardSizeKey.self) { cardSize = $0 }
    }

    private func card(step: TourStep, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.t("认识 Roost", "Meet Roost")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(store.tourStep + 1) / \(count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            Text(step.title).font(.title3).bold()
            Text(step.body).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if store.tourUsesExample {
                Label(L.t("当前为只读示例，完成后可添加自己的账号。", "Read-only example. Add your own account after the tour."), systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button(L.t("跳过教程", "Skip tour")) { store.endTour() }
                    .buttonStyle(.plain).foregroundStyle(.secondary).keyboardShortcut(.cancelAction)
                Spacer()
                if store.tourStep > 0 {
                    Button(L.t("上一步", "Back")) { store.tourStep -= 1 }.controlSize(.small)
                }
                Button(store.tourStep == count - 1 ? L.t("开始使用", "Get started") : L.t("下一步", "Next")) {
                    store.advanceTour()
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).controlSize(.small)
            }
        }
        .padding(18).frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.1)))
        .shadow(radius: 16, y: 6)
    }
}
