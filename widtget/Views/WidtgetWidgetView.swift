import SwiftUI
import WidgetKit

struct WidtgetWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ActivityEntry

    var body: some View {
        Group {
            switch entry.preferences.visualTheme {
            case .blockwork:
                ComposedWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            case .glasshouse:
                GlasshouseWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            case .phosphor:
                PhosphorWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            case .broadsheet:
                BroadsheetWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            case .arcade:
                ArcadeWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            case .defaultTheme:
                DefaultWidgetView(
                    entry: entry,
                    preferences: entry.preferences,
                    family: layoutFamily
                )
            }
        }
        .widgetURL(githubURL)
    }

    private var layoutFamily: WidgetLayoutFamily {
        switch family {
        case .systemSmall: .small
        case .systemMedium: .medium
        case .systemExtraLarge: .extraLarge
        default: .large
        }
    }

    private var githubURL: URL? {
        let path = entry.username.isEmpty ? "" : "/\(entry.username)"
        return URL(string: "https://github.com\(path)")
    }
}

private struct ComposedWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily

    private var palette: ComposedWidgetPalette {
        ComposedWidgetPalette(theme: preferences.visualTheme)
    }

    private var blocks: [WidgetPane] {
        preferences.blocks(for: family)
    }

    private var spacing: CGFloat {
        preferences.visualTheme == .blockwork ? 3 : 8
    }

    private var inset: CGFloat {
        preferences.visualTheme == .blockwork ? 0 : (family == .small ? 10 : 13)
    }

    var body: some View {
        VStack(spacing: 0) {
            ComposedPeriodHeader(entry: entry, theme: preferences.visualTheme)

            GeometryReader { proxy in
                composedSlots(size: proxy.size)
                    .padding(inset)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .background(palette.background)
    }

    @ViewBuilder
    private func composedSlots(size: CGSize) -> some View {
        switch family {
        case .small:
            if let block = blocks.first {
                slot(block)
            }
        case .medium:
            HStack(spacing: spacing) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    slot(block)
                }
            }
        case .large:
            let topHeight = max(0, (size.height - inset * 2 - spacing) * 0.44)
            VStack(spacing: spacing) {
                if let first = blocks.first {
                    slot(first)
                        .frame(height: topHeight)
                }
                HStack(spacing: spacing) {
                    ForEach(Array(blocks.dropFirst().enumerated()), id: \.offset) { _, block in
                        slot(block)
                    }
                }
            }
        case .extraLarge:
            HStack(spacing: spacing) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    slot(block)
                }
            }
        }
    }

    private func slot(_ block: WidgetPane) -> some View {
        WidgetBlockView(
            block: block,
            entry: entry,
            preferences: preferences,
            family: family,
            palette: palette
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.fill(for: block, choice: preferences.color(for: block)))
        .clipShape(
            RoundedRectangle(
                cornerRadius: preferences.visualTheme == .defaultTheme ? 12 : 0,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: preferences.visualTheme == .defaultTheme ? 12 : 0,
                style: .continuous
            )
            .stroke(palette.divider, lineWidth: preferences.visualTheme == .defaultTheme ? 1 : 0)
        }
        .clipped()
    }
}

