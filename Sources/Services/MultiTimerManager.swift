import AppKit
import Foundation

@MainActor
final class MultiTimerManager: ObservableObject {
	struct Slot: Identifiable, Hashable {
		let id: Int
		var durationSeconds: Int
		var remainingSeconds: Int
		var isRunning: Bool
		var lastTick: Date?
	}

	@Published private(set) var slots: [Slot]

	private var ticker: Timer?

	init(presetMinutes: [Int] = [60, 30, 15]) {
		let minutes = Self.sanitizePresets(presetMinutes)
		self.slots = minutes.enumerated().map { idx, m in
			let dur = m * 60
			return Slot(id: idx, durationSeconds: dur, remainingSeconds: dur, isRunning: false, lastTick: nil)
		}
	}

	func setAllPresets(minutes: [Int]) {
		let presets = Self.sanitizePresets(minutes)
		for idx in 0..<3 {
			let dur = presets[idx] * 60
			if slots.indices.contains(idx), slots[idx].durationSeconds != dur {
				setPresetMinutes(presets[idx], for: idx)
			}
		}
	}

	func setPresetMinutes(_ minutes: Int, for index: Int) {
		guard slots.indices.contains(index) else { return }
		let clampedMinutes = min(max(minutes, 1), 24 * 60)
		let dur = clampedMinutes * 60

		var slot = slots[index]
		slot.durationSeconds = dur
		slot.remainingSeconds = dur
		slot.isRunning = false
		slot.lastTick = nil
		slots[index] = slot

		stopTickerIfIdle()
	}

	func toggleRunning(for index: Int) {
		guard slots.indices.contains(index) else { return }
		var slot = slots[index]

		if slot.isRunning {
			slot.isRunning = false
			slot.lastTick = nil
			slots[index] = slot
			stopTickerIfIdle()
			return
		}

		if slot.remainingSeconds <= 0 {
			slot.remainingSeconds = slot.durationSeconds
		}
		slot.isRunning = true
		slot.lastTick = Date()
		slots[index] = slot
		ensureTicker()
	}

	func reset(_ index: Int) {
		guard slots.indices.contains(index) else { return }
		var slot = slots[index]
		slot.isRunning = false
		slot.lastTick = nil
		slot.remainingSeconds = slot.durationSeconds
		slots[index] = slot
		stopTickerIfIdle()
	}

	private func ensureTicker() {
		guard ticker == nil else { return }
		ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			Task { @MainActor in
				self?.tick()
			}
		}
	}

	private func stopTickerIfIdle() {
		if slots.allSatisfy({ !$0.isRunning }) {
			ticker?.invalidate()
			ticker = nil
		}
	}

	private func tick() {
		let now = Date()
		var anyRunning = false

		for idx in slots.indices {
			var slot = slots[idx]
			guard slot.isRunning else { continue }
			anyRunning = true

			let last = slot.lastTick ?? now
			let elapsed = Int(now.timeIntervalSince(last).rounded(.down))
			if elapsed <= 0 { continue }

			slot.remainingSeconds -= elapsed
			slot.lastTick = now

			if slot.remainingSeconds <= 0 {
				slot.remainingSeconds = 0
				slot.isRunning = false
				slot.lastTick = nil
				playAlarm()
				postFinishedNotification(for: slot)
			}

			slots[idx] = slot
		}

		if !anyRunning {
			stopTickerIfIdle()
		}
	}

	private func playAlarm() {
		// Soft default system sound. This works without bundling any audio assets.
		if let sound = NSSound(named: NSSound.Name("Glass")) {
			sound.play()
		} else {
			NSSound.beep()
		}
	}

	private func postFinishedNotification(for slot: Slot) {
		let minutes = max(1, Int(round(Double(slot.durationSeconds) / 60.0)))
		NotificationService.postTimerFinished(
			title: "타이머 종료",
			body: "타이머 \(slot.id + 1) (\(minutes)분)이 종료되었습니다."
		)
	}

	private static func sanitizePresets(_ minutes: [Int]) -> [Int] {
		var result = [60, 30, 15]
		for idx in 0..<min(3, minutes.count) {
			result[idx] = min(max(minutes[idx], 1), 24 * 60)
		}
		return result
	}
}
