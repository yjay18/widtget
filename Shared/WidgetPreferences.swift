import Foundation

enum WidtgetWidgetKind {
    static let value = "widtget.activity"
}

enum RepositoryDetail: String, CaseIterable, Identifiable, Sendable {
    case focused
    case expanded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focused: "Focused"
        case .expanded: "More rows"
        }
    }

    var mediumLimit: Int { self == .focused ? 2 : 3 }
    var largeLimit: Int { self == .focused ? 3 : 4 }
    var extraLargeLimit: Int { self == .focused ? 5 : 8 }
}

enum PeriodWindowMode: String, CaseIterable, Identifiable, Sendable {
    case fixed
    case rolling

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: "Fixed"
        case .rolling: "Rolling"
        }
    }

    var detail: String {
        switch self {
        case .fixed: "Today and this calendar week"
        case .rolling: "Last 24 hours and last 7 days"
        }
    }
}

enum SharedPreferences {
    static let suiteName = "group.com.yjay18.widtget"
    static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    enum Key {
        static let showRepositories = "appearance.showRepositories"
        static let showActivity = "appearance.showActivity"
        static let showUpdateTime = "appearance.showUpdateTime"
        static let repositoryDetail = "appearance.repositoryDetail"
        static let periodWindowMode = "appearance.periodWindowMode"
        static let githubUsername = "github.username"
        static let lastSuccessfulRefresh = "github.lastSuccessfulRefresh"
        static let githubRefreshRequested = "github.refreshRequested"
    }

    static func displayedPeriodKey(family: String, configuredPeriod: String) -> String {
        "widget.displayedPeriod.\(family).\(configuredPeriod)"
    }
}

struct WidgetViewPreferences: Sendable {
    var showRepositories: Bool
    var showActivity: Bool
    var showUpdateTime: Bool
    var repositoryDetail: RepositoryDetail

    static let defaults = WidgetViewPreferences(
        showRepositories: true,
        showActivity: true,
        showUpdateTime: true,
        repositoryDetail: .expanded
    )
}
