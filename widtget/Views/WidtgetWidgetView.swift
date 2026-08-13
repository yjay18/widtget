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

    let entry: ActivityEntry

    private var preferences: WidgetViewPreferences {
        WidgetViewPreferences(
            showRepositories: showRepositories,
            showActivity: showActivity,
            showUpdateTime: showUpdateTime,
            repositoryDetail: repositoryDetail
        )
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry, preferences: preferences)
            case .systemMedium:
                MediumWidgetView(entry: entry, preferences: preferences)
            default:
                LargeWidgetView(entry: entry, preferences: preferences)
            }
        }
        .widgetURL(URL(string: "https://github.com/yjay18"))
    }
}

private struct SmallWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PeriodHeader(entry: entry)

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

            HStack(spacing: 10) {
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
            }

            SecondaryMetrics(snapshot: entry.snapshot)

            if preferences.showActivity || preferences.showUpdateTime || preferences.showRepositories {
                HStack(alignment: .top, spacing: 12) {
                    if preferences.showActivity || preferences.showUpdateTime {
                        VStack(alignment: .leading, spacing: 7) {
                            sectionLabel("ACTIVITY")
                            if preferences.showActivity {
                                ActivityGrid(cells: entry.snapshot.activity)
                            }
                            if preferences.showUpdateTime {
                                UpdateStatus(snapshot: entry.snapshot)
                            }
                        }
                        .padding(10)
                        .widtgetSurface()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private func metricCard(value: Int, label: String, sign: Character, color: Color) -> some View {
        PrimaryMetric(
            value: value,
            label: label,
            sign: sign,
            color: color,
            fontSize: 39,
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
