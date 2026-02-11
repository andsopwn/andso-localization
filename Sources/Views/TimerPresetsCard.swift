import SwiftUI

struct TimerPresetsCard: View {
	@EnvironmentObject private var store: AppDataStore
	@Environment(\.colorScheme) private var colorScheme

	@ObservedObject var timers: MultiTimerManager

	var body: some View {
		Card("타이머") {
			HStack(spacing: 12) {
				ForEach(timers.slots) { slot in
					let minutesBinding = Binding(
						get: { store.timerPresetMinutes(at: slot.id) },
						set: { newMinutes in
							store.setTimerPresetMinutes(newMinutes, at: slot.id)
							timers.setPresetMinutes(newMinutes, for: slot.id)
						}
					)
					TimerSlotCard(
						index: slot.id,
						minutes: minutesBinding,
						remainingSeconds: slot.remainingSeconds,
						isRunning: slot.isRunning,
						onToggle: {
							timers.toggleRunning(for: slot.id)
						},
						onReset: {
							timers.reset(slot.id)
						}
					)
				}
			}
		}
	}
}

private struct TimerSlotCard: View {
	@Environment(\.colorScheme) private var colorScheme

	let index: Int
	@Binding var minutes: Int
	let remainingSeconds: Int
	let isRunning: Bool
	let onToggle: () -> Void
	let onReset: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .firstTextBaseline, spacing: 10) {
				Text("타이머 \(index + 1)")
					.font(.system(size: 12, weight: .bold, design: .rounded))
					.foregroundStyle(Theme.textSecondary(for: colorScheme))
				Spacer(minLength: 0)
			}

			Text(Theme.formatDuration(Double(remainingSeconds)))
				.font(.system(size: 22, weight: .bold, design: .rounded))
				.monospacedDigit()

			HStack(spacing: 10) {
				Button(action: onToggle) {
					Image(systemName: isRunning ? "pause.fill" : "play.fill")
						.font(.system(size: 13, weight: .bold))
						.foregroundStyle(Theme.ink)
						.frame(width: 34, height: 34)
						.background(Circle().fill(isRunning ? Theme.warm : Theme.accent))
				}
				.buttonStyle(.plain)
				.help(isRunning ? "일시정지" : "시작")

				Button(action: onReset) {
					Image(systemName: "arrow.counterclockwise")
						.font(.system(size: 12, weight: .bold))
						.foregroundStyle(Theme.textSecondary(for: colorScheme))
						.frame(width: 34, height: 34)
						.background(
							Circle()
								.fill(Color.white.opacity(0.10))
								.overlay(
									Circle()
										.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
								)
						)
				}
				.buttonStyle(.plain)
				.help("리셋")

				Spacer(minLength: 0)
			}

			HStack(spacing: 10) {
				Text("\(minutes)분")
					.font(.system(size: 12, weight: .semibold, design: .rounded))
					.foregroundStyle(Theme.textSecondary(for: colorScheme))
					.monospacedDigit()

				Spacer(minLength: 0)

				Stepper {
					EmptyView()
				} onIncrement: {
					stepUp()
				} onDecrement: {
					stepDown()
				}
				.labelsHidden()
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.78))
				.overlay(
					RoundedRectangle(cornerRadius: 20, style: .continuous)
						.strokeBorder(
							colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10),
							lineWidth: 1
						)
				)
		)
	}

	private func stepUp() {
		let v = minutes
		let maxMinutes = 24 * 60

		let next: Int
		if v < 5 {
			next = 5
		} else if v % 5 != 0 {
			next = ((v / 5) + 1) * 5
		} else {
			next = v + 5
		}

		minutes = min(next, maxMinutes)
	}

	private func stepDown() {
		let v = minutes

		let next: Int
		if v <= 5 {
			next = 1
		} else if v % 5 != 0 {
			next = (v / 5) * 5
		} else {
			next = v - 5
		}

		minutes = max(next, 1)
	}
}
