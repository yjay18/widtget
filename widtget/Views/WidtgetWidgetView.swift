import SwiftUI
import WidgetKit

struct WidtgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @AppStorage(SharedPreferences.Key.showRepositories, store: SharedPreferences.defaults)
    private var showRepositories = WidgetViewPreferences.defaults.showRepositories
    @AppStorage(SharedPreferences.Key.showActivity, store: SharedPreferences.defaults)
    private var showActivity = WidgetViewPreferences.defaults.showActivity
    @AppStorage(SharedPreferences.Key.showUpdateTime, store: SharedPreferences.defaults)
    private var showUpdateTime = WidgetViewPreferences.defaults.showUpdateTime
    @AppStorage(SharedPreferences.Key.repositoryDetail, store: SharedPreferences.defaults)
    private var repositoryDetail = WidgetViewPreferences.defaults.repositoryDetail
    @AppStorage(SharedPreferences.Key.periodWindowMode, store: SharedPreferences.defaults)
    private var periodWindowMode = WidgetViewPreferences.defaults.periodWindowMode
    @AppStorage(SharedPreferences.Key.snakeMinimumSegments, store: SharedPreferences.defaults)
    private var snakeMinimumSegments = WidgetViewPreferences.defaults.snakeMinimumSegments
    @AppStorage(SharedPreferences.Key.snakeMaximumSegments, store: SharedPreferences.defaults)
    private var snakeMaximumSegments = WidgetViewPreferences.defaults.snakeMaximumSegments

    let entry: ActivityEntry

    private var preferences: WidgetViewPreferences {
        WidgetViewPreferences(
            showRepositories: showRepositories,
            showActivity: showActivity,
            showUpdateTime: showUpdateTime,
            repositoryDetail: repositoryDetail,
            periodWindowMode: periodWindowMode,
            snakeMinimumSegments: snakeMinimumSegments,
            snakeMaximumSegments: snakeMaximumSegments
        )
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry, preferences: preferences)
            case .systemMedium:
                MediumWidgetView(entry: entry, preferences: preferences)
            case .systemExtraLarge:
                ExtraLargeWidgetView(entry: entry, preferences: preferences)
            default:
                LargeWidgetView(entry: entry, preferences: preferences)
            }
        }
        .widgetURL(githubURL)
    }

    private var githubURL: URL? {
        let path = entry.username.isEmpty ? "" : "/\(entry.username)"
        return URL(string: "https://github.com\(path)")
    }
}

private struct ExtraLargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 13) {
            PeriodHeader(entry: entry)

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    metricCard(
                        value: entry.snapshot.additions,
                        label: "lines added",
                        sign: "+",
                        color: WidtgetPalette.green
                    )
                    metricCard(
                        value: entry.snapshot.deletions,
                        label: "lines deleted",
                        sign: "−",
                        color: WidtgetPalette.coral
                    )
                    SecondaryMetrics(snapshot: entry.snapshot)
                    ActivityInsights(snapshot: entry.snapshot, labels: activityLabels)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .widtgetSurface(cornerRadius: 12)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                if preferences.showActivity || preferences.showUpdateTime {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("ACTIVITY")
                            if preferences.showActivity {
                                VStack(spacing: 5) {
                                    ActivityStrip(cells: entry.snapshot.activity, height: 82)
                                    ActivityAxisLabels(
                                        labels: activityLabels,
                                        fontSize: 7
                                    )
                                }
                                ActivityGrid(cells: entry.snapshot.activity)
                            }
                            if preferences.showUpdateTime {
                                UpdateStatus(snapshot: entry.snapshot)
                            }
                        }
                        .padding(13)
                        .widtgetSurface(cornerRadius: 13)

                        if preferences.showActivity {
                            CommitSnakeView(
                                snapshot: entry.snapshot,
                                minimumSegments: preferences.snakeMinimumSegments,
                                maximumSegments: preferences.snakeMaximumSegments
                            )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .widtgetSurface(cornerRadius: 13)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if preferences.showRepositories {
                    VStack(alignment: .leading, spacing: 11) {
                        sectionLabel("REPOSITORIES")
                        RepositoryList(
                            snapshot: entry.snapshot,
                            limit: preferences.repositoryDetail.extraLargeLimit
                        )
                    }
                    .padding(13)
                    .widtgetSurface(cornerRadius: 13)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(17)
    }

    private var activityLabels: [String] {
        ActivityIntervalLabels.labels(
            period: entry.period,
            windowMode: preferences.periodWindowMode,
            referenceDate: entry.snapshot.updatedAt,
            cellCount: entry.snapshot.activity.count,
            style: .expanded
        )
    }

    private func metricCard(value: Int, label: String, sign: Character, color: Color) -> some View {
        PrimaryMetric(
            value: value,
            label: label,
            sign: sign,
            color: color,
            fontSize: 50,
            loading: entry.snapshot.state == .loading
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widtgetSurface(cornerRadius: 13)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(WidtgetPalette.secondaryText)
    }
}

private struct SmallWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PeriodHeader(entry: entry, compact: true)

            PrimaryMetric(
                value: entry.snapshot.additions,
                label: "lines added",
                sign: "+",
                color: WidtgetPalette.green,
                fontSize: 27,
                loading: entry.snapshot.state == .loading
            )

            PrimaryMetric(
                value: entry.snapshot.deletions,
                label: "lines deleted",
                sign: "−",
                color: WidtgetPalette.coral,
                fontSize: 25,
                loading: entry.snapshot.state == .loading
            )

            Spacer(minLength: 0)
            SecondaryMetrics(snapshot: entry.snapshot, compact: true)
            if preferences.showActivity || preferences.showUpdateTime {
                HStack(alignment: .bottom, spacing: 7) {
                    if preferences.showActivity {
                        ActivityStrip(cells: entry.snapshot.activity, height: 9)
                    }
                    if preferences.showUpdateTime {
                        UpdateStatus(snapshot: entry.snapshot)
                    }
                }
            }
        }
        .padding(12)
    }
}

