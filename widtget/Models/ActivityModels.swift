import Foundation

enum ActivityLoadState: String, Codable, Sendable {
    case setupRequired
    case loading
    case loaded
    case noActivity
    case error
}

struct RepositoryActivity: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let commits: Int
    let additions: Int
    let deletions: Int

    var id: String { name }
    var totalChanged: Int { additions + deletions }
}

struct ActivityCell: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let additions: Int
    let deletions: Int

    var totalChanged: Int { additions + deletions }
}

struct ActivitySnapshot: Hashable, Codable, Sendable {
    let additions: Int
    let deletions: Int
    let commits: Int
    let repositories: [RepositoryActivity]
    let activity: [ActivityCell]
    let updatedAt: Date
    let state: ActivityLoadState
    let errorMessage: String?

    init(
        additions: Int,
        deletions: Int,
        commits: Int,
        repositories: [RepositoryActivity],
        activity: [ActivityCell],
        updatedAt: Date,
        state: ActivityLoadState = .loaded,
        errorMessage: String? = nil
    ) {
        self.additions = additions
        self.deletions = deletions
        self.commits = commits
        self.repositories = repositories.sorted {
            if $0.totalChanged != $1.totalChanged {
                return $0.totalChanged > $1.totalChanged
            }
            if $0.commits != $1.commits {
                return $0.commits > $1.commits
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        self.activity = activity
        self.updatedAt = updatedAt
        self.state = state
        self.errorMessage = errorMessage
    }

    func visibleRepositories(limit: Int) -> ArraySlice<RepositoryActivity> {
        repositories.prefix(limit)
    }

    func hiddenRepositoryCount(limit: Int) -> Int {
        max(0, repositories.count - limit)
    }

    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 60 * 60
    }

    func markingRefreshError(_ message: String) -> ActivitySnapshot {
        ActivitySnapshot(
            additions: additions,
            deletions: deletions,
            commits: commits,
            repositories: repositories,
            activity: activity,
            updatedAt: updatedAt,
            state: .error,
            errorMessage: message
        )
    }
}

enum ActivityNumberFormat {
    private static let groupedFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func exact(_ value: Int, sign: Character) -> String {
        let formatted = groupedFormatter.string(from: NSNumber(value: abs(value))) ?? String(abs(value))
        return "\(sign)\(formatted)"
    }

    static func compact(_ value: Int, sign: Character) -> String {
        let magnitude = Double(abs(value))
        let suffix: String
        let scaled: Double

        switch magnitude {
        case 1_000_000...:
            suffix = "M"
            scaled = magnitude / 1_000_000
        case 1_000...:
            suffix = "k"
            scaled = magnitude / 1_000
        default:
            return exact(value, sign: sign)
        }

        let decimals = scaled < 10 && scaled.rounded() != scaled ? 1 : 0
        return "\(sign)\(scaled.formatted(.number.precision(.fractionLength(decimals))))\(suffix)"
    }
}
