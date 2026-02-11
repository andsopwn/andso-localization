import AppKit
import SwiftUI

struct ContentView: View {
	@EnvironmentObject private var store: AppDataStore
	@EnvironmentObject private var tracker: AppUsageTracker
	@EnvironmentObject private var timers: MultiTimerManager
	@EnvironmentObject private var quitGuard: QuitGuard
	@Environment(\.colorScheme) private var colorScheme

	@State private var selectedDate = Date()
	@State private var showTrackingApps = false
	@State private var showSettings = false

	@State private var newTaskTitle = ""
	@State private var memoDraft = ""

	var body: some View {
		ZStack {
			SparkleBackgroundView(
				customImageURL: store.customBackgroundImageURL,
				backgroundImageChangeToken: store.backgroundImageChangeToken
			)
				.ignoresSafeArea()
				.allowsHitTesting(false)

			HStack(alignment: .top, spacing: 16) {
				sidebar
					.layoutPriority(1)
				mainPanel
					.frame(minWidth: 560)
					.frame(maxWidth: .infinity)
			}
			.padding(18)

			if quitGuard.showPrompt {
				QuitPromptToast()
					.transition(.move(edge: .top).combined(with: .opacity))
					.zIndex(10)
			}
		}
		.foregroundStyle(Theme.textPrimary(for: colorScheme))
		.background(
			WindowSizingView(
				minSize: CGSize(width: 1140, height: 780),
				maxSize: CGSize(width: 1680, height: 1080)
			)
		)
			.sheet(isPresented: $showTrackingApps) {
				TrackedAppsSheet()
					.environmentObject(store)
					.frame(minWidth: 520, minHeight: 420)
			}
			.sheet(isPresented: $showSettings) {
				SettingsSheet()
					.environmentObject(store)
					.frame(minWidth: 560, minHeight: 520)
			}
		.onAppear {
			memoDraft = store.memo(for: selectedDate)
		}
		.onChange(of: store.timerPresetsMinutes) { _, newValue in
			timers.setAllPresets(minutes: newValue)
		}
		.onChange(of: selectedDate) { _, newValue in
			memoDraft = store.memo(for: newValue)
		}
		.onChange(of: memoDraft) { _, newValue in
			store.setMemo(for: selectedDate, memo: newValue)
		}
	}

