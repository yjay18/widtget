import Foundation

struct WeeklyDashboardAnalytics {
    struct PeakInterval {
        let index: Int
        let label: String
        let changed: Int
    }

    struct Review {
        enum Tone {
            case green
            case coral
            case neutral
        }

        struct Note: Identifiable {
            let id: String
            let label: String
            let value: String
            let detail: String
            let tone: Tone
        }

        let eyebrow: String
        let title: String
        let summary: String
        let notes: [Note]
    }

    let snapshot: ActivitySnapshot
    let windowMode: PeriodWindowMode

    var totalChanged: Int {
        snapshot.additions + snapshot.deletions
    }

    var netChanged: Int {
        snapshot.additions - snapshot.deletions
    }

    var averagePerCommit: Int {
        guard snapshot.commits > 0 else { return 0 }
        return Int((Double(totalChanged) / Double(snapshot.commits)).rounded())
    }

    var deletionShare: Double {
        guard totalChanged > 0 else { return 0 }
        return Double(snapshot.deletions) / Double(totalChanged)
    }

    var activeIntervals: Int {
        snapshot.activity.filter { $0.totalChanged > 0 }.count
    }

    var maximumActivity: Int {
        max(snapshot.activity.map(\.totalChanged).max() ?? 0, 1)
    }

    var leadingRepository: RepositoryActivity? {
        snapshot.repositories.first
    }

    var leadingRepositoryShare: Double {
        guard let leadingRepository, totalChanged > 0 else { return 0 }
        return Double(leadingRepository.totalChanged) / Double(totalChanged)
    }

    var peak: PeakInterval? {
        guard let result = snapshot.activity.enumerated().max(by: {
            $0.element.totalChanged < $1.element.totalChanged
        }), result.element.totalChanged > 0 else { return nil }

        return PeakInterval(
            index: result.offset,
            label: intervalLabels.indices.contains(result.offset)
                ? intervalLabels[result.offset]
                : "Interval \(result.offset + 1)",
            changed: result.element.totalChanged
        )
    }

    var intervalLabels: [String] {
        let count = snapshot.activity.count
        guard count > 0 else { return [] }

        let calendar = Calendar.current
        let intervalStart: Date
        switch windowMode {
        case .fixed:
            intervalStart = calendar.dateInterval(of: .weekOfYear, for: snapshot.updatedAt)?.start
                ?? calendar.startOfDay(for: snapshot.updatedAt)
        case .rolling:
            intervalStart = snapshot.updatedAt.addingTimeInterval(-7 * 24 * 60 * 60)
        }

        return (0..<count).map { index in
            let date = calendar.date(
                byAdding: .minute,
                value: Int((7 * 24 * 60) * Double(index) / Double(count)),
                to: intervalStart
            ) ?? intervalStart
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    var review: Review {
        switch snapshot.state {
        case .setupRequired:
            return Review(
                eyebrow: "WEEKLY REVIEW · WAITING",
                title: "Connect GitHub to begin the story.",
                summary: "Once connected, widtget will turn the saved weekly snapshot into a concise, deterministic review.",
                notes: []
            )
        case .loading:
            return Review(
                eyebrow: "WEEKLY REVIEW · FETCHING",
                title: "The week is being assembled.",
                summary: "Repository totals and activity rhythm will appear after the current refresh finishes.",
                notes: []
            )
        case .error:
            return Review(
                eyebrow: "WEEKLY REVIEW · CACHED",
                title: "The last complete week is still here.",
                summary: snapshot.errorMessage ?? "The latest refresh failed, so these analytics may be stale.",
                notes: loadedNotes
            )
        case .noActivity:
            return Review(
                eyebrow: "WEEKLY REVIEW · QUIET",
                title: "A quiet week in the selected window.",
                summary: "No commits were found across the connected repositories. The dashboard will keep the window ready for the next refresh.",
                notes: []
            )
        case .loaded:
            return Review(
                eyebrow: "WEEKLY REVIEW · \(windowMode == .fixed ? "CALENDAR" : "ROLLING")",
                title: loadedTitle,
                summary: loadedSummary,
                notes: loadedNotes
            )
        }
    }

    private var loadedTitle: String {
        if snapshot.commits >= 50 && activeIntervals >= 5 {
            return "A high-motion week with a steady pulse."
        }
        if snapshot.repositories.count == 1, let repository = leadingRepository {
            return "\(repository.name) held the whole week."
        }
        if activeIntervals >= 5 {
            return "A steady seven-day rhythm."
        }
        if leadingRepositoryShare >= 0.7, let repository = leadingRepository {
            return "The week converged on \(repository.name)."
        }
        return "A concentrated week across \(max(snapshot.repositories.count, 1)) repositories."
    }

    private var loadedSummary: String {
        let commitWord = snapshot.commits == 1 ? "commit" : "commits"
        let repositoryWord = snapshot.repositories.count == 1 ? "repository" : "repositories"
        let direction: String
        if netChanged > 0 {
            direction = "The net footprint grew by \(compact(netChanged)) lines."
        } else if netChanged < 0 {
            direction = "The net footprint contracted by \(compact(abs(netChanged))) lines."
        } else {
            direction = "Additions and deletions finished in balance."
        }

        return "\(snapshot.commits.formatted()) \(commitWord) moved \(compact(totalChanged)) lines across \(snapshot.repositories.count.formatted()) \(repositoryWord). \(direction)"
    }

    private var loadedNotes: [Review.Note] {
        var notes: [Review.Note] = []

        if let repository = leadingRepository {
            notes.append(
                Review.Note(
                    id: "focus",
                    label: "FOCUS",
                    value: repository.name,
                    detail: "\(percentage(leadingRepositoryShare)) of weekly line movement · \(repository.commits) commits",
                    tone: .green
                )
            )
        }

        if let peak {
            notes.append(
                Review.Note(
                    id: "rhythm",
                    label: "PEAK",
                    value: peak.label,
                    detail: "\(compact(peak.changed)) lines · active in \(activeIntervals)/\(snapshot.activity.count) intervals",
                    tone: .neutral
                )
            )
        }

        let balanceDetail: String
        let balanceTone: Review.Tone
        if deletionShare >= 0.6 {
            balanceDetail = "Deletion-heavy movement; this describes change shape, not code quality."
            balanceTone = .coral
        } else if deletionShare <= 0.25 {
            balanceDetail = "Addition-led movement across the selected weekly window."
            balanceTone = .green
        } else {
            balanceDetail = "Additions and deletions both had a visible share of the week."
            balanceTone = .neutral
        }
        notes.append(
            Review.Note(
                id: "shape",
                label: "CHANGE SHAPE",
                value: "\(percentage(1 - deletionShare)) add / \(percentage(deletionShare)) delete",
                detail: balanceDetail,
                tone: balanceTone
            )
        )

        return notes
    }

    func compact(_ value: Int) -> String {
        let sign: Character = value < 0 ? "−" : "+"
        return String(ActivityNumberFormat.compact(value, sign: sign).dropFirst())
    }

    func percentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
