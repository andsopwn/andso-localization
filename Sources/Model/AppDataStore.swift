import Foundation

@MainActor
final class AppDataStore: ObservableObject {
	static let shared = AppDataStore()

	@Published private(set) var trackedApps: [TrackedApp] = []
	@Published private(set) var days: [String: DayData] = [:]
	@Published private(set) var timerPresetsMinutes: [Int] = AppDataStore.defaultTimerPresetsMinutes
	@Published private(set) var backgroundImageFilename: String?
	@Published private(set) var backgroundImageChangeToken: UInt64 = 0

	private static let schemaVersion = 1
	private static let defaultTimerPresetsMinutes = [60, 30, 15]
	private static let storageDirectoryName = "andso"
	private static let legacyStorageDirectoryName = "PTimer"

	private static let dayKeyFormatter: DateFormatter = {
		let f = DateFormatter()
		f.calendar = Calendar.autoupdatingCurrent
		f.locale = Locale(identifier: "en_US_POSIX")
		f.timeZone = TimeZone.autoupdatingCurrent
		f.dateFormat = "yyyy-MM-dd"
		return f
	}()

	private var pendingSave: Task<Void, Never>?

	private init() {
		loadFromDisk()
	}

	func dayKey(for date: Date) -> String {
		Self.dayKeyFormatter.string(from: date)
	}

	func isTracked(bundleId: String) -> Bool {
		trackedApps.contains(where: { $0.bundleId == bundleId })
	}

	func addTrackedApp(bundleId: String, displayName: String) {
		guard !bundleId.isEmpty else { return }
		if let idx = trackedApps.firstIndex(where: { $0.bundleId == bundleId }) {
			trackedApps[idx].displayName = displayName
		} else {
			trackedApps.append(TrackedApp(bundleId: bundleId, displayName: displayName))
		}
		trackedApps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
		scheduleSave()
	}

	func removeTrackedApp(bundleId: String) {
		trackedApps.removeAll(where: { $0.bundleId == bundleId })
		scheduleSave()
	}

	func dayData(for date: Date) -> DayData {
		days[dayKey(for: date)] ?? .empty
	}

	func appSeconds(for date: Date) -> [String: Double] {
		dayData(for: date).appSeconds
	}

	func memo(for date: Date) -> String {
		dayData(for: date).memo
	}

	func setMemo(for date: Date, memo: String) {
		let key = dayKey(for: date)
		var day = days[key] ?? .empty
		day.memo = memo
		days[key] = day
		scheduleSave()
	}

	func tasks(for date: Date) -> [TaskItem] {
		dayData(for: date).tasks
	}

	func addTask(for date: Date, title: String) {
		let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		let key = dayKey(for: date)
		var day = days[key] ?? .empty
		day.tasks.insert(
			TaskItem(
				id: UUID(),
				title: trimmed,
				isCompleted: false,
				createdAt: Date(),
				completedAt: nil
			),
			at: 0
		)
		days[key] = day
		scheduleSave()
	}

	func deleteTask(for date: Date, id: UUID) {
		let key = dayKey(for: date)
		var day = days[key] ?? .empty
		day.tasks.removeAll(where: { $0.id == id })
		days[key] = day
		scheduleSave()
	}

	func setTaskCompleted(for date: Date, id: UUID, isCompleted: Bool) {
		let key = dayKey(for: date)
		var day = days[key] ?? .empty
		guard let idx = day.tasks.firstIndex(where: { $0.id == id }) else { return }
		day.tasks[idx].isCompleted = isCompleted
		day.tasks[idx].completedAt = isCompleted ? Date() : nil
		days[key] = day
		scheduleSave()
	}

	func addUsage(bundleId: String, at date: Date, seconds: Double) {
		guard seconds > 0 else { return }
		let key = dayKey(for: date)
		var day = days[key] ?? .empty
		day.appSeconds[bundleId, default: 0] += seconds
		days[key] = day
		scheduleSave()
	}

	func saveNow() {
		pendingSave?.cancel()
		pendingSave = nil
		writeToDisk()
	}

	func timerPresetMinutes(at index: Int) -> Int {
		guard timerPresetsMinutes.indices.contains(index) else { return Self.defaultTimerPresetsMinutes.first ?? 60 }
		return timerPresetsMinutes[index]
	}

