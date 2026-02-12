import AppKit

@MainActor
enum AppIconManager {
	struct Option: Identifiable, Hashable {
		let id: String
		let title: String
		let resourceName: String?
		let resourceExtension: String?
	}

	static let defaultIconId = "default"
	static let catIconId = "cat"
	static let whaleIconId = "whale"

	static let options: [Option] = [
		Option(id: defaultIconId, title: "기본", resourceName: "AppIcon", resourceExtension: "icns"),
		Option(id: catIconId, title: "고양이", resourceName: "cat", resourceExtension: "png"),
		Option(id: whaleIconId, title: "고래", resourceName: "whale", resourceExtension: "png"),
	]

	static func normalizeIconId(_ iconId: String?) -> String {
		guard let iconId, options.contains(where: { $0.id == iconId }) else { return defaultIconId }
		return iconId
	}

	static func displayTitle(for iconId: String) -> String {
		let normalized = normalizeIconId(iconId)
		return options.first(where: { $0.id == normalized })?.title ?? "기본"
	}

	static func image(for iconId: String) -> NSImage? {
		let normalized = normalizeIconId(iconId)
		let option = options.first(where: { $0.id == normalized }) ?? options[0]

		if normalized == defaultIconId {
			return defaultAppIconImage()
		}

		guard let name = option.resourceName, let ext = option.resourceExtension else {
			return defaultAppIconImage()
		}

		if let url = Bundle.main.url(forResource: name, withExtension: ext), let image = NSImage(contentsOf: url) {
			return normalizedRoundedIcon(from: image) ?? image
		}
		return defaultAppIconImage()
	}

	static func apply(iconId: String) {
		let normalized = normalizeIconId(iconId)

		// For the default icon, remove any runtime override so macOS keeps the
		// original bundle icon (this avoids square fallback rendering while running).
		if normalized == defaultIconId {
			NSApp.applicationIconImage = nil
			return
		}

		guard let image = image(for: normalized) else { return }
		NSApp.applicationIconImage = image
	}

	private static func defaultAppIconImage() -> NSImage? {
		if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
			let image = NSImage(contentsOf: url)
		{
			return image
		}
		return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
	}

	private static func normalizedRoundedIcon(from source: NSImage) -> NSImage? {
		let canvasSide: CGFloat = 1024
		let canvasSize = NSSize(width: canvasSide, height: canvasSide)
		let drawRect = NSRect(origin: .zero, size: canvasSize)
		let contentInset = canvasSide * 0.11
		let iconRect = drawRect.insetBy(dx: contentInset, dy: contentInset)
		let corner = iconRect.width * 0.225
		let preparedSource = trimmedByAlphaIfNeeded(source) ?? source

		let result = NSImage(size: canvasSize)
		result.lockFocus()
		defer { result.unlockFocus() }

		guard let ctx = NSGraphicsContext.current else { return nil }
		ctx.imageInterpolation = .high

		NSColor.clear.setFill()
		drawRect.fill()

		let clip = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner)
		clip.addClip()

		let sourceSize = preparedSource.size
		guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
		let scale = max(iconRect.width / sourceSize.width, iconRect.height / sourceSize.height)
		let targetSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
		let targetRect = NSRect(
			x: iconRect.midX - (targetSize.width * 0.5),
			y: iconRect.midY - (targetSize.height * 0.5),
			width: targetSize.width,
			height: targetSize.height
		)

		preparedSource.draw(
			in: targetRect,
			from: NSRect(origin: .zero, size: preparedSource.size),
			operation: .sourceOver,
			fraction: 1.0,
			respectFlipped: true,
			hints: [.interpolation: NSImageInterpolation.high]
		)
		return result
	}

	private static func trimmedByAlphaIfNeeded(_ source: NSImage) -> NSImage? {
		guard
			let tiff = source.tiffRepresentation,
			let rep = NSBitmapImageRep(data: tiff)
		else {
			return nil
		}

		guard rep.hasAlpha else { return source }

		let width = rep.pixelsWide
		let height = rep.pixelsHigh
		guard width > 0, height > 0 else { return source }

		var minX = width
		var minY = height
		var maxX = -1
		var maxY = -1

		let threshold: CGFloat = 0.03
		for y in 0..<height {
			for x in 0..<width {
				guard let color = rep.colorAt(x: x, y: y) else { continue }
				if color.alphaComponent > threshold {
					if x < minX { minX = x }
					if y < minY { minY = y }
					if x > maxX { maxX = x }
					if y > maxY { maxY = y }
				}
			}
		}

		guard maxX >= minX, maxY >= minY else { return source }
		let cropRect = CGRect(
			x: minX,
			y: minY,
			width: (maxX - minX) + 1,
			height: (maxY - minY) + 1
		)

		guard let cg = rep.cgImage?.cropping(to: cropRect) else { return source }
		return NSImage(cgImage: cg, size: NSSize(width: cropRect.width, height: cropRect.height))
	}
}
