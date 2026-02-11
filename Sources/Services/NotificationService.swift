import Foundation
import UserNotifications

@MainActor
enum NotificationService {
	private static let delegate = NotificationCenterDelegate()

	static func configure() {
		let center = UNUserNotificationCenter.current()
		center.delegate = delegate
		requestAuthorizationIfNeeded()
	}

	static func requestAuthorizationIfNeeded() {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			guard settings.authorizationStatus == .notDetermined else { return }
			DispatchQueue.main.async {
				UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
					// Best-effort.
				}
			}
		}
	}

	static func postTimerFinished(title: String, body: String) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = .default

		// A short trigger tends to be more reliable than a nil trigger, and it also goes
		// through the usual delivery path. Use >= 1s for broad macOS compatibility.
		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)

		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: trigger
		)

		UNUserNotificationCenter.current().add(request) { _ in
			// Best-effort.
		}
	}
}

private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification
	) async -> UNNotificationPresentationOptions {
		// Show banners even while the app is frontmost.
		[.banner, .sound]
	}
}