private struct MediumWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 9) {
            PeriodHeader(entry: entry)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    PrimaryMetric(
                        value: entry.snapshot.additions,
                        label: "lines added",
                        sign: "+",
                        color: WidtgetPalette.green,
                        fontSize: 31,
                        loading: entry.snapshot.state == .loading
                    )
                    PrimaryMetric(
                        value: entry.snapshot.deletions,
                        label: "lines deleted",
                        sign: "−",
                        color: WidtgetPalette.coral,
                        fontSize: 29,
                        loading: entry.snapshot.state == .loading
                    )
                    SecondaryMetrics(snapshot: entry.snapshot, compact: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if preferences.showRepositories || preferences.showActivity || preferences.showUpdateTime {
                    Rectangle()
                        .fill(WidtgetPalette.border)
                        .frame(width: 1)

                    VStack(spacing: 8) {
                        if preferences.showRepositories {
                            RepositoryList(
                                snapshot: entry.snapshot,
                                limit: preferences.repositoryDetail.mediumLimit,
                                compact: true
                            )
                        }
                        Spacer(minLength: 0)
                        if preferences.showActivity {
                            ActivityStrip(cells: entry.snapshot.activity, height: 16)
                        }
                        if preferences.showUpdateTime {
                            HStack {
                                UpdateStatus(snapshot: entry.snapshot)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(14)
    }
}

private struct LargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 11) {
            PeriodHeader(entry: entry)

            GeometryReader { proxy in
                let cardWidth = max(0, (proxy.size.width - 10) / 2)

                HStack(spacing: 10) {
                    metricCard(
                        value: entry.snapshot.additions,
                        label: "lines added",
                        sign: "+",
                        color: WidtgetPalette.green
                    )
                    .frame(width: cardWidth)

                    metricCard(
                        value: entry.snapshot.deletions,
                        label: "lines deleted",
                        sign: "−",
                        color: WidtgetPalette.coral
                    )
                    .frame(width: cardWidth)
                }
            }
            .frame(height: 70)

            SecondaryMetrics(snapshot: entry.snapshot)

            if preferences.showActivity || preferences.showUpdateTime || preferences.showRepositories {
                HStack(alignment: .top, spacing: 12) {
                    if preferences.showActivity || preferences.showUpdateTime {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("ACTIVITY")
                            if preferences.showActivity {
                                ActivityStrip(cells: entry.snapshot.activity, height: 52)
                                ActivityGrid(
                                    cells: entry.snapshot.activity,
                                    labels: compactActivityLabels,
                                    labelFontSize: 6.5
                                )
                                Rectangle()
                                    .fill(WidtgetPalette.border)
                                    .frame(height: 1)
                                ActivityInsights(
                                    snapshot: entry.snapshot,
                                    labels: expandedActivityLabels,
                                    compact: true
                                )
                            }
                            Spacer(minLength: 0)
                            if preferences.showUpdateTime {
                                UpdateStatus(snapshot: entry.snapshot)
                                    .padding(.bottom, 5)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .widtgetSurface()
                    }

                    if preferences.showRepositories {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("REPOSITORIES")
                            RepositoryList(
                                snapshot: entry.snapshot,
                                limit: preferences.repositoryDetail.largeLimit
                            )
                        }
                        .padding(10)
                        .widtgetSurface()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(16)
    }

    private var compactActivityLabels: [String] {
        activityLabels(style: .compact)
    }

    private var expandedActivityLabels: [String] {
        activityLabels(style: .expanded)
    }

    private func activityLabels(style: ActivityIntervalLabelStyle) -> [String] {
        ActivityIntervalLabels.labels(
            period: entry.period,
            windowMode: preferences.periodWindowMode,
            referenceDate: entry.snapshot.updatedAt,
            cellCount: entry.snapshot.activity.count,
            style: style
        )
    }

    private func metricCard(value: Int, label: String, sign: Character, color: Color) -> some View {
        PrimaryMetric(
            value: value,
            label: label,
            sign: sign,
            color: color,
            fontSize: 35,
            loading: entry.snapshot.state == .loading
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widtgetSurface(cornerRadius: 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(0.9)
            .foregroundStyle(WidtgetPalette.secondaryText)
    }
}
