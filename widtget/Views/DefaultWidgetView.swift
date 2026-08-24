import SwiftUI
import WidgetKit

enum DefaultWidgetPalette {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.063)
    static let surface = Color(red: 0.075, green: 0.094, blue: 0.118)
    static let raisedSurface = Color(red: 0.092, green: 0.115, blue: 0.143)
    static let border = Color.white.opacity(0.075)
    static let primaryText = Color(red: 0.93, green: 0.95, blue: 0.97)
    static let secondaryText = Color(red: 0.52, green: 0.57, blue: 0.63)
    static let green = Color(red: 0.22, green: 0.80, blue: 0.46)
    static let coral = Color(red: 0.95, green: 0.38, blue: 0.40)
    static let neutral = Color(red: 0.13, green: 0.16, blue: 0.20)
}

struct DefaultWidgetView: View {
    // An opaque background is painted as a light material in macOS vibrant mode and
    // washes the widget out; clear it when de-emphasized so content stays legible.
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily

    var body: some View {
        Group {
            switch family {
            case .small:
                DefaultSmallWidgetView(entry: entry, preferences: preferences)
            case .medium:
                DefaultMediumWidgetView(entry: entry, preferences: preferences)
            case .large:
                DefaultLargeWidgetView(entry: entry, preferences: preferences)
            case .extraLarge:
                DefaultExtraLargeWidgetView(entry: entry, preferences: preferences)
            }
        }
        .background(renderingMode == .fullColor ? DefaultWidgetPalette.background : Color.clear)
    }
}

private struct DefaultSmallWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            DefaultPeriodHeader(entry: entry, compact: true)

            DefaultPrimaryMetric(
                value: entry.snapshot.additions,
                label: "lines added",
                sign: "+",
                color: DefaultWidgetPalette.green,
                fontSize: 27,
                loading: entry.snapshot.state == .loading
            )

            DefaultPrimaryMetric(
                value: entry.snapshot.deletions,
                label: "lines deleted",
                sign: "−",
                color: DefaultWidgetPalette.coral,
                fontSize: 25,
                loading: entry.snapshot.state == .loading
            )

            Spacer(minLength: 0)
            DefaultSecondaryMetrics(snapshot: entry.snapshot, compact: true)

            if preferences.showActivity || preferences.showUpdateTime {
                HStack(alignment: .bottom, spacing: 7) {
                    if preferences.showActivity {
                        defaultActivityStrip(cells: entry.snapshot.activity, height: 9)
                    }
                    if preferences.showUpdateTime {
                        DefaultUpdateStatus(snapshot: entry.snapshot)
                    }
                }
                .frame(height: 12)
                .clipped()
            }
        }
        .padding(12)
        .clipped()
    }
}

private struct DefaultMediumWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 9) {
            DefaultPeriodHeader(entry: entry)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    DefaultPrimaryMetric(
                        value: entry.snapshot.additions,
                        label: "lines added",
                        sign: "+",
                        color: DefaultWidgetPalette.green,
                        fontSize: 31,
                        loading: entry.snapshot.state == .loading
                    )
                    DefaultPrimaryMetric(
                        value: entry.snapshot.deletions,
                        label: "lines deleted",
                        sign: "−",
                        color: DefaultWidgetPalette.coral,
                        fontSize: 29,
                        loading: entry.snapshot.state == .loading
                    )
                    DefaultSecondaryMetrics(snapshot: entry.snapshot, compact: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if preferences.showRepositories || preferences.showActivity || preferences.showUpdateTime {
                    Rectangle()
                        .fill(DefaultWidgetPalette.border)
                        .frame(width: 1)

                    VStack(spacing: 8) {
                        if preferences.showRepositories {
                            DefaultRepositoryList(
                                snapshot: entry.snapshot,
                                limit: preferences.repositoryDetail.mediumLimit,
                                compact: true
                            )
                        }
                        Spacer(minLength: 0)
                        if preferences.showActivity {
                            defaultActivityStrip(cells: entry.snapshot.activity, height: 16)
                        }
                        if preferences.showUpdateTime {
                            HStack {
                                DefaultUpdateStatus(snapshot: entry.snapshot)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .clipped()
                }
            }
        }
        .padding(14)
        .clipped()
    }
}

private struct DefaultLargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 11) {
            DefaultPeriodHeader(entry: entry)

