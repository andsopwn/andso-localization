import AppKit
import SwiftUI

struct WindowSizingView: NSViewRepresentable {
	let minSize: CGSize
	let maxSize: CGSize

	func makeNSView(context: Context) -> NSView {
		let v = WindowSizingNSView()
		v.minSize = minSize
		v.maxSize = maxSize
		return v
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		guard let v = nsView as? WindowSizingNSView else { return }
		v.minSize = minSize
		v.maxSize = maxSize
		v.applySizingIfPossible()
	}
}

private final class WindowSizingNSView: NSView {
	var minSize: CGSize = .zero
	var maxSize: CGSize = .zero

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		applySizingIfPossible()
	}

	func applySizingIfPossible() {
		guard let window else { return }

		// Use content sizes so the constraints match SwiftUI layout, not the title bar.
		window.contentMinSize = NSSize(width: minSize.width, height: minSize.height)
		window.contentMaxSize = NSSize(width: maxSize.width, height: maxSize.height)
	}
}

