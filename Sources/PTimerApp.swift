import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NotificationService.configure()
		AppIconManager.apply(iconId: AppDataStore.shared.selectedAppIconId)
	}

	func applicationWillTerminate(_ notification: Notification) {
		Task { @MainActor in
			AppDataStore.shared.saveNow()
		}
	}
}

@main
struct PTimerApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	@StateObject private var store = AppDataStore.shared
	@StateObject private var tracker = AppUsageTracker(store: AppDataStore.shared)
	@StateObject private var timers = MultiTimerManager(presetMinutes: AppDataStore.shared.timerPresetsMinutes)
	@StateObject private var quitGuard = QuitGuard()

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(store)
				.environmentObject(tracker)
				.environmentObject(timers)
				.environmentObject(quitGuard)
				.tint(Theme.accent)
				.preferredColorScheme(.dark)
		}
		.windowStyle(.hiddenTitleBar)
		.windowToolbarStyle(.unifiedCompact)
		.commands {
			CommandGroup(replacing: .appTermination) {
				Button("Quit andso localization") {
					quitGuard.handleQuitCommand()
				}
				.keyboardShortcut("q", modifiers: .command)
			}
		}
	}
}
