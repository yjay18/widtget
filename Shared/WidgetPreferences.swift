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
    var largeLimit: Int { self == .focused ? 4 : 6 }
    var extraLargeLimit: Int { self == .focused ? 8 : 10 }
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

enum CommitSnakeLimits {
    static let commitsPerBlockRange = 1...20
    static let defaultCommitsPerBlock = 8
    static let visualBlockCount = 20
}

enum WidgetPane: String, CaseIterable, Identifiable, Codable, Sendable {
    case additions
    case deletions
    case summary
    case activity
    case activityTable
    case insights
    case repositories
    case snake

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .additions: "Lines made"
        case .deletions: "Lines removed"
        case .summary: "Commit summary"
        case .activity: "Activity bars"
        case .activityTable: "Activity table"
        case .insights: "Net / peak / average"
        case .repositories: "Repositories"
        case .snake: "Commit snek"
        }
    }

    var detail: String {
        switch self {
        case .additions: "Primary additions total"
        case .deletions: "Deletion total and net change"
        case .summary: "Commits, repositories, and active intervals"
        case .activity: "Fixed-height scaled interval bars"
        case .activityTable: "Compact interval contribution cells"
        case .insights: "Derived net, peak, and average"
        case .repositories: "Ranked repository breakdown"
        case .snake: "Commit-driven pet for Extra Large"
        }
    }
}

enum WidgetVisualTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case defaultTheme
    case blockwork
    case glasshouse
    case phosphor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultTheme: "Default"
        case .blockwork: "Blockwork"
        case .glasshouse: "Glasshouse"
        case .phosphor: "Phosphor"
        }
    }
}

enum WidgetLayoutFamily: String, CaseIterable, Identifiable, Codable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var slotCount: Int {
        switch self {
        case .small: 1
        case .medium: 2
        case .large: 3
        case .extraLarge: 4
        }
    }
}

enum WidgetBlockColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case orange
    case lime
    case sky
    case ink
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Auto"
        case .orange: "Orange"
        case .lime: "Lime"
        case .sky: "Sky"
        case .ink: "Ink"
        case .paper: "Paper"
        }
    }
}

enum BlockworkColorway: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case cobalt
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Workshop"
        case .cobalt: "Blueprint"
        case .mono: "Newsprint"
        }
    }
}

struct WidgetModularPreferences: Sendable {
    var paneOrder: [WidgetPane]
    var enabledPanes: Set<WidgetPane>
    var colorway: BlockworkColorway
    var visualTheme: WidgetVisualTheme
    var familyLayouts: [WidgetLayoutFamily: [WidgetPane]]
    var blockColors: [WidgetPane: WidgetBlockColor]

