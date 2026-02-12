import Foundation

struct TrackedApp: Codable, Identifiable, Hashable {
	var bundleId: String
	var displayName: String

	var id: String { bundleId }
}

struct TaskItem: Codable, Identifiable, Hashable {
	var id: UUID
	var title: String
	var isCompleted: Bool
	var createdAt: Date
	var completedAt: Date?
}

struct DayData: Codable, Hashable {
	var appSeconds: [String: Double]
	var tasks: [TaskItem]
	var memo: String

	static let empty = DayData(appSeconds: [:], tasks: [], memo: "")
}

struct DatabaseFile: Codable {
	var schemaVersion: Int
	var trackedApps: [TrackedApp]
	var days: [String: DayData]
	/// Optional to stay backward compatible with existing schemaVersion=1 files.
	var timerPresetsMinutes: [Int]?
	/// Optional custom background image filename stored under app support directory.
	var backgroundImageFilename: String?
	/// Optional app icon id selected by user.
	var selectedAppIconId: String?
}
