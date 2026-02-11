import Foundation
import SwiftUI

enum Theme {
	static let accent = Color(red: 0.15, green: 0.78, blue: 0.72)
	static let warm = Color(red: 1.00, green: 0.50, blue: 0.35)
	static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)

	static let cardCornerRadius: CGFloat = 22

	static func textPrimary(for scheme: ColorScheme) -> Color {
		switch scheme {
		case .dark:
			return Color.white.opacity(0.92)
		default:
			return Color.black.opacity(0.86)
		}
	}

	static func textSecondary(for scheme: ColorScheme) -> Color {
		switch scheme {
		case .dark:
			return Color.white.opacity(0.72)
		default:
			return Color.black.opacity(0.60)
		}
	}

	static func textTertiary(for scheme: ColorScheme) -> Color {
		switch scheme {
		case .dark:
			return Color.white.opacity(0.56)
		default:
			return Color.black.opacity(0.46)
		}
	}

	static func sectionFill(for scheme: ColorScheme) -> AnyShapeStyle {
		switch scheme {
		case .dark:
			return AnyShapeStyle(
				LinearGradient(
					stops: [
						.init(color: Color.white.opacity(0.14), location: 0.0),
						.init(color: Color.white.opacity(0.08), location: 1.0),
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
		default:
			// Keep sections readable even if the user runs the app in Light appearance.
			return AnyShapeStyle(
				LinearGradient(
					stops: [
						.init(color: Color.white.opacity(0.92), location: 0.0),
						.init(color: Color.white.opacity(0.78), location: 1.0),
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
		}
	}

	static let headerDateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.calendar = Calendar.autoupdatingCurrent
		f.locale = Locale(identifier: "ko_KR")
		f.timeZone = TimeZone.autoupdatingCurrent
		f.dateFormat = "yyyy년 M월 d일 (EEE)"
		return f
	}()

	static func formatDuration(_ seconds: Double) -> String {
		let total = max(0, Int(seconds.rounded(.down)))
		let h = total / 3600
		let m = (total % 3600) / 60
		let s = total % 60

		// Compact, easy-to-scan format for per-app rows and totals.
		// - 1h+  => H:MM:SS
		// - <1h  => M:SS
		if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
		return String(format: "%d:%02d", m, s)
	}
}
