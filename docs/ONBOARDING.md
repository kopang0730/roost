# First-run setup and tutorial

Roost opens a vertical checklist on the first launch, controlled by the existing `onboarded` UserDefaults key. The checklist includes:

- Accessibility: resize, arrange and focus windows.
- Screen Recording: live game-window previews.
- Automation: Apple events to System Events and Finder, matching the Python backend’s window-management scripts. Requests run sequentially off the main thread; the app’s Info.plist supplies `NSAppleEventsUsageDescription`.

Clicking a permission opens System Settings and a small non-activating `NSPanel` attached below its window. The panel remains available while System Settings is active, follows window movement, hides when another app becomes active, and closes through Return to Roost, completion of the permission flow, or closing Settings. Its native drag source supplies the running bundle as a `public.file-url`. The user can drop it into supported macOS permission lists, or use the system list’s add button. Automation requires the system’s consent dialogs and cannot be granted by dragging an icon. Permission checks run once per second while setup is visible and whenever Roost becomes active. Completion requires all three checks to pass. Choosing “Set up later” preserves access to the app and starts the skippable tour.

Finishing setup plays a two-second celebration, then starts a six-step tour: account list, add account, launch settings, performance settings, maintenance, and settings/tutorial access. Reduce Motion uses a short static success screen. The tour measures targets in the main content’s coordinate space, scrolls detail sections into view, clips offscreen highlights, and keeps its card within the window. Underlying controls are blocked during the tour, including toolbar actions and accessibility navigation. A new user sees a read-only example account; it is never added to saved accounts. Settings and the sidebar’s “Settings & tutorial” entry provide replay and permission-setup access.

## Validation

Run `./scripts/test-onboarding.sh` on an Apple Silicon Mac with Command Line Tools. The standalone executable uses a separate defaults domain and disables backend startup. It checks persistence, skip/replay, empty and existing account paths, fifteen spotlight layouts at three window sizes, offscreen targets, and the app-file URL drag type.

Manual checks:

1. Fresh app preferences: checklist shows actual permission state; “Finish setup” stays disabled until all checks pass. Returning from System Settings updates the checklist.
2. Grant Automation: System Events and Finder launch in the background as needed; requests are sequential and the UI stays responsive. A denied request can be changed from System Settings → Privacy & Security → Automation.
3. Allow all required permissions, then finish: celebration appears once, followed by the tour. Close/reopen during permission setup: setup resumes. Close/reopen after completion: the main app appears.
4. Empty account list: tour shows the labeled example, with no saved account, launch, or configuration writes. Skip/finish removes the example.
5. Existing account: all six highlights match their actual controls; Back and Next scroll correctly. Check the minimum 940 × 600 content size, a larger window, both languages and Reduce Motion.
6. Settings: replay returns to step one, and permission setup reopens the checklist. Escape skips the tour. Background controls remain inaccessible while overlays are active.

OS consent, permission-list drop handling and restart behavior require real user interaction on each supported macOS version. UI fixtures can verify the granted-state screen and celebration without changing system permissions, but do not establish those OS behaviors.

## Local development permission identity

Ad-hoc signing uses a code-hash-based designated requirement. Replacing a development build can leave a Screen Recording registration bound to an older executable. An observed local failure had a denied ScreenCapture row with an old requirement while Accessibility matched the installed build. The scoped recovery is to quit Roost, run `tccutil reset ScreenCapture com.roost.app`, reopen the installed app, and request the permission again. The user completes consent in macOS. Do not modify the TCC database or treat a mismatched registration as a grant.

The companion uses AppKit’s [floating panel](https://developer.apple.com/documentation/appkit/nspanel/isfloatingpanel) with a non-activating style so dragging the icon leaves System Settings available.