private struct ComposedPeriodHeader: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: ActivityEntry
    let theme: WidgetVisualTheme

    private var palette: ComposedWidgetPalette {
        ComposedWidgetPalette(theme: theme)
    }

    var body: some View {
        HStack(spacing: 7) {
            if theme == .defaultTheme && widgetFamily != .systemSmall {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.addition)
            }

            Text(entry.username.isEmpty ? "GitHub" : "@\(entry.username)")
                .font(.system(size: widgetFamily == .systemSmall ? 9 : 10, weight: .black, design: .rounded))
                .foregroundStyle(palette.headerText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            Link(destination: URL(string: "widtget://refresh")!) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(entry.snapshot.state == .error ? palette.deletion : palette.addition)
                    .frame(width: 16, height: 16)
            }
            .accessibilityLabel("Refresh GitHub activity")

            Button(
                intent: SetActivityPeriodIntent(
                    period: entry.period.toggled,
                    family: ActivityWidgetFamily(widgetFamily: widgetFamily),
                    configuredPeriod: entry.configuredPeriod
                )
            ) {
                Text(entry.period.displayName)
                    .font(.system(size: widgetFamily == .systemSmall ? 7 : 8, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(theme == .blockwork ? palette.ink : palette.text)
                    .padding(.horizontal, widgetFamily == .systemSmall ? 5 : 7)
                    .padding(.vertical, theme == .blockwork ? 4 : 3)
                    .background {
                        if theme == .blockwork {
                            Rectangle().fill(palette.lime)
                        } else {
                            Capsule().stroke(palette.divider, lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
        .padding(.horizontal, theme == .blockwork ? 11 : 12)
        .padding(.vertical, theme == .blockwork ? 7 : 6)
        .background(palette.header)
    }
}

private struct WidgetBlockView: View {
    let block: WidgetPane
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily
    let palette: ComposedWidgetPalette

    private var fill: Color {
        palette.fill(for: block, choice: preferences.color(for: block))
    }

    private var foreground: Color {
        palette.foreground(for: block, choice: preferences.color(for: block))
    }

    private var contentPadding: CGFloat {
        switch family {
        case .small: 10
        case .medium: 11
        case .large: 12
        case .extraLarge: 13
        }
    }

    var body: some View {
        Group {
            switch block {
            case .additions:
                metricBlock(
                    label: "LINES MADE",
                    value: entry.snapshot.additions,
                    sign: "+",
                    valueColor: preferences.visualTheme == .defaultTheme
                        ? palette.addition
                        : foreground,
                    footer: "\(ActivityNumberFormat.compact(entry.snapshot.deletions, sign: "−")) REMOVED"
                )
            case .deletions:
                metricBlock(
                    label: "LINES REMOVED",
                    value: entry.snapshot.deletions,
                    sign: "−",
                    valueColor: palette.deletion,
                    footer: "NET \(signedCompact(entry.snapshot.additions - entry.snapshot.deletions))"
                )
            case .summary:
                summaryBlock
            case .activity:
                activityBarsBlock
            case .activityTable:
                activityTableBlock
            case .insights:
                insightsBlock
            case .repositories:
                repositoriesBlock
            case .snake:
                CommitSnakeView(
                    snapshot: entry.snapshot,
                    commitsPerBlock: preferences.snakeCommitsPerBlock,
                    expanded: isExpandedFamily
                )
                .background(fill)
            }
        }
        .foregroundStyle(foreground)
    }

    private func metricBlock(
        label: String,
        value: Int,
        sign: Character,
        valueColor: Color,
        footer: String
    ) -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: isExpandedFamily ? 7 : 5) {
                blockLabel(label)

                if isExpandedFamily {
                    metricContext(horizontal: proxy.size.width > proxy.size.height * 1.6)
                }

                Spacer(minLength: 1)

                Text(
                    entry.snapshot.state == .loading
                        ? "\(sign)––,–––"
                        : ActivityNumberFormat.exact(value, sign: sign)
                )
                .font(.system(size: metricFontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .contentTransition(.numericText())

                Text(footer)
                    .font(.system(size: isExpandedFamily ? 7.5 : 7, weight: .black, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(foreground.opacity(0.68))
                    .lineLimit(1)
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }

    private var summaryBlock: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                blockLabel("SUMMARY")

                if isExpandedFamily {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 7),
                            count: proxy.size.width > proxy.size.height * 1.45 ? 3 : 2
                        ),
                        spacing: 7
                    ) {
                        expandedSummaryValue(entry.snapshot.commits, label: "COMMITS")
                        expandedSummaryValue(entry.snapshot.repositories.count, label: "REPOS")
                        expandedSummaryValue(activeIntervals, label: "ACTIVE")
                        expandedSummaryValue(totalChanged, label: "CHANGED")
                        expandedSummaryValue(entry.snapshot.additions - entry.snapshot.deletions, label: "NET", signed: true)
                        expandedSummaryValue(averagePerCommit, label: "AVG / COMMIT")
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    HStack(spacing: 10) {
                        summaryValue(entry.snapshot.commits, label: "COMMITS")
                        divider
                        summaryValue(entry.snapshot.repositories.count, label: "REPOS")
                        divider
                        summaryValue(activeIntervals, label: "ACTIVE")
                    }
                    Spacer(minLength: 0)
                }

                if preferences.showUpdateTime {
                    statusText
                }
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activityBarsBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            blockLabel("ACTIVITY BARS")
            GeometryReader { proxy in
                ActivityStrip(
                    cells: entry.snapshot.activity,
                    height: max(10, proxy.size.height),
                    additionColor: palette.activityAddition,
                    deletionColor: palette.deletion,
                    neutralColor: palette.neutral
                )
            }
            ActivityAxisLabels(
                labels: activityLabels,
                fontSize: isExpandedFamily ? 7.5 : 6.5,
                color: foreground.opacity(0.7)
            )
            if isExpandedFamily {
                activityInsightRail
            }
            if preferences.showUpdateTime {
                statusText
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activityTableBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            blockLabel("ACTIVITY TABLE")

            if isExpandedFamily {
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 6) {
                        ActivityStrip(
                            cells: entry.snapshot.activity,
                            height: expandedActivityChartHeight(availableHeight: proxy.size.height),
                            additionColor: palette.activityAddition,
                            deletionColor: palette.deletion,
                            neutralColor: palette.neutral
                        )

                        ActivityAxisLabels(
                            labels: activityLabels,
                            fontSize: 7,
                            color: foreground.opacity(0.7)
                        )

                        if proxy.size.height > 115 {
                            ActivityGrid(
                                cells: entry.snapshot.activity,
                                labels: [],
                                additionColor: palette.activityAddition,
                                deletionColor: palette.deletion,
                                neutralColor: palette.neutral,
                                labelColor: foreground.opacity(0.68)
                            )
                        }

                        activityInsightRail
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
                }
            } else {
                ActivityGrid(
                    cells: entry.snapshot.activity,
                    labels: activityLabels.count == entry.snapshot.activity.count ? activityLabels : [],
                    labelFontSize: 6,
                    additionColor: palette.activityAddition,
                    deletionColor: palette.deletion,
                    neutralColor: palette.neutral,
                    labelColor: foreground.opacity(0.68)
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var insightsBlock: some View {
        let net = entry.snapshot.additions - entry.snapshot.deletions
        let total = entry.snapshot.additions + entry.snapshot.deletions
        let average = entry.snapshot.commits == 0 ? 0 : total / entry.snapshot.commits
        let peakIndex = entry.snapshot.activity.enumerated().max {
            $0.element.totalChanged < $1.element.totalChanged
        }?.offset
        let peak = peakIndex.flatMap { activityLabels.indices.contains($0) ? activityLabels[$0] : nil } ?? "—"

        return VStack(alignment: .leading, spacing: 9) {
            blockLabel("NET / PEAK / AVG")
            insightValue(signedCompact(net), label: "NET LINES", color: net < 0 ? palette.deletion : foreground)
                .frame(maxHeight: isExpandedFamily ? .infinity : nil, alignment: .topLeading)
            divider.frame(maxWidth: .infinity, maxHeight: 2)
            insightValue(peak.uppercased(), label: "PEAK INTERVAL", color: foreground)
                .frame(maxHeight: isExpandedFamily ? .infinity : nil, alignment: .topLeading)
            divider.frame(maxWidth: .infinity, maxHeight: 2)
            insightValue(average.formatted(), label: "LINES / COMMIT", color: foreground)
                .frame(maxHeight: isExpandedFamily ? .infinity : nil, alignment: .topLeading)
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var repositoriesBlock: some View {
        VStack(alignment: .leading, spacing: family == .extraLarge ? 9 : 6) {
            blockLabel("REPOSITORIES / \(entry.snapshot.repositories.count)")

            if entry.snapshot.repositories.isEmpty {
                Text("NO REPOSITORY ACTIVITY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(foreground.opacity(0.62))
            } else {
                ForEach(entry.snapshot.visibleRepositories(limit: repositoryLimit)) { repository in
                    repositoryRow(repository)
                        .frame(maxHeight: isExpandedFamily ? .infinity : nil, alignment: .top)
                }

                let hiddenCount = entry.snapshot.hiddenRepositoryCount(limit: repositoryLimit)
                if hiddenCount > 0 {
                    Text("+\(hiddenCount) MORE REPOSITORIES")
                        .font(.system(size: 6.5, weight: .black, design: .monospaced))
                        .foregroundStyle(foreground.opacity(0.62))
                }
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func blockLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: isExpandedFamily ? 8.5 : 7.5, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(foreground.opacity(0.72))
            .lineLimit(1)
    }

    @ViewBuilder
    private func metricContext(horizontal: Bool) -> some View {
        if horizontal {
            HStack(spacing: 5) {
                metricContextValue(entry.snapshot.commits.formatted(), label: "COMMITS")
                metricContextValue(signedCompact(entry.snapshot.additions - entry.snapshot.deletions), label: "NET")
                metricContextValue(averagePerCommit.formatted(), label: "AVG / COMMIT")
            }
            .frame(height: 34)
        } else {
            VStack(spacing: 5) {
                metricContextValue(entry.snapshot.commits.formatted(), label: "COMMITS")
                metricContextValue(signedCompact(entry.snapshot.additions - entry.snapshot.deletions), label: "NET")
                metricContextValue(averagePerCommit.formatted(), label: "AVG / COMMIT")
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func metricContextValue(_ value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer(minLength: 2)

            Text(label)
                .font(.system(size: 5.5, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            Rectangle().stroke(foreground.opacity(0.42), lineWidth: 1)
        }
    }

    private func expandedSummaryValue(_ value: Int, label: String, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(signed ? signedCompact(value) : value.formatted())
                .font(.system(size: family == .extraLarge ? 18 : 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(label)
                .font(.system(size: 5.8, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.62))
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            Rectangle().stroke(foreground.opacity(0.42), lineWidth: 1)
        }
    }

    private var activityInsightRail: some View {
        HStack(spacing: 5) {
            activityRailValue(activeIntervals.formatted(), label: "ACTIVE")
            activityRailValue(peakActivityLabel, label: "PEAK")
            activityRailValue(
                String(ActivityNumberFormat.compact(totalChanged, sign: "+").dropFirst()),
                label: "CHANGED"
            )
        }
        .frame(height: 29)
    }

    private func activityRailValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            Text(label)
                .font(.system(size: 5.2, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.58))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay {
            Rectangle().stroke(foreground.opacity(0.4), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func repositoryRow(_ repository: RepositoryActivity) -> some View {
        if isExpandedFamily {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(repository.name)
                        .font(.system(size: family == .extraLarge ? 10.5 : 9.5, weight: .black, design: .rounded))
                        .lineLimit(1)

                    Spacer(minLength: 3)

                    Text(ActivityNumberFormat.compact(repository.additions, sign: "+"))
                    Text(ActivityNumberFormat.compact(repository.deletions, sign: "−"))
                        .foregroundStyle(palette.deletion)
                }
                .font(.system(size: 7, weight: .black, design: .monospaced))

                HStack(spacing: 6) {
                    Text("\(repository.commits) COMMITS")
                    Text("\(ActivityNumberFormat.compact(repository.totalChanged, sign: "+").dropFirst()) CHANGED")
                }
                .font(.system(size: 5.6, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.58))

                GeometryReader { proxy in
                    let total = CGFloat(max(repository.totalChanged, 1))
                    HStack(spacing: 0) {
                        foreground
                            .opacity(0.76)
                            .frame(width: proxy.size.width * CGFloat(repository.additions) / total)
                        palette.deletion
                            .opacity(0.84)
                    }
                    .background(foreground.opacity(0.14))
                }
                .frame(height: 4)
            }
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Text(repository.name)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 3)
                    Text(ActivityNumberFormat.compact(repository.additions, sign: "+"))
                    Text(ActivityNumberFormat.compact(repository.deletions, sign: "−"))
                        .foregroundStyle(palette.deletion)
                }
                .font(.system(size: 7, weight: .black, design: .monospaced))
                Rectangle()
                    .fill(foreground.opacity(0.7))
                    .frame(height: preferences.visualTheme == .blockwork ? 2 : 1)
            }
        }
    }

    private func expandedActivityChartHeight(availableHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = availableHeight > 115 ? 82 : 45
        return max(24, availableHeight - reservedHeight)
    }

    private func summaryValue(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.formatted())
                .font(.system(size: family == .small ? 18 : 23, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightValue(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: family == .extraLarge ? 22 : 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 6.5, weight: .black, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.62))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(foreground.opacity(0.52))
            .frame(width: 1)
    }

    private var statusText: some View {
        Group {
            if entry.snapshot.state == .setupRequired {
                Text("OPEN APP TO CONNECT")
            } else if entry.snapshot.state == .error {
                Text(entry.snapshot.errorMessage ?? "COULDN'T REFRESH")
                    .foregroundStyle(palette.deletion)
            } else if entry.snapshot.isStale {
                Text("STALE · \(entry.snapshot.updatedAt, style: .relative)")
            } else {
                Text("UPDATED \(entry.snapshot.updatedAt, style: .relative)")
            }
        }
        .font(.system(size: 7, weight: .black, design: .monospaced))
        .foregroundStyle(foreground.opacity(0.64))
        .lineLimit(1)
    }

    private var metricFontSize: CGFloat {
        switch family {
        case .small: 34
        case .medium: 32
        case .large: 41
        case .extraLarge: 43
        }
    }

    private var repositoryLimit: Int {
        switch family {
        case .small: 1
        case .medium: preferences.repositoryDetail.mediumLimit
        case .large: preferences.repositoryDetail.largeLimit
        case .extraLarge: preferences.repositoryDetail.extraLargeLimit
        }
    }

    private var activeIntervals: Int {
        entry.snapshot.activity.filter { $0.totalChanged > 0 }.count
    }

    private var isExpandedFamily: Bool {
        family == .large || family == .extraLarge
    }

    private var totalChanged: Int {
        entry.snapshot.additions + entry.snapshot.deletions
    }

    private var averagePerCommit: Int {
        entry.snapshot.commits == 0 ? 0 : totalChanged / entry.snapshot.commits
    }

    private var peakActivityLabel: String {
        guard let peakIndex = entry.snapshot.activity.enumerated().max(by: {
            $0.element.totalChanged < $1.element.totalChanged
        })?.offset,
        entry.snapshot.activity.indices.contains(peakIndex),
        entry.snapshot.activity[peakIndex].totalChanged > 0,
        activityLabels.indices.contains(peakIndex) else {
            return "—"
        }
        return activityLabels[peakIndex].uppercased()
    }

    private var activityLabels: [String] {
        ActivityIntervalLabels.labels(
            period: entry.period,
            windowMode: preferences.periodWindowMode,
            referenceDate: entry.snapshot.updatedAt,
            cellCount: entry.snapshot.activity.count,
            style: family == .extraLarge ? .expanded : .compact
        )
    }

    private func signedCompact(_ value: Int) -> String {
        ActivityNumberFormat.compact(value, sign: value < 0 ? "−" : "+")
    }
}

private struct ComposedWidgetPalette {
    let theme: WidgetVisualTheme

    let ink = Color(red: 0.063, green: 0.067, blue: 0.059)
    let paper = Color(red: 0.937, green: 0.898, blue: 0.804)
    let orange = Color(red: 0.953, green: 0.357, blue: 0.173)
    let lime = Color(red: 0.725, green: 0.863, blue: 0.235)
    let sky = Color(red: 0.412, green: 0.729, blue: 0.859)

    var background: Color {
        theme == .blockwork ? paper : Color(red: 0.035, green: 0.047, blue: 0.063)
    }

    var header: Color {
        theme == .blockwork ? ink : background
    }

    var headerText: Color {
        theme == .blockwork ? paper : text
    }

    var text: Color {
        theme == .blockwork ? ink : Color(red: 0.93, green: 0.95, blue: 0.97)
    }

    var muted: Color {
        theme == .blockwork ? ink.opacity(0.62) : Color(red: 0.52, green: 0.57, blue: 0.63)
    }

    var divider: Color {
        theme == .blockwork ? ink : Color.white.opacity(0.075)
    }

    var addition: Color {
        theme == .blockwork ? ink : Color(red: 0.22, green: 0.80, blue: 0.46)
    }

    var activityAddition: Color {
        theme == .blockwork ? ink : Color(red: 0.22, green: 0.80, blue: 0.46)
    }

    var deletion: Color {
        theme == .blockwork ? orange : Color(red: 0.95, green: 0.38, blue: 0.40)
    }

    var neutral: Color {
        theme == .blockwork ? ink.opacity(0.18) : Color(red: 0.13, green: 0.16, blue: 0.20)
    }

    func fill(for block: WidgetPane, choice: WidgetBlockColor) -> Color {
        if choice != .automatic {
            return customFill(choice)
        }

        if theme == .defaultTheme {
            return Color(red: 0.075, green: 0.094, blue: 0.118)
        }

        switch block {
        case .additions: return orange
        case .deletions, .snake: return ink
        case .summary, .insights: return lime
        case .activity, .activityTable: return sky
        case .repositories: return paper
        }
    }

    func foreground(for block: WidgetPane, choice: WidgetBlockColor) -> Color {
        if theme == .defaultTheme {
            if choice == .automatic {
                return text
            }
            return choice == .ink ? paper : ink
        }

        let resolved = choice == .automatic ? automaticChoice(for: block) : choice
        return resolved == .ink ? paper : ink
    }

    private func automaticChoice(for block: WidgetPane) -> WidgetBlockColor {
        switch block {
        case .deletions, .snake: .ink
        case .additions: .orange
        case .summary, .insights: .lime
        case .activity, .activityTable: .sky
        case .repositories: .paper
        }
    }

    private func customFill(_ choice: WidgetBlockColor) -> Color {
        switch choice {
        case .automatic: paper
        case .orange: orange
        case .lime: lime
        case .sky: sky
        case .ink: ink
        case .paper: paper
        }
    }
}

private struct SmallWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 0) {
            PeriodHeader(entry: entry, compact: true)

            if let primaryMetricPane {
                smallMetricTile(primaryMetricPane)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    BlockworkSectionLabel("WEEKLY OUTPUT")
                    Text("\(entry.snapshot.commits)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text("COMMITS")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WidtgetPalette.lime)
            }

            if preferences.showActivity {
                ActivityStrip(cells: entry.snapshot.activity, height: 10)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(WidtgetPalette.sky)
            }

            SecondaryMetrics(snapshot: entry.snapshot, compact: true)
        }
    }

    @ViewBuilder
    private func smallMetricTile(_ pane: WidgetPane) -> some View {
        let secondary = secondaryMetricPane.map(metricSummary) ?? "\(entry.snapshot.commits) COMMITS"

        if pane == .deletions {
            BlockworkMetricTile(
                value: entry.snapshot.deletions,
                label: "LINES REMOVED",
                footer: secondary,
                sign: "−",
                fill: WidtgetPalette.ink,
                foreground: WidtgetPalette.paper,
                valueColor: WidtgetPalette.orange,
                fontSize: 32,
                loading: entry.snapshot.state == .loading
            )
        } else {
            BlockworkMetricTile(
                value: entry.snapshot.additions,
                label: "LINES MADE",
                footer: secondary,
                sign: "+",
                fill: WidtgetPalette.orange,
                foreground: WidtgetPalette.ink,
                valueColor: WidtgetPalette.ink,
                fontSize: 34,
                loading: entry.snapshot.state == .loading
            )
        }
    }

    private var primaryMetricPane: WidgetPane? {
        preferences.visiblePaneOrder.first { $0 == .additions || $0 == .deletions }
    }

    private var secondaryMetricPane: WidgetPane? {
        preferences.visiblePaneOrder.first {
            ($0 == .additions || $0 == .deletions) && $0 != primaryMetricPane
        }
    }

    private func metricSummary(_ pane: WidgetPane) -> String {
        switch pane {
        case .additions:
            "\(ActivityNumberFormat.compact(entry.snapshot.additions, sign: "+")) MADE"
        case .deletions:
            "\(ActivityNumberFormat.compact(entry.snapshot.deletions, sign: "−")) REMOVED"
        default:
            "\(entry.snapshot.commits) COMMITS"
        }
    }
}

private struct MediumWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 0) {
            PeriodHeader(entry: entry)

            GeometryReader { proxy in
                let metricArea = hasDetails
                    ? proxy.size.width * (orderedMetricPanes.count > 1 ? 0.64 : 0.43)
                    : proxy.size.width
                let metricWidth = orderedMetricPanes.isEmpty
                    ? 0
                    : metricArea / CGFloat(orderedMetricPanes.count)
                let detailsWidth = hasDetails ? max(0, proxy.size.width - metricArea) : 0

                HStack(spacing: 0) {
                    ForEach(Array(orderedMetricPanes.enumerated()), id: \.element) { index, pane in
                        mediumMetricPane(pane)
                            .frame(width: metricWidth)
                            .overlay(alignment: .leading) {
                                if index > 0 {
                                    BlockworkDivider()
                                }
                            }
                    }

                    if hasDetails {
                        mediumDetails
                            .frame(width: detailsWidth)
                            .overlay(alignment: .leading) {
                                if !orderedMetricPanes.isEmpty {
                                    BlockworkDivider()
                                }
                            }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var mediumDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            BlockworkSectionLabel("MODULES / \(orderedDetailPanes.count)")

            ForEach(orderedDetailPanes) { pane in
                switch pane {
                case .activity:
                    ActivityStrip(cells: entry.snapshot.activity, height: 26)
                case .repositories:
                    RepositoryList(
                        snapshot: entry.snapshot,
                        limit: preferences.repositoryDetail.mediumLimit,
                        compact: true
                    )
                default:
                    EmptyView()
                }
            }

            Spacer(minLength: 0)

            if preferences.showUpdateTime {
                UpdateStatus(snapshot: entry.snapshot)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidtgetPalette.sky)
        .clipped()
    }

    @ViewBuilder
    private func mediumMetricPane(_ pane: WidgetPane) -> some View {
        if pane == .deletions {
            BlockworkMetricTile(
                value: entry.snapshot.deletions,
                label: "REMOVED",
                footer: "NET \(netChange)",
                sign: "−",
                fill: WidtgetPalette.ink,
                foreground: WidtgetPalette.paper,
                valueColor: WidtgetPalette.orange,
                fontSize: 28,
                loading: entry.snapshot.state == .loading
            )
        } else {
            BlockworkMetricTile(
                value: entry.snapshot.additions,
                label: "LINES MADE",
                footer: "\(entry.snapshot.commits) COMMITS",
                sign: "+",
                fill: WidtgetPalette.orange,
                foreground: WidtgetPalette.ink,
                valueColor: WidtgetPalette.ink,
                fontSize: 34,
                loading: entry.snapshot.state == .loading
            )
        }
    }

    private var orderedMetricPanes: [WidgetPane] {
        preferences.visiblePaneOrder.filter { $0 == .additions || $0 == .deletions }
    }

    private var orderedDetailPanes: [WidgetPane] {
        preferences.visiblePaneOrder.filter {
            ($0 == .activity && preferences.showActivity)
                || ($0 == .repositories && preferences.showRepositories)
        }
    }

    private var hasDetails: Bool {
        !orderedDetailPanes.isEmpty || preferences.showUpdateTime
    }

    private var netChange: String {
        ActivityNumberFormat.compact(
            entry.snapshot.additions - entry.snapshot.deletions,
            sign: entry.snapshot.additions >= entry.snapshot.deletions ? "+" : "−"
        )
    }
}

private struct LargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 0) {
            PeriodHeader(entry: entry)

            if !orderedMetricPanes.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(orderedMetricPanes.enumerated()), id: \.element) { index, pane in
                        largeMetricPane(pane)
                            .frame(
                                maxWidth: pane == .deletions && orderedMetricPanes.count > 1
                                    ? 150
                                    : .infinity
                            )
                            .overlay(alignment: .leading) {
                                if index > 0 {
                                    BlockworkDivider()
                                }
                            }
                    }
                }
                .frame(height: 86)
            }

            SecondaryMetrics(snapshot: entry.snapshot)
                .overlay(alignment: .top) { BlockworkDivider(horizontal: true) }
                .overlay(alignment: .bottom) { BlockworkDivider(horizontal: true) }

            if !orderedDetailPanes.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(orderedDetailPanes.enumerated()), id: \.element) { index, pane in
                        largeDetailPane(pane)
                            .overlay(alignment: .leading) {
                                if index > 0 {
                                    BlockworkDivider()
                                }
                            }
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func largeMetricPane(_ pane: WidgetPane) -> some View {
        if pane == .deletions {
            BlockworkMetricTile(
                value: entry.snapshot.deletions,
                label: "REMOVED",
                footer: "CLEAN CUTS",
                sign: "−",
                fill: WidtgetPalette.ink,
                foreground: WidtgetPalette.paper,
                valueColor: WidtgetPalette.orange,
                fontSize: 35,
                loading: entry.snapshot.state == .loading
            )
        } else {
            BlockworkMetricTile(
                value: entry.snapshot.additions,
                label: "LINES MADE",
                footer: "\(entry.snapshot.commits) COMMITS",
                sign: "+",
                fill: WidtgetPalette.orange,
                foreground: WidtgetPalette.ink,
                valueColor: WidtgetPalette.ink,
                fontSize: 43,
                loading: entry.snapshot.state == .loading
            )
        }
    }

    @ViewBuilder
    private func largeDetailPane(_ pane: WidgetPane) -> some View {
        switch pane {
        case .activity:
            largeActivityPanel
        case .repositories:
            largeRepositoryPanel
        default:
            EmptyView()
        }
    }

    private var largeActivityPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            BlockworkSectionLabel("ACTIVITY")

            if preferences.showActivity {
                ActivityStrip(cells: entry.snapshot.activity, height: 42)
                ActivityGrid(
                    cells: entry.snapshot.activity,
                    labels: compactActivityLabels,
                    labelFontSize: 6.5
                )

                Rectangle()
                    .fill(WidtgetPalette.ink)
                    .frame(height: 2)

                ActivityInsights(
                    snapshot: entry.snapshot,
                    labels: expandedActivityLabels,
                    compact: true
                )
            }

            Spacer(minLength: 0)

            if preferences.showUpdateTime {
                UpdateStatus(snapshot: entry.snapshot)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidtgetPalette.sky)
        .clipped()
    }

    private var largeRepositoryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockworkSectionLabel("REPOSITORIES / \(entry.snapshot.repositories.count)")
            RepositoryList(
                snapshot: entry.snapshot,
                limit: preferences.repositoryDetail.largeLimit
            )
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidtgetPalette.paper)
        .clipped()
    }

    private var compactActivityLabels: [String] {
        activityLabels(style: .compact)
    }

    private var expandedActivityLabels: [String] {
        activityLabels(style: .expanded)
    }

    private var orderedMetricPanes: [WidgetPane] {
        preferences.visiblePaneOrder.filter { $0 == .additions || $0 == .deletions }
    }

    private var orderedDetailPanes: [WidgetPane] {
        preferences.paneOrder.filter {
            ($0 == .activity && (preferences.showActivity || preferences.showUpdateTime))
                || ($0 == .repositories && preferences.showRepositories)
        }
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
}

private struct ExtraLargeWidgetView: View {
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences

    var body: some View {
        VStack(spacing: 0) {
            PeriodHeader(entry: entry)

            HStack(spacing: 0) {
                extraLargeMetrics

                ForEach(Array(orderedDetailGroups.enumerated()), id: \.element) { _, group in
                    extraLargeDetailGroup(group)
                        .overlay(alignment: .leading) { BlockworkDivider() }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var extraLargeMetrics: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedMetricPanes.enumerated()), id: \.element) { index, pane in
                extraLargeMetricPane(pane)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            BlockworkDivider(horizontal: true)
                        }
                    }
            }

            SecondaryMetrics(snapshot: entry.snapshot)
                .overlay(alignment: .top) {
                    if !orderedMetricPanes.isEmpty {
                        BlockworkDivider(horizontal: true)
                    }
                }

            ActivityInsights(snapshot: entry.snapshot, labels: activityLabels)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(WidtgetPalette.lime)
                .overlay(alignment: .top) { BlockworkDivider(horizontal: true) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func extraLargeMetricPane(_ pane: WidgetPane) -> some View {
        if pane == .deletions {
            BlockworkMetricTile(
                value: entry.snapshot.deletions,
                label: "LINES REMOVED",
                footer: "NET \(netChange)",
                sign: "−",
                fill: WidtgetPalette.ink,
                foreground: WidtgetPalette.paper,
                valueColor: WidtgetPalette.orange,
                fontSize: 46,
                loading: entry.snapshot.state == .loading
            )
        } else {
            BlockworkMetricTile(
                value: entry.snapshot.additions,
                label: "LINES MADE",
                footer: "\(entry.snapshot.commits) COMMITS",
                sign: "+",
                fill: WidtgetPalette.orange,
                foreground: WidtgetPalette.ink,
                valueColor: WidtgetPalette.ink,
                fontSize: 50,
                loading: entry.snapshot.state == .loading
            )
        }
    }

    @ViewBuilder
    private func extraLargeDetailGroup(_ group: ExtraLargeDetailGroup) -> some View {
        switch group {
        case .activityAndSnake:
            extraLargeActivityColumn
        case .repositories:
            extraLargeRepositoryPanel
        }
    }

    private var extraLargeActivityColumn: some View {
        Group {
            if preferences.showActivity && preferences.shows(.snake) {
                GeometryReader { proxy in
                    let spacing: CGFloat = 10
                    let minimumPetHeight: CGFloat = 76
                    let desiredActivityHeight = proxy.size.height * 0.62
                    let maximumActivityHeight = max(0, proxy.size.height - spacing - minimumPetHeight)
                    let activityHeight = min(desiredActivityHeight, maximumActivityHeight)

                    VStack(spacing: spacing) {
                        activityPanel
                            .frame(height: activityHeight, alignment: .topLeading)

                        CommitSnakeView(
                            snapshot: entry.snapshot,
                            commitsPerBlock: preferences.snakeCommitsPerBlock
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(WidtgetPalette.ink)
                    }
                    .padding(.leading, 3)
                    .background(WidtgetPalette.ink)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
                }
            } else if preferences.showActivity {
                activityPanel
            } else if preferences.shows(.snake) {
                CommitSnakeView(
                    snapshot: entry.snapshot,
                    commitsPerBlock: preferences.snakeCommitsPerBlock
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WidtgetPalette.ink)
            } else {
                activityPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockworkSectionLabel("ACTIVITY / \(entry.snapshot.activity.count) INTERVALS")

            if preferences.showActivity {
                VStack(spacing: 5) {
                    ActivityStrip(
                        cells: entry.snapshot.activity,
                        height: extraLargeActivityStripHeight
                    )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidtgetPalette.sky)
        .clipped()
    }

    private var extraLargeRepositoryPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            BlockworkSectionLabel("REPOSITORIES / \(entry.snapshot.repositories.count)")
            RepositoryList(
                snapshot: entry.snapshot,
                limit: preferences.repositoryDetail.extraLargeLimit
            )
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WidtgetPalette.paper)
        .clipped()
    }

    private var extraLargeActivityStripHeight: CGFloat {
        let rowCount = Int(ceil(Double(entry.snapshot.activity.count) / 7.0))
        return max(44, 82 - CGFloat(max(0, rowCount - 1)) * 24)
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

    private var orderedMetricPanes: [WidgetPane] {
        preferences.visiblePaneOrder.filter { $0 == .additions || $0 == .deletions }
    }

    private var orderedDetailGroups: [ExtraLargeDetailGroup] {
        preferences.paneOrder.reduce(into: [ExtraLargeDetailGroup]()) { result, pane in
            let group: ExtraLargeDetailGroup?
            switch pane {
            case .activity where preferences.showActivity || preferences.showUpdateTime:
                group = .activityAndSnake
            case .snake where preferences.shows(.snake):
                group = .activityAndSnake
            case .repositories where preferences.showRepositories:
                group = .repositories
            default:
                group = nil
            }

            if let group, !result.contains(group) {
                result.append(group)
            }
        }
    }

    private var netChange: String {
        ActivityNumberFormat.compact(
            entry.snapshot.additions - entry.snapshot.deletions,
            sign: entry.snapshot.additions >= entry.snapshot.deletions ? "+" : "−"
        )
    }
}

private enum ExtraLargeDetailGroup: Hashable {
    case activityAndSnake
    case repositories
}

private struct BlockworkMetricTile: View {
    let value: Int
    let label: String
    let footer: String
    let sign: Character
    let fill: Color
    let foreground: Color
    let valueColor: Color
    let fontSize: CGFloat
    let loading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BlockworkSectionLabel(label, color: foreground.opacity(0.76))

            Spacer(minLength: 1)

            PrimaryMetric(
                value: value,
                label: label,
                sign: sign,
                color: valueColor,
                fontSize: fontSize,
                loading: loading
            )

            Text(footer)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(0.35)
                .foregroundStyle(foreground.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(fill)
        .clipped()
    }
}

private struct BlockworkSectionLabel: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = WidtgetPalette.ink.opacity(0.72)) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 7.5, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}

private struct BlockworkDivider: View {
    var horizontal = false

    var body: some View {
        Rectangle()
            .fill(WidtgetPalette.ink)
            .frame(
                width: horizontal ? nil : 3,
                height: horizontal ? 3 : nil
            )
    }
}
