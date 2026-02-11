import AppKit
import Foundation

@MainActor
final class AppUsageTracker: ObservableObject {
	@Published private(set) var currentBundleId: String?
	@Published private(set) var currentAppName: String?

	private let store: AppDataStore
	private let calendar = Calendar.autoupdatingCurrent

	private var currentStart: Date?
	private var isPaused = false
	private var tickTimer: Timer?
	private var observers: [NSObjectProtocol] = []

	init(store: AppDataStore) {
		self.store = store
		start()
	}

	func start() {
		guard observers.isEmpty else { return }

		let nc = NSWorkspace.shared.notificationCenter

		observers.append(
			nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
				let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
				let bundleId = app?.bundleIdentifier
				let appName = app?.localizedName
				Task { @MainActor in
					self?.switchTo(bundleId: bundleId, appName: appName, at: Date())
				}
			}
		)

		observers.append(
			nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
				Task { @MainActor in
					self?.pause(at: Date())
				}
			}
		)

		observers.append(
			nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
				Task { @MainActor in
					self?.resume(at: Date())
				}
			}
		)

		observers.append(
			nc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
				Task { @MainActor in
					self?.pause(at: Date())
				}
			}
		)

		observers.append(
			nc.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
				Task { @MainActor in
					self?.resume(at: Date())
				}
			}
		)

		// Ensure we have an initial current app.
		if let app = NSWorkspace.shared.frontmostApplication {
			switchTo(bundleId: app.bundleIdentifier, appName: app.localizedName, at: Date())
		}

		tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			Task { @MainActor in
				self?.flushCurrentSession(at: Date())
			}
		}
	}

	func stop() {
		tickTimer?.invalidate()
		tickTimer = nil

		let nc = NSWorkspace.shared.notificationCenter
		for token in observers {
			nc.removeObserver(token)
		}
		observers.removeAll()

		flushCurrentSession(at: Date())
		currentBundleId = nil
		currentAppName = nil
		currentStart = nil
	}

	private func switchTo(bundleId: String?, appName: String?, at now: Date) {
		guard !isPaused else { return }

		flushCurrentSession(at: now)

		currentBundleId = bundleId
		currentAppName = appName
		currentStart = now
	}

	private func pause(at now: Date) {
		guard !isPaused else { return }
		flushCurrentSession(at: now)
		isPaused = true
		currentBundleId = nil
		currentAppName = nil
		currentStart = nil
	}

	private func resume(at now: Date) {
		guard isPaused else { return }
		isPaused = false
		if let app = NSWorkspace.shared.frontmostApplication {
			switchTo(bundleId: app.bundleIdentifier, appName: app.localizedName, at: now)
		}
	}

	private func flushCurrentSession(at now: Date) {
		guard
			!isPaused,
			let bundleId = currentBundleId,
			let start = currentStart,
			now > start
		else { return }

		guard store.isTracked(bundleId: bundleId) else {
			currentStart = now
			return
		}

		addUsage(bundleId: bundleId, from: start, to: now)
		currentStart = now
	}

	private func addUsage(bundleId: String, from start: Date, to end: Date) {
		var segmentStart = start
		while segmentStart < end {
			let dayStart = calendar.startOfDay(for: segmentStart)
			guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
			let segmentEnd = min(end, nextDayStart)
			let seconds = segmentEnd.timeIntervalSince(segmentStart)
			if seconds > 0 {
				store.addUsage(bundleId: bundleId, at: segmentStart, seconds: seconds)
			}
			segmentStart = segmentEnd
		}
	}
}
