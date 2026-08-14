import Foundation

enum StoredActivityPeriod: String, Codable, Sendable {
    case daily
    case weekly
}

struct ActivitySnapshotArchive: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let username: String
    let daily: ActivitySnapshot
    let weekly: ActivitySnapshot
    let rollingDaily: ActivitySnapshot?
    let rollingWeekly: ActivitySnapshot?
    let savedAt: Date

    init(
        username: String,
        daily: ActivitySnapshot,
        weekly: ActivitySnapshot,
        rollingDaily: ActivitySnapshot? = nil,
        rollingWeekly: ActivitySnapshot? = nil,
        savedAt: Date = .now
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.username = username
        self.daily = daily
        self.weekly = weekly
        self.rollingDaily = rollingDaily
        self.rollingWeekly = rollingWeekly
        self.savedAt = savedAt
    }

    func snapshot(for period: StoredActivityPeriod, windowMode: PeriodWindowMode) -> ActivitySnapshot {
        switch (period, windowMode) {
        case (.daily, .fixed): daily
        case (.weekly, .fixed): weekly
        case (.daily, .rolling): rollingDaily ?? daily
        case (.weekly, .rolling): rollingWeekly ?? weekly
        }
    }

    func markingRefreshError(_ message: String) -> ActivitySnapshotArchive {
        ActivitySnapshotArchive(
            username: username,
            daily: daily.markingRefreshError(message),
            weekly: weekly.markingRefreshError(message),
            rollingDaily: rollingDaily?.markingRefreshError(message),
            rollingWeekly: rollingWeekly?.markingRefreshError(message),
            savedAt: savedAt
        )
    }
}

enum ActivitySnapshotStoreError: LocalizedError {
    case appGroupUnavailable
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "The shared widget container is unavailable. Run the signed app once and confirm both targets use the same App Group."
        case .unsupportedSchema(let version):
            "The saved widget data uses unsupported schema version \(version)."
        }
    }
}

enum ActivitySnapshotStore {
    private static let fileName = "github-activity-snapshots.json"

    static func read() throws -> ActivitySnapshotArchive? {
        let url = try snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let data = try Data(contentsOf: url)
        let archive = try decoder.decode(ActivitySnapshotArchive.self, from: data)
        guard archive.schemaVersion == ActivitySnapshotArchive.currentSchemaVersion else {
            throw ActivitySnapshotStoreError.unsupportedSchema(archive.schemaVersion)
        }
        return archive
    }

    static func write(_ archive: ActivitySnapshotArchive) throws {
        let url = try snapshotURL()
        let data = try encoder.encode(archive)
        try data.write(to: url, options: .atomic)
    }

    static func remove() throws {
        let url = try snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func snapshotURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedPreferences.suiteName
        ) else {
            throw ActivitySnapshotStoreError.appGroupUnavailable
        }
        return container.appendingPathComponent(fileName, isDirectory: false)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
