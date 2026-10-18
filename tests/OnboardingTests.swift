import SwiftUI
import AppKit

@main
struct OnboardingTests {
    static func main() {
        // This executable has its own defaults domain, separate from com.roost.app.
        let defaults = UserDefaults.standard
        let keys = ["onboarded", "tourDone"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(false, forKey: "onboarded")
        defaults.removeObject(forKey: "tourDone")
        let store = Store(startServices: false)
        precondition(store.showOnboarding && !store.tourActive)
        store.finishOnboarding()
        precondition(!store.showOnboarding && store.tourActive && store.tourUsesExample)
        precondition(defaults.bool(forKey: "onboarded"))
        precondition(!defaults.bool(forKey: "tourDone"))
        for _ in 1..<TourScript.steps.count { store.advanceTour() }
        precondition(store.tourStep == TourScript.steps.count - 1 && store.tourActive)
        store.advanceTour()
        precondition(!store.tourActive && !store.tourUsesExample && defaults.bool(forKey: "tourDone"))
        store.startTour()
        precondition(store.tourStep == 0 && store.tourActive)
        store.endTour()
        store.reopenOnboarding()
        precondition(store.showOnboarding && !store.tourActive && !defaults.bool(forKey: "onboarded"))
        store.finishOnboarding(startTour: false)
        precondition(!store.showOnboarding && !store.tourActive)
        store.accounts = [TourScript.exampleAccount]
        store.startTour()
        precondition(!store.tourUsesExample)
        store.endTour()
        precondition(TourScript.exampleAccount.flags.isEmpty && !TourScript.exampleAccount.instanceReady)

        let card = CGSize(width: 340, height: 260)
        for size in [CGSize(width: 940, height: 600), CGSize(width: 1100, height: 760), CGSize(width: 1500, height: 950)] {
            let regions = [CGRect(x: 0, y: 0, width: 260, height: size.height - 120),
                           CGRect(x: 16, y: size.height - 100, width: 230, height: 30),
                           CGRect(x: 280, y: 0, width: size.width - 300, height: 170),
                           CGRect(x: 290, y: 20, width: size.width - 320, height: 30),
                           CGRect(x: 280, y: size.height - 140, width: size.width - 300, height: 110)]
            for region in regions {
                let hole = TourLayout.highlight(region, in: size)!
                let origin = TourLayout.cardOrigin(hole: hole, card: card, in: size)
                let frame = CGRect(origin: origin, size: card)
                precondition(CGRect(origin: .zero, size: size).contains(frame), "Guide card escaped the window")
                precondition(!frame.intersects(hole), "Guide card covered a target with available space")
            }
            precondition(TourLayout.highlight(nil, in: size) == nil)
            precondition(TourLayout.highlight(CGRect(x: 0, y: -500, width: 200, height: 50), in: size) == nil)
            let fallback = TourLayout.cardOrigin(hole: nil, card: card, in: size)
            precondition(CGRect(origin: .zero, size: size).contains(CGRect(origin: fallback, size: card)))
        }
        let provider = NSItemProvider(object: URL(fileURLWithPath: "/Applications/Roost.app") as NSURL)
        precondition(provider.hasItemConformingToTypeIdentifier("public.file-url"))
        for visible in [CGRect(x: 0, y: 0, width: 1440, height: 875),
                        CGRect(x: -1920, y: 0, width: 1920, height: 1050),
                        CGRect(x: 0, y: -1080, width: 1920, height: 1050)] {
            for settings in [CGRect(x: visible.minX + 100, y: visible.minY + 300, width: 700, height: 500),
                             CGRect(x: visible.minX + 100, y: visible.minY, width: 700, height: 800),
                             CGRect(x: visible.maxX - 400, y: visible.maxY - 400, width: 700, height: 500)] {
                let frame = PermissionCoachLayout.frame(below: settings, visible: visible)
                precondition(visible.contains(frame), "Permission helper escaped the display")
                if settings.minY - visible.minY >= PermissionCoachLayout.size.height + 24 {
                    precondition(frame.maxY < settings.minY, "Permission helper should sit below System Settings")
                }
            }
        }
        precondition(PermissionKind.screen.supportsAppDrop && PermissionKind.accessibility.supportsAppDrop)
        precondition(!PermissionKind.automation.supportsAppDrop)
        precondition(AppIconDragView.appURL.writableTypes(for: .general).contains(.fileURL))
        print("PASS: onboarding persistence, skip/replay, empty/existing accounts, 15 spotlight layouts, offscreen targets app file-URL drag and permission helper layout")
    }
}