	func setTimerPresetMinutes(_ minutes: Int, at index: Int) {
		guard timerPresetsMinutes.indices.contains(index) else { return }
		timerPresetsMinutes[index] = clampPresetMinutes(minutes)
		scheduleSave()
	}

	var customBackgroundImageURL: URL? {
		guard let name = sanitizedBackgroundFilename(backgroundImageFilename) else { return nil }
		return storageDirectoryURL.appendingPathComponent(name)
	}

	func setCustomBackgroundImage(from sourceURL: URL) throws {
		let ext = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !ext.isEmpty else {
			throw BackgroundImageError.invalidImage
		}

		try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)

		let destinationName = "background.\(ext)"
		let destinationURL = storageDirectoryURL.appendingPathComponent(destinationName)
		let tempURL = storageDirectoryURL.appendingPathComponent("background-import-\(UUID().uuidString).\(ext)")

		if FileManager.default.fileExists(atPath: tempURL.path) {
			try? FileManager.default.removeItem(at: tempURL)
		}
		try FileManager.default.copyItem(at: sourceURL, to: tempURL)

		if FileManager.default.fileExists(atPath: destinationURL.path) {
			_ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL, backupItemName: nil, options: [])
		} else {
			try FileManager.default.moveItem(at: tempURL, to: destinationURL)
		}

		if let oldName = backgroundImageFilename, oldName != destinationName {
			let oldURL = storageDirectoryURL.appendingPathComponent(oldName)
			if FileManager.default.fileExists(atPath: oldURL.path) {
				try? FileManager.default.removeItem(at: oldURL)
			}
		}

		backgroundImageFilename = destinationName
		bumpBackgroundChangeToken()
		scheduleSave()
	}

	func resetCustomBackgroundImage() {
		if let oldName = backgroundImageFilename {
			let oldURL = storageDirectoryURL.appendingPathComponent(oldName)
			if FileManager.default.fileExists(atPath: oldURL.path) {
				try? FileManager.default.removeItem(at: oldURL)
			}
		}
		backgroundImageFilename = nil
		bumpBackgroundChangeToken()
		scheduleSave()
	}

	func resetAllData() {
		trackedApps = []
		days = [:]
		timerPresetsMinutes = Self.defaultTimerPresetsMinutes
		if let oldName = backgroundImageFilename {
			let oldURL = storageDirectoryURL.appendingPathComponent(oldName)
			if FileManager.default.fileExists(atPath: oldURL.path) {
				try? FileManager.default.removeItem(at: oldURL)
			}
		}
		backgroundImageFilename = nil
		scheduleSave()
	}

	var databaseFileURLForSharing: URL {
		databaseFileURL
	}

	func exportDatabase(to url: URL) throws {
		let file = DatabaseFile(
			schemaVersion: Self.schemaVersion,
			trackedApps: trackedApps,
			days: days,
			timerPresetsMinutes: timerPresetsMinutes,
			backgroundImageFilename: backgroundImageFilename
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601

		let data = try encoder.encode(file)
		try data.write(to: url, options: [.atomic])
	}

	func importDatabase(from url: URL) throws {
		let data = try Data(contentsOf: url)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		let file = try decoder.decode(DatabaseFile.self, from: data)
		guard file.schemaVersion == Self.schemaVersion else {
			throw ImportError.unsupportedSchema(expected: Self.schemaVersion, actual: file.schemaVersion)
		}

		trackedApps = file.trackedApps
		days = file.days
		timerPresetsMinutes = sanitizedTimerPresets(file.timerPresetsMinutes)
			backgroundImageFilename = sanitizedBackgroundFilename(file.backgroundImageFilename)
			bumpBackgroundChangeToken()
			saveNow()
	}

	// MARK: - Disk I/O

	private var storageDirectoryURL: URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		return base.appendingPathComponent(Self.storageDirectoryName, isDirectory: true)
	}

	private var legacyStorageDirectoryURL: URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		return base.appendingPathComponent(Self.legacyStorageDirectoryName, isDirectory: true)
	}

	private var databaseFileURL: URL {
		storageDirectoryURL.appendingPathComponent("database.json")
	}

	private var legacyDatabaseFileURL: URL {
		legacyStorageDirectoryURL.appendingPathComponent("database.json")
	}

	private func scheduleSave() {
		pendingSave?.cancel()
		pendingSave = Task { [weak self] in
			// Debounce disk writes (tasks/memo typing + periodic usage tracking).
			try? await Task.sleep(nanoseconds: 750_000_000)
			self?.writeToDisk()
		}
	}

	private func loadFromDisk() {
		do {
			try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)

			let url = databaseFileURL
			var readURL = url
			var loadedFromLegacy = false

			if !FileManager.default.fileExists(atPath: url.path) {
				let legacyURL = legacyDatabaseFileURL
				if FileManager.default.fileExists(atPath: legacyURL.path) {
					readURL = legacyURL
					loadedFromLegacy = true
				} else {
					timerPresetsMinutes = Self.defaultTimerPresetsMinutes
					backgroundImageFilename = nil
					return
				}
			}

			let data = try Data(contentsOf: readURL)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let file = try decoder.decode(DatabaseFile.self, from: data)
			guard file.schemaVersion == Self.schemaVersion else {
				// For now, ignore mismatched schema and start fresh.
				return
			}
			trackedApps = file.trackedApps
			days = file.days
			timerPresetsMinutes = sanitizedTimerPresets(file.timerPresetsMinutes)
				backgroundImageFilename = sanitizedBackgroundFilename(file.backgroundImageFilename)
				bumpBackgroundChangeToken()

			if loadedFromLegacy {
				// Migrate to the new storage directory name on first launch.
				writeToDisk()
			}
		} catch {
			// Best-effort: start empty.
			trackedApps = []
			days = [:]
			timerPresetsMinutes = Self.defaultTimerPresetsMinutes
				backgroundImageFilename = nil
				bumpBackgroundChangeToken()
			}
		}

	private func writeToDisk() {
		do {
			try FileManager.default.createDirectory(at: storageDirectoryURL, withIntermediateDirectories: true)
			let file = DatabaseFile(
				schemaVersion: Self.schemaVersion,
				trackedApps: trackedApps,
				days: days,
				timerPresetsMinutes: timerPresetsMinutes,
				backgroundImageFilename: backgroundImageFilename
			)

			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			encoder.dateEncodingStrategy = .iso8601
			let data = try encoder.encode(file)

			let url = databaseFileURL
			let tmpURL = url.appendingPathExtension("tmp")
			try data.write(to: tmpURL, options: [.atomic])

			if FileManager.default.fileExists(atPath: url.path) {
				_ = try FileManager.default.replaceItemAt(url, withItemAt: tmpURL, backupItemName: nil, options: [])
			} else {
				try FileManager.default.moveItem(at: tmpURL, to: url)
			}
		} catch {
			// Ignore disk write errors for now.
		}
	}

	private func sanitizedTimerPresets(_ input: [Int]?) -> [Int] {
		var result = Self.defaultTimerPresetsMinutes
		guard let input else { return result }
		for idx in 0..<min(3, input.count) {
			result[idx] = clampPresetMinutes(input[idx])
		}
		return result
	}

	private func clampPresetMinutes(_ minutes: Int) -> Int {
		min(max(minutes, 1), 24 * 60)
	}

	private func bumpBackgroundChangeToken() {
		backgroundImageChangeToken &+= 1
	}

	private func sanitizedBackgroundFilename(_ filename: String?) -> String? {
		guard let filename, !filename.isEmpty else { return nil }
		let safe = (filename as NSString).lastPathComponent
		guard safe == filename else { return nil }
		let url = storageDirectoryURL.appendingPathComponent(safe)
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		return safe
	}
}

private enum ImportError: LocalizedError {
	case unsupportedSchema(expected: Int, actual: Int)

	var errorDescription: String? {
		switch self {
		case let .unsupportedSchema(expected, actual):
			return "지원하지 않는 DB 형식입니다. (expected \(expected), got \(actual))"
		}
	}
}

private enum BackgroundImageError: LocalizedError {
	case invalidImage

	var errorDescription: String? {
		switch self {
		case .invalidImage:
			return "지원되지 않는 이미지 파일입니다."
		}
	}
}
