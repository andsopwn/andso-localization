import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsSheet: View {
	@EnvironmentObject private var store: AppDataStore
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme

	@State private var statusMessage: String?

	@State private var pendingImportURL: URL?
	@State private var showImportConfirm = false

	@State private var showResetConfirm = false
	@State private var notificationStatusText: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text("설정")
					.font(.system(size: 20, weight: .bold, design: .rounded))
				Spacer(minLength: 0)
				Button("닫기") { dismiss() }
					.buttonStyle(.borderedProminent)
			}

			if let statusMessage {
				Text(statusMessage)
					.font(.system(size: 12, weight: .semibold, design: .rounded))
					.foregroundStyle(Theme.textSecondary(for: colorScheme))
			}

			Divider()

			VStack(alignment: .leading, spacing: 12) {
				sectionTitle("데이터")

				HStack(spacing: 10) {
					Button {
						exportDatabase()
					} label: {
						Label("DB 저장…", systemImage: "square.and.arrow.down")
					}
					.buttonStyle(.borderedProminent)

					Button {
						pickImportFile()
					} label: {
						Label("DB 불러오기…", systemImage: "square.and.arrow.down.on.square")
					}
					.buttonStyle(.bordered)

					Spacer(minLength: 0)
				}

				HStack(spacing: 10) {
					Button {
						NSWorkspace.shared.activateFileViewerSelecting([store.databaseFileURLForSharing])
					} label: {
						Label("저장 위치 열기", systemImage: "folder")
					}
					.buttonStyle(.bordered)

					Button(role: .destructive) {
						showResetConfirm = true
					} label: {
						Label("데이터 초기화", systemImage: "trash")
					}
					.buttonStyle(.bordered)

					Spacer(minLength: 0)
				}

				Text(store.databaseFileURLForSharing.path)
					.font(.system(size: 11, weight: .regular, design: .monospaced))
					.foregroundStyle(Theme.textTertiary(for: colorScheme))
					.lineLimit(2)
			}

			Divider()

			VStack(alignment: .leading, spacing: 12) {
				sectionTitle("배경")

				HStack(spacing: 10) {
					Button {
						pickBackgroundImage()
					} label: {
						Label("배경화면 변경…", systemImage: "photo")
					}
					.buttonStyle(.borderedProminent)

					Button {
						store.resetCustomBackgroundImage()
						statusMessage = "기본 배경으로 복원했습니다."
					} label: {
						Label("기본 배경 복원", systemImage: "arrow.counterclockwise")
					}
					.buttonStyle(.bordered)

					Spacer(minLength: 0)
				}

				Text(backgroundStatusText())
					.font(.system(size: 11, weight: .regular, design: .rounded))
					.foregroundStyle(Theme.textTertiary(for: colorScheme))
					.lineLimit(2)
			}

			Divider()

			VStack(alignment: .leading, spacing: 12) {
				sectionTitle("지원")

				Button {
					openBugReportMail()
				} label: {
					Label("버그 신고", systemImage: "ladybug")
				}
				.buttonStyle(.bordered)

				HStack(spacing: 10) {
					Text("버전 \(appVersionString())")
						.font(.system(size: 12, weight: .semibold, design: .rounded))
						.foregroundStyle(Theme.textSecondary(for: colorScheme))
					Spacer(minLength: 0)
				}
			}

			Divider()

			VStack(alignment: .leading, spacing: 12) {
				sectionTitle("알림")

				if let notificationStatusText {
					Text(notificationStatusText)
						.font(.system(size: 12, weight: .semibold, design: .rounded))
						.foregroundStyle(Theme.textSecondary(for: colorScheme))
				}

				Button {
					openNotificationSettings()
				} label: {
					Label("알림 설정 열기", systemImage: "bell")
				}
				.buttonStyle(.bordered)

				Button {
					NotificationService.requestAuthorizationIfNeeded()
					NotificationService.postTimerFinished(
						title: "알림 테스트",
						body: "andso localization 테스트 알림입니다."
					)
					statusMessage = "테스트 알림을 예약했습니다."
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
						refreshNotificationStatus()
					}
				} label: {
					Label("테스트 알림 보내기", systemImage: "paperplane")
				}
				.buttonStyle(.bordered)
			}

			Spacer(minLength: 0)
		}
		.padding(18)
		.foregroundStyle(Theme.textPrimary(for: colorScheme))
		.onAppear {
			NotificationService.requestAuthorizationIfNeeded()
			refreshNotificationStatus()
		}
		.alert("DB 불러오기", isPresented: $showImportConfirm) {
			Button("취소", role: .cancel) {
				pendingImportURL = nil
			}
			Button("불러오기", role: .destructive) {
				confirmImport()
			}
		} message: {
			Text("현재 데이터가 덮어씌워집니다.")
		}
		.alert("데이터 초기화", isPresented: $showResetConfirm) {
			Button("취소", role: .cancel) {}
			Button("초기화", role: .destructive) {
				withAnimation(.snappy(duration: 0.25)) {
					store.resetAllData()
				}
				statusMessage = "데이터를 초기화했습니다."
			}
		} message: {
			Text("추적 앱, 작업시간, 작업 목록, 메모가 모두 삭제됩니다.")
		}
	}

	@ViewBuilder
	private func sectionTitle(_ title: String) -> some View {
		Text(title)
			.font(.system(size: 13, weight: .bold, design: .rounded))
			.foregroundStyle(Theme.textSecondary(for: colorScheme))
	}

	private func exportDatabase() {
		statusMessage = nil

		let panel = NSSavePanel()
		panel.title = "DB 저장"
		panel.canCreateDirectories = true
		panel.allowedContentTypes = [.json]
		panel.nameFieldStringValue = "andso-timer-backup.json"

		let res = panel.runModal()
		guard res == .OK, let url = panel.url else { return }

		do {
			try store.exportDatabase(to: url)
			statusMessage = "저장됨: \(url.lastPathComponent)"
		} catch {
			statusMessage = "저장 실패: \(error.localizedDescription)"
		}
	}

	private func pickImportFile() {
		statusMessage = nil

		let panel = NSOpenPanel()
		panel.title = "DB 불러오기"
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.json]

		let res = panel.runModal()
		guard res == .OK, let url = panel.url else { return }

		pendingImportURL = url
		showImportConfirm = true
	}

	private func pickBackgroundImage() {
		statusMessage = nil

		let panel = NSOpenPanel()
		panel.title = "배경화면 변경"
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.image]

		let res = panel.runModal()
		guard res == .OK, let url = panel.url else { return }
		guard NSImage(contentsOf: url) != nil else {
			statusMessage = "이미지 파일을 읽을 수 없습니다."
			return
		}

		do {
			try store.setCustomBackgroundImage(from: url)
			statusMessage = "배경화면 적용됨: \(url.lastPathComponent)"
		} catch {
			statusMessage = "배경화면 변경 실패: \(error.localizedDescription)"
		}
	}

	private func confirmImport() {
		guard let url = pendingImportURL else { return }
		pendingImportURL = nil

		do {
			try store.importDatabase(from: url)
			statusMessage = "불러옴: \(url.lastPathComponent)"
		} catch {
			statusMessage = "불러오기 실패: \(error.localizedDescription)"
		}
	}

	private func openBugReportMail() {
		let version = appVersionString()
		var comps = URLComponents()
		comps.scheme = "mailto"
		comps.path = "xorpwn@gmail.com"
		comps.queryItems = [
			URLQueryItem(name: "subject", value: "andso localization bug report (\(version))"),
			URLQueryItem(
				name: "body",
				value: """
				- What happened?

				- Expected:

				- Steps to reproduce:

				- Notes (macOS / device):
				"""
			),
		]

		guard let url = comps.url else { return }
		NSWorkspace.shared.open(url)
	}

	private func backgroundStatusText() -> String {
		if let name = store.customBackgroundImageURL?.lastPathComponent {
			return "현재 배경: \(name)"
		}
		return "현재 배경: 기본 sparkle.jpg"
	}

	private func appVersionString() -> String {
		let v = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
		let b = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "?"
		return "v\(v)-\(b)"
	}

	private func refreshNotificationStatus() {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			let text: String
			switch settings.authorizationStatus {
			case .authorized:
				text = "알림 권한: 허용됨"
			case .denied:
				text = "알림 권한: 꺼짐 (설정에서 켜주세요)"
			case .notDetermined:
				text = "알림 권한: 미설정 (앱 실행 후 허용 필요)"
			case .provisional:
				text = "알림 권한: 임시 허용됨"
			case .ephemeral:
				text = "알림 권한: 임시(에페메랄)"
			@unknown default:
				text = "알림 권한: 알 수 없음"
			}

			DispatchQueue.main.async {
				notificationStatusText = text
			}
		}
	}

	private func openNotificationSettings() {
		// Best-effort: macOS System Settings deep link.
		let candidates = [
			"x-apple.systempreferences:com.apple.preference.notifications",
			"x-apple.systempreferences:com.apple.Notifications-Settings.extension",
		]
		for s in candidates {
			if let url = URL(string: s), NSWorkspace.shared.open(url) {
				return
			}
		}
	}
}