            GeometryReader { proxy in
                let cardWidth = max(0, (proxy.size.width - 10) / 2)

                HStack(spacing: 10) {
                    metricCard(
                        value: entry.snapshot.additions,
                        label: "lines added",
                        sign: "+",
                        color: DefaultWidgetPalette.green
                    )
                    .frame(width: cardWidth)

                    metricCard(
                        value: entry.snapshot.deletions,
                        label: "lines deleted",
                        sign: "−",
                        color: DefaultWidgetPalette.coral
                    )
                    .frame(width: cardWidth)
                }
            }
            .frame(height: 70)

            DefaultSecondaryMetrics(snapshot: entry.snapshot)

            if preferences.showActivity || preferences.showUpdateTime || preferences.showRepositories {
                HStack(alignment: .top, spacing: 12) {
                    if preferences.showActivity || preferences.showUpdateTime {
                        VStack(alignment: .leading, spacing: 5) {
                            sectionLabel("ACTIVITY")
                            if preferences.showActivity {
                                defaultActivityStrip(cells: entry.snapshot.activity, height: 40)
                                ActivityAxisLabels(
                                    labels: compactActivityLabels,
                                    fontSize: 6.5,
                                    color: DefaultWidgetPalette.secondaryText
                                )
                                Rectangle()
                                    .fill(DefaultWidgetPalette.border)
                                    .frame(height: 1)
                                DefaultActivityInsights(
                                    snapshot: entry.snapshot,
                                    labels: expandedActivityLabels,
                                    compact: true
                                )
                                .frame(height: 35, alignment: .top)
                                .clipped()
                            }
                            Spacer(minLength: 0)
                            if preferences.showUpdateTime {
                                DefaultUpdateStatus(snapshot: entry.snapshot)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .defaultWidgetSurface()
                        .clipped()
                    }

                    if preferences.showRepositories {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("REPOSITORIES")
                            DefaultRepositoryList(
                                snapshot: entry.snapshot,
                                limit: preferences.repositoryDetail.largeLimit
                            )
                        }
                        .padding(10)
                        .defaultWidgetSurface()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .clipped()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .clipped()
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
        DefaultPrimaryMetric(
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
        .defaultWidgetSurface(cornerRadius: 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(0.9)
            .foregroundStyle(DefaultWidgetPalette.secondaryText)
    }
}

private struct DefaultExtraLargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 13) {
            DefaultPeriodHeader(entry: entry)

            GeometryReader { proxy in
                HStack(alignment: .top, spacing: 14) {
                    metricsColumn

                    if preferences.showActivity || preferences.showUpdateTime {
                        activityColumn(availableHeight: proxy.size.height)
                    }

                    if preferences.showRepositories {
                        VStack(alignment: .leading, spacing: 11) {
                            sectionLabel("REPOSITORIES")
                            DefaultRepositoryList(
                                snapshot: entry.snapshot,
                                limit: preferences.repositoryDetail.extraLargeLimit
                            )
                        }
                        .padding(13)
                        .defaultWidgetSurface(cornerRadius: 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .clipped()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
            }
        }
        .padding(17)
        .clipped()
    }

    private var metricsColumn: some View {
        VStack(spacing: 10) {
            metricCard(
                value: entry.snapshot.additions,
                label: "lines added",
                sign: "+",
                color: DefaultWidgetPalette.green
            )
            metricCard(
                value: entry.snapshot.deletions,
                label: "lines deleted",
                sign: "−",
                color: DefaultWidgetPalette.coral
            )
            DefaultSecondaryMetrics(snapshot: entry.snapshot)
            DefaultActivityInsights(snapshot: entry.snapshot, labels: activityLabels)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .defaultWidgetSurface(cornerRadius: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private func activityColumn(availableHeight: CGFloat) -> some View {
        let activityHeight = min(164, max(126, availableHeight * 0.61))

        return VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                sectionLabel("ACTIVITY")
                if preferences.showActivity {
                    defaultActivityStrip(cells: entry.snapshot.activity, height: 50)
                    ActivityAxisLabels(
                        labels: activityLabels,
                        fontSize: 7,
                        color: DefaultWidgetPalette.secondaryText
                    )
                    ActivityGrid(
                        cells: entry.snapshot.activity,
                        additionColor: DefaultWidgetPalette.green,
                        deletionColor: DefaultWidgetPalette.coral,
                        neutralColor: DefaultWidgetPalette.neutral,
                        labelColor: DefaultWidgetPalette.secondaryText
                    )
                    .frame(height: 32)
                    .clipped()
                }
                if preferences.showUpdateTime {
                    DefaultUpdateStatus(snapshot: entry.snapshot)
                }
            }
            .padding(13)
            .frame(height: activityHeight, alignment: .topLeading)
            .defaultWidgetSurface(cornerRadius: 13)
            .clipped()

            if preferences.showActivity {
                DefaultCommitSnakeView(
                    snapshot: entry.snapshot,
                    commitsPerBlock: preferences.snakeCommitsPerBlock
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultWidgetSurface(cornerRadius: 13)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
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
        DefaultPrimaryMetric(
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
        .defaultWidgetSurface(cornerRadius: 13)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundStyle(DefaultWidgetPalette.secondaryText)
    }
}

private struct DefaultPeriodHeader: View {
    @Environment(\.widgetFamily) private var family

    let entry: ActivityEntry
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            if !compact {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DefaultWidgetPalette.green)
            }

            Text(entry.username.isEmpty ? "GitHub" : "@\(entry.username)")
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(DefaultWidgetPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            Link(destination: URL(string: "widtget://refresh")!) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        entry.snapshot.state == .error
                            ? DefaultWidgetPalette.coral
                            : DefaultWidgetPalette.secondaryText
                    )
                    .frame(width: 16, height: 16)
            }
            .accessibilityLabel("Refresh GitHub activity")

            Button(
                intent: SetActivityPeriodIntent(
                    period: entry.period.toggled,
                    family: ActivityWidgetFamily(widgetFamily: family),
                    configuredPeriod: entry.configuredPeriod
                )
            ) {
                Text(entry.period.displayName)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(DefaultWidgetPalette.primaryText)
                    .padding(.horizontal, compact ? 5 : 7)
                    .padding(.vertical, 4)
                    .overlay { Capsule().stroke(DefaultWidgetPalette.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
    }
}

private struct DefaultPrimaryMetric: View {
    let value: Int
    let label: String
    let sign: Character
    let color: Color
    let fontSize: CGFloat
    let loading: Bool

    var body: some View {
        Text(loading ? "\(sign)––,–––" : ActivityNumberFormat.exact(value, sign: sign))
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(loading ? DefaultWidgetPalette.secondaryText.opacity(0.45) : color)
            .lineLimit(1)
            .minimumScaleFactor(0.48)
            .contentTransition(.numericText())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(value) \(label)")
    }
}

private struct DefaultSecondaryMetrics: View {
    let snapshot: ActivitySnapshot
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 12) {
            metric(value: snapshot.commits, label: "commit")
            Rectangle()
                .fill(DefaultWidgetPalette.border)
                .frame(width: 1, height: 11)
            metric(value: snapshot.repositories.count, label: "repository")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: compact ? 23 : 27)
        .defaultWidgetSurface(cornerRadius: 8)
    }

    private func metric(value: Int, label: String) -> some View {
        let displayLabel = value == 1 ? label : "\(label)s"

        return HStack(spacing: 3) {
            Text(snapshot.state == .loading ? "––" : value.formatted())
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DefaultWidgetPalette.primaryText)
            Text(displayLabel)
                .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(DefaultWidgetPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct DefaultUpdateStatus: View {
    let snapshot: ActivitySnapshot

    var body: some View {
        Group {
            if snapshot.state == .setupRequired {
                Text("Open app to connect")
            } else if snapshot.state == .error {
                Text(snapshot.errorMessage ?? "Couldn’t refresh")
                    .foregroundStyle(DefaultWidgetPalette.coral)
            } else if snapshot.state == .noActivity {
                Text("No activity")
            } else if snapshot.state == .loading {
                Text("Loading activity")
            } else if snapshot.isStale {
                Text("Stale · \(snapshot.updatedAt, style: .relative)")
            } else {
                Text("Updated \(snapshot.updatedAt, style: .relative)")
            }
        }
        .font(.system(size: 8, weight: .medium, design: .rounded))
        .foregroundStyle(DefaultWidgetPalette.secondaryText)
        .lineLimit(1)
    }
}

private struct DefaultActivityInsights: View {
    let snapshot: ActivitySnapshot
    let labels: [String]
    var compact = false

    private var net: Int { snapshot.additions - snapshot.deletions }
    private var average: Int {
        guard snapshot.commits > 0 else { return 0 }
        return Int((Double(snapshot.additions + snapshot.deletions) / Double(snapshot.commits)).rounded())
    }
    private var peakIndex: Int? {
        snapshot.activity.enumerated().max {
            $0.element.totalChanged < $1.element.totalChanged
        }?.offset
    }
    private var peakLabel: String {
        guard let peakIndex, labels.indices.contains(peakIndex), snapshot.activity[peakIndex].totalChanged > 0 else {
            return "—"
        }
        return labels[peakIndex].uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 6 : 10) {
            insight("NET", signedCompact(net), "LINES", net < 0 ? DefaultWidgetPalette.coral : DefaultWidgetPalette.green)
            separator
            insight("PEAK", peakLabel, "INTERVAL", DefaultWidgetPalette.primaryText)
            separator
            insight("AVG", unsignedCompact(average), "LINES / COMMIT", DefaultWidgetPalette.primaryText)
        }
    }

    private func insight(_ title: String, _ value: String, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            Text(title)
                .font(.system(size: compact ? 6.5 : 7.5, weight: .bold, design: .rounded))
                .tracking(compact ? 0.7 : 0.9)
                .foregroundStyle(DefaultWidgetPalette.secondaryText)
            Text(value)
                .font(.system(size: compact ? 12 : 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: compact ? 5.5 : 6.5, weight: .semibold, design: .rounded))
                .foregroundStyle(DefaultWidgetPalette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle()
            .fill(DefaultWidgetPalette.border)
            .frame(width: 1, height: compact ? 35 : 42)
    }

    private func signedCompact(_ value: Int) -> String {
        ActivityNumberFormat.compact(value, sign: value < 0 ? "−" : "+")
    }

    private func unsignedCompact(_ value: Int) -> String {
        String(ActivityNumberFormat.compact(value, sign: "+").dropFirst())
    }
}

private struct DefaultRepositoryList: View {
    let snapshot: ActivitySnapshot
    let limit: Int
    var compact = false

    private var maximumChange: CGFloat {
        CGFloat(max(snapshot.repositories.map(\.totalChanged).max() ?? 0, 1))
    }

    var body: some View {
        VStack(spacing: compact ? 7 : 9) {
            if snapshot.repositories.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.state == .loading ? "Loading repositories" : "No repository activity")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DefaultWidgetPalette.secondaryText)
                    Rectangle().fill(DefaultWidgetPalette.neutral).frame(height: 4)
                }
            } else {
                ForEach(snapshot.visibleRepositories(limit: limit)) { repository in
                    repositoryRow(repository)
                }
            }

            let hidden = snapshot.hiddenRepositoryCount(limit: limit)
            if hidden > 0 {
                HStack {
                    Text("+\(hidden) more")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(DefaultWidgetPalette.secondaryText)
                    Spacer()
                }
            }
        }
    }

    private func repositoryRow(_ repository: RepositoryActivity) -> some View {
        VStack(spacing: compact ? 3 : 5) {
            HStack(spacing: 6) {
                Text(repository.name)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DefaultWidgetPalette.primaryText)
                    .lineLimit(1)
                Text("\(repository.commits)c")
                    .font(.system(size: compact ? 8 : 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DefaultWidgetPalette.secondaryText)
                Spacer(minLength: 3)
                Text(ActivityNumberFormat.compact(repository.additions, sign: "+"))
                    .foregroundStyle(DefaultWidgetPalette.green)
                Text(ActivityNumberFormat.compact(repository.deletions, sign: "−"))
                    .foregroundStyle(DefaultWidgetPalette.coral)
            }
            .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .monospaced))
            .monospacedDigit()

            GeometryReader { proxy in
                let totalWidth = proxy.size.width * CGFloat(repository.totalChanged) / maximumChange
                let additionsWidth = repository.totalChanged == 0
                    ? 0
                    : totalWidth * CGFloat(repository.additions) / CGFloat(repository.totalChanged)

                HStack(spacing: 1) {
                    Rectangle().fill(DefaultWidgetPalette.green).frame(width: additionsWidth)
                    Rectangle().fill(DefaultWidgetPalette.coral).frame(width: max(0, totalWidth - additionsWidth))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DefaultWidgetPalette.neutral)
            }
            .frame(height: compact ? 3 : 4)
        }
    }
}

private enum DefaultSnakeMood {
    case sleeping, hatched, growing, thriving, setupRequired, loading, worried

    init(snapshot: ActivitySnapshot) {
        switch snapshot.state {
        case .error: self = .worried
        case .setupRequired: self = .setupRequired
        case .loading: self = .loading
        case .loaded, .noActivity:
            switch snapshot.commits {
            case 0: self = .sleeping
            case 1..<5: self = .hatched
            case 5..<15: self = .growing
            default: self = .thriving
            }
        }
    }

    var title: String {
        switch self {
        case .sleeping: "SNAKE IS SNOOZING"
        case .hatched: "A SNAKE HATCHED"
        case .growing: "SNAKE IS GROWING"
        case .thriving: "SNAKE IS HUGE"
        case .setupRequired: "SNAKE NEEDS GITHUB"
        case .loading: "SNAKE IS HUNTING"
        case .worried: "SNAKE LOST THE TRAIL"
        }
    }

    var accent: Color {
        switch self {
        case .worried: DefaultWidgetPalette.coral
        case .sleeping, .setupRequired, .loading: DefaultWidgetPalette.secondaryText
        case .hatched, .growing, .thriving: DefaultWidgetPalette.green
        }
    }
}

private struct DefaultCommitSnakeView: View {
    let snapshot: ActivitySnapshot
    let commitsPerBlock: Int

    private var mood: DefaultSnakeMood { DefaultSnakeMood(snapshot: snapshot) }
    private var segments: Int {
        let divisor = min(max(commitsPerBlock, 1), 20)
        return min(Int(ceil(Double(snapshot.commits) / Double(divisor))), 20)
    }

    var body: some View {
        HStack(spacing: 11) {
            DefaultSnakeCanvas(mood: mood, segments: segments)
                .frame(width: 118, height: 67)

            VStack(alignment: .leading, spacing: 5) {
                Text("COMMIT SNAKE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(DefaultWidgetPalette.secondaryText)
                Text(mood.title)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(DefaultWidgetPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(snapshot.commits) COMMITS · \(segments)/20 BLOCKS")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundStyle(mood.accent)
                    .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DefaultWidgetPalette.neutral)
                        Capsule()
                            .fill(mood.accent)
                            .frame(width: max(3, proxy.size.width * Double(segments) / 20))
                    }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct DefaultSnakeCanvas: View {
    let mood: DefaultSnakeMood
    let segments: Int

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let columns = 7
            let rows = 3
            let gap: CGFloat = 3
            let block = max(3, floor(min(
                (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns),
                (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            )))
            let gridWidth = CGFloat(columns) * block + CGFloat(columns - 1) * gap
            let gridHeight = CGFloat(rows) * block + CGFloat(rows - 1) * gap
            let origin = CGPoint(x: (size.width - gridWidth) / 2, y: (size.height - gridHeight) / 2)

            func frame(_ index: Int) -> CGRect {
                let row = index / columns
                let offset = index % columns
                let column = row.isMultiple(of: 2) ? offset : columns - 1 - offset
                return CGRect(
                    x: origin.x + CGFloat(column) * (block + gap),
                    y: origin.y + CGFloat(rows - 1 - row) * (block + gap),
                    width: block,
                    height: block
                )
            }

            for index in 0..<21 {
                let color: Color
                if index == min(segments, 20) {
                    color = mood.accent
                } else if index < segments {
                    color = (index + 1).isMultiple(of: 5)
                        ? DefaultWidgetPalette.coral
                        : DefaultWidgetPalette.green.opacity(0.82)
                } else {
                    color = DefaultWidgetPalette.neutral.opacity(0.7)
                }
                context.fill(Path(roundedRect: frame(index), cornerRadius: 2), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DefaultWidgetSurfaceModifier: ViewModifier {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(renderingMode == .fullColor ? DefaultWidgetPalette.surface : Color.clear)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        renderingMode == .fullColor
                            ? DefaultWidgetPalette.border
                            : Color.primary.opacity(0.14),
                        lineWidth: 1
                    )
            }
    }
}

private extension View {
    func defaultWidgetSurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(DefaultWidgetSurfaceModifier(cornerRadius: cornerRadius))
    }
}

private func defaultActivityStrip(cells: [ActivityCell], height: CGFloat) -> some View {
    ActivityStrip(
        cells: cells,
        height: height,
        additionColor: DefaultWidgetPalette.green,
        deletionColor: DefaultWidgetPalette.coral,
        neutralColor: DefaultWidgetPalette.neutral
    )
}