	private var sidebar: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline, spacing: 10) {
				Text("andso timer")
					.font(.system(size: 22, weight: .bold, design: .rounded))
				Spacer(minLength: 0)
				Button {
					showSettings = true
				} label: {
						Image(systemName: "gearshape.fill")
							.font(.system(size: 14, weight: .semibold))
							.padding(8)
							.background(
								RoundedRectangle(cornerRadius: 12, style: .continuous)
									.fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.85))
									.overlay(
										RoundedRectangle(cornerRadius: 12, style: .continuous)
											.strokeBorder(
												colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10),
												lineWidth: 1
											)
									)
							)
					}
					.buttonStyle(.plain)
					.help("설정")
				}

				MonthCalendarView(selectedDate: $selectedDate)
					.padding(12)
						.background(
							RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
								.fill(Theme.sectionFill(for: colorScheme))
								.overlay(
									RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
										.strokeBorder(
											colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10),
											lineWidth: 1
										)
										)
								.shadow(color: Color.black.opacity(0.12), radius: 22, x: 0, y: 10)
						)

			TimerPresetsCard(timers: timers)

			Spacer(minLength: 0)

			HStack(spacing: 8) {
				let bundleId = tracker.currentBundleId
				let isTracked = bundleId.map(store.isTracked(bundleId:)) ?? false
				let appName = tracker.currentAppName ?? bundleId ?? "알 수 없는 앱"

				Circle()
					.fill(bundleId == nil ? Color.white.opacity(0.25) : (isTracked ? Theme.accent : Color.white.opacity(0.28)))
					.frame(width: 8, height: 8)

				VStack(alignment: .leading, spacing: 2) {
					Text(bundleId == nil ? "추적 대기" : (isTracked ? "추적 중" : "추적 제외"))
						.font(.system(size: 12, weight: .semibold, design: .rounded))
						.foregroundStyle(Theme.textSecondary(for: colorScheme))

					if bundleId != nil {
						Text(appName)
							.font(.system(size: 11, weight: .semibold, design: .rounded))
							.foregroundStyle(Theme.textTertiary(for: colorScheme))
							.lineLimit(1)
					}
				}

				Spacer(minLength: 0)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 8)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color.black.opacity(0.18))
			)
			}
			.frame(minWidth: 500, idealWidth: 560, maxWidth: 640)
		}

	private var mainPanel: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .firstTextBaseline, spacing: 12) {
					Text(Theme.headerDateFormatter.string(from: selectedDate))
						.font(.system(size: 26, weight: .bold, design: .rounded))
					Spacer(minLength: 0)
					Button {
						showTrackingApps = true
					} label: {
						Text("추적 앱")
							.font(.system(size: 13, weight: .semibold, design: .rounded))
							.padding(.vertical, 8)
								.padding(.horizontal, 12)
								.background(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.85))
										.overlay(
											RoundedRectangle(cornerRadius: 14, style: .continuous)
												.strokeBorder(
													colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10),
													lineWidth: 1
												)
										)
								)
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal, 4)

				workTimeCard
				taskListCard
				completedTasksCard
				memoCard
			}
			.padding(.bottom, 20)
		}
	}

	private var workTimeCard: some View {
		let secondsById = store.appSeconds(for: selectedDate)
		let rows = store.trackedApps
			.map { app in (app: app, seconds: secondsById[app.bundleId] ?? 0) }
			.sorted(by: { $0.seconds > $1.seconds })
		let maxSeconds = max(rows.map(\.seconds).max() ?? 0, 1)
		let totalSeconds = rows.reduce(0) { $0 + $1.seconds }

			return Card("작업시간", trailing: {
				Text(Theme.formatDuration(totalSeconds))
					.font(.system(size: 13, weight: .semibold, design: .rounded))
					.foregroundStyle(Theme.textSecondary(for: colorScheme))
					.monospacedDigit()
			}) {
				if store.trackedApps.isEmpty {
					HStack(spacing: 12) {
						Text("추적할 앱이 없습니다.")
							.foregroundStyle(Theme.textSecondary(for: colorScheme))
						Spacer(minLength: 0)
						Button {
							showTrackingApps = true
						} label: {
						Text("추가하기")
							.font(.system(size: 13, weight: .semibold, design: .rounded))
							.padding(.vertical, 8)
							.padding(.horizontal, 12)
							.background(
								RoundedRectangle(cornerRadius: 14, style: .continuous)
									.fill(Theme.accent.opacity(0.18))
							)
					}
					.buttonStyle(.plain)
				}
			} else {
				VStack(alignment: .leading, spacing: 10) {
					ForEach(rows, id: \.app.bundleId) { row in
						UsageRowView(
							app: row.app,
							seconds: row.seconds,
							maxSeconds: maxSeconds
						)
					}
				}
			}
		}
	}

	private var taskListCard: some View {
		let tasks = store.tasks(for: selectedDate).filter { !$0.isCompleted }
		return Card("작업목록") {
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 10) {
					TextField("할 일을 추가...", text: $newTaskTitle)
						.textFieldStyle(.plain)
						.padding(.vertical, 10)
						.padding(.horizontal, 12)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(Color.white.opacity(0.10))
						)
						.onSubmit(addTask)

					Button(action: addTask) {
						Image(systemName: "plus")
							.font(.system(size: 14, weight: .bold))
							.foregroundStyle(Theme.ink)
							.padding(10)
							.background(
								Circle().fill(Theme.warm)
							)
					}
					.buttonStyle(.plain)
					.help("작업 추가")
				}

					if tasks.isEmpty {
						Text("아직 작업이 없어요.")
							.foregroundStyle(Theme.textSecondary(for: colorScheme))
					} else {
					VStack(alignment: .leading, spacing: 8) {
						ForEach(tasks) { task in
							let day = selectedDate
							let id = task.id
							TaskRow(
								title: task.title,
								isCompleted: task.isCompleted,
								onToggle: { newValue in
									Task { @MainActor in
										withAnimation(.snappy(duration: 0.25)) {
											AppDataStore.shared.setTaskCompleted(for: day, id: id, isCompleted: newValue)
										}
									}
								},
								onDelete: {
									Task { @MainActor in
										withAnimation(.snappy(duration: 0.25)) {
											AppDataStore.shared.deleteTask(for: day, id: id)
										}
									}
								}
							)
						}
					}
				}
			}
		}
	}

	private var completedTasksCard: some View {
		let tasks = store.tasks(for: selectedDate)
			.filter { $0.isCompleted }
			.sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })

		return Card("완료한 작업") {
				if tasks.isEmpty {
					Text("완료한 작업이 아직 없어요.")
						.foregroundStyle(Theme.textSecondary(for: colorScheme))
				} else {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(tasks) { task in
						let day = selectedDate
						let id = task.id
						TaskRow(
							title: task.title,
							isCompleted: task.isCompleted,
							onToggle: { newValue in
								Task { @MainActor in
									withAnimation(.snappy(duration: 0.25)) {
										AppDataStore.shared.setTaskCompleted(for: day, id: id, isCompleted: newValue)
									}
								}
							},
							onDelete: {
								Task { @MainActor in
									withAnimation(.snappy(duration: 0.25)) {
										AppDataStore.shared.deleteTask(for: day, id: id)
									}
								}
							}
						)
					}
				}
			}
		}
	}

	private var memoCard: some View {
		Card("메모") {
			ZStack(alignment: .topLeading) {
				TextEditor(text: $memoDraft)
					.font(.system(size: 13, weight: .regular, design: .rounded))
					.scrollContentBackground(.hidden)
					.padding(10)
					.background(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.fill(Color.white.opacity(0.10))
					)
					.frame(minHeight: 140)

					if memoDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						Text("오늘 한 일, 내일 할 일, 아이디어…")
							.font(.system(size: 13, weight: .regular, design: .rounded))
							.foregroundStyle(Theme.textTertiary(for: colorScheme))
							// TextEditor on macOS uses an internal textContainerInset (~5pt).
							// Match that + our outer padding so the placeholder aligns with the caret.
							.padding(.horizontal, 15)
							.padding(.vertical, 15)
							.allowsHitTesting(false)
					}
			}
		}
	}

	private func addTask() {
		let title = newTaskTitle
		newTaskTitle = ""
		withAnimation(.snappy(duration: 0.25)) {
			store.addTask(for: selectedDate, title: title)
		}
	}
}

