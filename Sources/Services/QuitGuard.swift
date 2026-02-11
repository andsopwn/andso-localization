import AppKit
import Foundation
import SwiftUI

@MainActor
final class QuitGuard: ObservableObject {
	@Published var showPrompt = false

	private var lastRequestAt: Date?
	private var hideTask: Task<Void, Never>?

	func handleQuitCommand() {
		let now = Date()
		if let last = lastRequestAt, now.timeIntervalSince(last) < 1.6 {
			NSApp.terminate(nil)
			return
		}

		lastRequestAt = now
		withAnimation(.snappy(duration: 0.18)) {
			showPrompt = true
		}

		hideTask?.cancel()
		hideTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: 1_200_000_000)
			await MainActor.run {
				withAnimation(.snappy(duration: 0.18)) {
					self?.showPrompt = false
				}
			}
		}
	}
}
