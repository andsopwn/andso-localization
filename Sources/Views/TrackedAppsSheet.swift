import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TrackedAppsSheet: View {
	@EnvironmentObject private var store: AppDataStore
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme

	@State private var errorMessage: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text("추적 앱")
					.font(.system(size: 20, weight: .bold, design: .rounded))
				Spacer(minLength: 0)
				Button("닫기") { dismiss() }
					.buttonStyle(.borderedProminent)
			}

			Text("선택한 앱이 활성화된 시간만 ‘작업시간’에 기록됩니다.")
				.foregroundStyle(Theme.textSecondary(for: colorScheme))

			if let errorMessage {
				Text(errorMessage)
					.foregroundStyle(.red)
					.font(.system(size: 12, weight: .semibold, design: .rounded))
			}

			Divider()

			ScrollView {
				VStack(alignment: .leading, spacing: 10) {
					if store.trackedApps.isEmpty {
						Text("아직 추적 앱이 없습니다. 아래 버튼으로 앱(.app)을 추가해보세요.")
							.foregroundStyle(Theme.textSecondary(for: colorScheme))
							.padding(.vertical, 10)
					} else {
						ForEach(store.trackedApps) { app in
							TrackedAppRow(app: app) {
								withAnimation(.snappy(duration: 0.25)) {
									store.removeTrackedApp(bundleId: app.bundleId)
								}
							}
						}
					}
				}
				.padding(.vertical, 6)
			}

			HStack(spacing: 10) {
				Button {
					pickAppBundle()
				} label: {
					Label("앱 추가…", systemImage: "plus")
				}
				.buttonStyle(.borderedProminent)

				Button {
					errorMessage = nil
				} label: {
					Label("메시지 지우기", systemImage: "xmark.circle")
				}
				.buttonStyle(.bordered)
				.disabled(errorMessage == nil)

				Spacer(minLength: 0)
			}
		}
		.padding(18)
		.foregroundStyle(Theme.textPrimary(for: colorScheme))
	}

	private func pickAppBundle() {
		errorMessage = nil

		let panel = NSOpenPanel()
		panel.title = "추적할 앱 선택"
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.applicationBundle]

		let res = panel.runModal()
		guard res == .OK, let url = panel.url else { return }

		guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else {
			errorMessage = "선택한 앱에서 Bundle ID를 읽지 못했어요."
			return
		}

		let displayName =
			(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
			?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
			?? FileManager.default.displayName(atPath: url.path)

		withAnimation(.snappy(duration: 0.25)) {
			store.addTrackedApp(bundleId: bundleId, displayName: displayName)
		}
	}
}

private struct TrackedAppRow: View {
	@Environment(\.colorScheme) private var colorScheme

	let app: TrackedApp
	let onRemove: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(Color.white.opacity(0.08))
				if let icon = iconForBundleId(app.bundleId) {
					Image(nsImage: icon)
						.resizable()
						.scaledToFit()
						.padding(4)
					} else {
						Image(systemName: "app.dashed")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(Theme.textTertiary(for: colorScheme))
					}
				}
			.frame(width: 34, height: 34)

				VStack(alignment: .leading, spacing: 4) {
					Text(app.displayName)
						.font(.system(size: 13, weight: .semibold, design: .rounded))
					Text(app.bundleId)
						.font(.system(size: 11, weight: .regular, design: .monospaced))
						.foregroundStyle(Theme.textTertiary(for: colorScheme))
						.lineLimit(1)
				}

			Spacer(minLength: 0)

			Button(role: .destructive, action: onRemove) {
				Label("삭제", systemImage: "trash")
					.labelStyle(.iconOnly)
			}
			.buttonStyle(.bordered)
		}
			.padding(10)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(Theme.sectionFill(for: colorScheme))
					.overlay(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.strokeBorder(
								colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10),
								lineWidth: 1
							)
					)
			)
	}

	private func iconForBundleId(_ bundleId: String) -> NSImage? {
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
		return NSWorkspace.shared.icon(forFile: url.path)
	}
}
