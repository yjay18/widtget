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
}

enum SharedPreferences {
    static let suiteName = "group.com.yjay18.widtget"
    static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    enum Key {
        static let showRepositories = "appearance.showRepositories"
        static let showActivity = "appearance.showActivity"
        static let showUpdateTime = "appearance.showUpdateTime"
        static let repositoryDetail = "appearance.repositoryDetail"
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