private struct TaskRow: View {
	@Environment(\.colorScheme) private var colorScheme

	let title: String
	let isCompleted: Bool
	let onToggle: @Sendable (Bool) -> Void
	let onDelete: @Sendable () -> Void

	var body: some View {
		HStack(spacing: 10) {
				Toggle(isOn: Binding(get: { isCompleted }, set: { newValue in onToggle(newValue) })) {
					Text(title)
						.font(.system(size: 13, weight: .semibold, design: .rounded))
						.foregroundStyle(isCompleted ? Theme.textSecondary(for: colorScheme) : Theme.textPrimary(for: colorScheme))
				}
				.toggleStyle(.checkbox)

			Spacer(minLength: 0)

				Button(role: .destructive, action: onDelete) {
					Image(systemName: "trash")
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(Theme.textTertiary(for: colorScheme))
						.padding(6)
						.background(
							RoundedRectangle(cornerRadius: 10, style: .continuous)
								.fill(Color.white.opacity(0.08))
					)
			}
			.buttonStyle(.plain)
		}
	}
}

private struct UsageRowView: View {
	@Environment(\.colorScheme) private var colorScheme

	let app: TrackedApp
	let seconds: Double
	let maxSeconds: Double

	var body: some View {
		HStack(spacing: 12) {
			AppIcon(bundleId: app.bundleId)
				.frame(width: 28, height: 28)

			VStack(alignment: .leading, spacing: 6) {
				Text(app.displayName)
					.font(.system(size: 13, weight: .semibold, design: .rounded))
					.lineLimit(1)

				GeometryReader { geo in
					let w = geo.size.width
					let ratio = min(1, seconds / maxSeconds)
					ZStack(alignment: .leading) {
						Capsule()
							.fill(Color.white.opacity(0.10))
						Capsule()
							.fill(
								LinearGradient(
									colors: [Theme.accent, Theme.warm],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.frame(width: max(10, w * ratio))
							.opacity(seconds <= 0 ? 0.25 : 1)
					}
				}
				.frame(height: 8)
			}

			Spacer(minLength: 0)

				Text(Theme.formatDuration(seconds))
					.font(.system(size: 12, weight: .semibold, design: .rounded))
					.foregroundStyle(Theme.textSecondary(for: colorScheme))
					.monospacedDigit()
			}
			.padding(.vertical, 6)
		}
	}

private struct AppIcon: View {
	@Environment(\.colorScheme) private var colorScheme

	let bundleId: String

	var body: some View {
		let icon = iconForBundleId(bundleId)
		ZStack {
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(Color.white.opacity(0.10))

			if let icon {
				Image(nsImage: icon)
					.resizable()
					.scaledToFit()
					.padding(3)
			} else {
				Image(systemName: "app.dashed")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(Theme.textTertiary(for: colorScheme))
			}
		}
	}

	private func iconForBundleId(_ bundleId: String) -> NSImage? {
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
		return NSWorkspace.shared.icon(forFile: url.path)
	}
}

private struct SparkleBackgroundView: View {
	private static let sparkleImage: NSImage? = {
		guard let url = Bundle.main.url(forResource: "sparkle", withExtension: "jpg") else { return nil }
		return NSImage(contentsOf: url)
	}()

	let customImageURL: URL?
	let backgroundImageChangeToken: UInt64

	@State private var customImage: NSImage?

	var body: some View {
		GeometryReader { geo in
			ZStack {
					if let img = customImage ?? Self.sparkleImage {
						Image(nsImage: img)
							.resizable()
							.scaledToFill()
							.frame(width: geo.size.width, height: geo.size.height)
							.clipped()
							.scaleEffect(1.06)
							.blur(radius: 2)
					} else {
						Color.black.opacity(0.06)
					}

					LinearGradient(
						stops: [
							.init(color: Theme.ink.opacity(0.78), location: 0.00),
							.init(color: Theme.ink.opacity(0.45), location: 0.45),
							.init(color: Theme.ink.opacity(0.72), location: 1.00),
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
					.blendMode(.overlay)

					LinearGradient(
						stops: [
							.init(color: Color.black.opacity(0.45), location: 0.00),
							.init(color: Color.black.opacity(0.14), location: 0.45),
							.init(color: Color.black.opacity(0.48), location: 1.00),
						],
						startPoint: .top,
						endPoint: .bottom
					)
			}
		}
		.onAppear {
			reloadImage()
		}
		.onChange(of: customImageURL?.path ?? "") { _, _ in
			reloadImage()
		}
		.onChange(of: backgroundImageChangeToken) { _, _ in
			reloadImage()
		}
	}

	private func reloadImage() {
		guard let customImageURL else {
			customImage = nil
			return
		}
		customImage = NSImage(contentsOf: customImageURL)
	}
}

private struct QuitPromptToast: View {
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		VStack {
			Text("hold cmd+q to quit")
				.font(.system(size: 12, weight: .semibold, design: .rounded))
				.foregroundStyle(Theme.textPrimary(for: colorScheme))
				.padding(.vertical, 10)
				.padding(.horizontal, 14)
				.background(
					Capsule(style: .continuous)
						.fill(Color.black.opacity(0.44))
						.overlay(
							Capsule(style: .continuous)
								.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
						)
				)
				.padding(.top, 16)
			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.allowsHitTesting(false)
	}
}