    static let defaults = WidgetModularPreferences(
        paneOrder: WidgetPane.allCases,
        enabledPanes: Set(WidgetPane.allCases),
        colorway: .original,
        visualTheme: .defaultTheme,
        familyLayouts: [
            .small: [.additions],
            .medium: [.additions, .activity],
            .large: [.additions, .activityTable, .repositories],
            .extraLarge: [.additions, .activityTable, .repositories, .snake]
        ],
        blockColors: [:]
    )
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
        static let snakeCommitsPerBlock = "appearance.snakeCommitsPerBlock"
        static let paneOrder = "appearance.blockwork.paneOrder"
        static let enabledPanes = "appearance.blockwork.enabledPanes"
        static let colorway = "appearance.blockwork.colorway"
        static let visualTheme = "appearance.widget.visualTheme"
        static let layoutPrefix = "appearance.widget.layout"
        static let blockColorPrefix = "appearance.widget.blockColor"
        static let themeScopeVersion = "appearance.widget.themeScopeVersion"
        static let githubUsername = "github.username"
        static let lastSuccessfulRefresh = "github.lastSuccessfulRefresh"
        static let githubRefreshRequested = "github.refreshRequested"
    }

    static func displayedPeriodKey(family: String, configuredPeriod: String) -> String {
        "widget.displayedPeriod.\(family).\(configuredPeriod)"
    }

    static var modularPreferences: WidgetModularPreferences {
        let storedOrder = defaults.string(forKey: Key.paneOrder)?
            .split(separator: ",")
            .compactMap { WidgetPane(rawValue: String($0)) } ?? []
        let uniqueOrder = storedOrder.reduce(into: [WidgetPane]()) { result, pane in
            if !result.contains(pane) {
                result.append(pane)
            }
        }
        let completedOrder = uniqueOrder + WidgetPane.allCases.filter { !uniqueOrder.contains($0) }

        let enabledPanes: Set<WidgetPane>
        if let storedEnabled = defaults.string(forKey: Key.enabledPanes) {
            enabledPanes = Set(
                storedEnabled
                    .split(separator: ",")
                    .compactMap { WidgetPane(rawValue: String($0)) }
            )
        } else {
            enabledPanes = WidgetModularPreferences.defaults.enabledPanes
        }

        let colorway = defaults.string(forKey: Key.colorway)
            .flatMap(BlockworkColorway.init(rawValue:))
            ?? WidgetModularPreferences.defaults.colorway

        let visualTheme = defaults.string(forKey: Key.visualTheme)
            .flatMap(WidgetVisualTheme.init(rawValue:))
            ?? WidgetModularPreferences.defaults.visualTheme

        let familyLayouts = Dictionary(
            uniqueKeysWithValues: WidgetLayoutFamily.allCases.map { family in
                let key = "\(Key.layoutPrefix).\(family.rawValue)"
                let stored = defaults.string(forKey: key)?
                    .split(separator: ",")
                    .compactMap { WidgetPane(rawValue: String($0)) } ?? []
                let fallback = WidgetModularPreferences.defaults.familyLayouts[family] ?? []
                let normalized = Array((stored.isEmpty ? fallback : stored).prefix(family.slotCount))
                let padded = normalized + fallback.filter { !normalized.contains($0) }
                return (family, Array(padded.prefix(family.slotCount)))
            }
        )

        let blockColors = WidgetPane.allCases.reduce(
            into: [WidgetPane: WidgetBlockColor]()
        ) { result, pane in
            let key = "\(Key.blockColorPrefix).\(pane.rawValue)"
            guard let rawValue = defaults.string(forKey: key),
                  let color = WidgetBlockColor(rawValue: rawValue)
            else {
                return
            }
            result[pane] = color
        }

        return WidgetModularPreferences(
            paneOrder: completedOrder,
            enabledPanes: enabledPanes,
            colorway: colorway,
            visualTheme: visualTheme,
            familyLayouts: familyLayouts,
            blockColors: blockColors
        )
    }

    static func saveModularPreferences(_ preferences: WidgetModularPreferences) {
        defaults.set(
            preferences.paneOrder.map(\.rawValue).joined(separator: ","),
            forKey: Key.paneOrder
        )
        defaults.set(
            preferences.enabledPanes.map(\.rawValue).sorted().joined(separator: ","),
            forKey: Key.enabledPanes
        )
        defaults.set(preferences.colorway.rawValue, forKey: Key.colorway)
        defaults.set(preferences.visualTheme.rawValue, forKey: Key.visualTheme)

        for family in WidgetLayoutFamily.allCases {
            defaults.set(
                preferences.familyLayouts[family, default: []]
                    .prefix(family.slotCount)
                    .map(\.rawValue)
                    .joined(separator: ","),
                forKey: "\(Key.layoutPrefix).\(family.rawValue)"
            )
        }

        for pane in WidgetPane.allCases {
            let key = "\(Key.blockColorPrefix).\(pane.rawValue)"
            if let color = preferences.blockColors[pane] {
                defaults.set(color.rawValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

struct WidgetViewPreferences: Sendable {
    var showRepositories: Bool
    var showActivity: Bool
    var showUpdateTime: Bool
    var repositoryDetail: RepositoryDetail
    var periodWindowMode: PeriodWindowMode
    var snakeCommitsPerBlock: Int
    var paneOrder: [WidgetPane]
    var enabledPanes: Set<WidgetPane>
    var colorway: BlockworkColorway
    var visualTheme: WidgetVisualTheme
    var familyLayouts: [WidgetLayoutFamily: [WidgetPane]]
    var blockColors: [WidgetPane: WidgetBlockColor]

    static let defaults = WidgetViewPreferences(
        showRepositories: true,
        showActivity: true,
        showUpdateTime: true,
        repositoryDetail: .expanded,
        periodWindowMode: .fixed,
        snakeCommitsPerBlock: CommitSnakeLimits.defaultCommitsPerBlock,
        paneOrder: WidgetModularPreferences.defaults.paneOrder,
        enabledPanes: WidgetModularPreferences.defaults.enabledPanes,
        colorway: WidgetModularPreferences.defaults.colorway,
        visualTheme: WidgetModularPreferences.defaults.visualTheme,
        familyLayouts: WidgetModularPreferences.defaults.familyLayouts,
        blockColors: WidgetModularPreferences.defaults.blockColors
    )

    func shows(_ pane: WidgetPane) -> Bool {
        enabledPanes.contains(pane)
    }

    var visiblePaneOrder: [WidgetPane] {
        paneOrder.filter(enabledPanes.contains)
    }

    func blocks(for family: WidgetLayoutFamily) -> [WidgetPane] {
        let fallback = WidgetModularPreferences.defaults.familyLayouts[family] ?? []
        return Array(familyLayouts[family, default: fallback].prefix(family.slotCount))
    }

    func color(for pane: WidgetPane) -> WidgetBlockColor {
        blockColors[pane] ?? .automatic
    }
}
