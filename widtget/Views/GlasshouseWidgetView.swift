import SwiftUI
import WidgetKit

// Glasshouse: SF, hairline separators, no card frames. Colour only on the data —
// mint additions, rose deletions; everything else is text at a few opacities.
enum GlasshousePalette {
    static let base = Color(red: 0.110, green: 0.114, blue: 0.129)
    static let text = Color(red: 0.949, green: 0.953, blue: 0.961)
    static let mint = Color(red: 0.494, green: 0.886, blue: 0.659)
    static let rose = Color(red: 0.941, green: 0.525, blue: 0.549)
    static let hair = Color.white.opacity(0.12)
    static let quiet = Color.white.opacity(0.22)
}

struct GlasshouseWidgetView: View {
    // When the desktop is de-emphasized, macOS renders widgets in vibrant mode:
    // clear the opaque background so the system material shows and the light
    // content stays legible.
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily

    var body: some View {
        Group {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            case .extraLarge: extraLarge
            }
        }
        .padding(family == .small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(renderingMode == .fullColor ? GlasshousePalette.base : Color.clear)
        .foregroundStyle(GlasshousePalette.text)
    }

    private var loading: Bool { entry.snapshot.state == .loading }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            GlassHeader(entry: entry, compact: true)
            GlassMetric(value: entry.snapshot.additions, sign: "+", label: "lines added",
                        color: GlasshousePalette.mint, size: 34, loading: loading)
            GlassMetric(value: entry.snapshot.deletions, sign: "−", label: "lines deleted",
                        color: GlasshousePalette.rose, size: 17, loading: loading)
            Spacer(minLength: 0)
            GlassDivider()
            glassBars(cells: entry.snapshot.activity, height: 26)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassHeader(entry: entry)
            GlassDivider()
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    caption("lines added")
                    GlassMetric(value: entry.snapshot.additions, sign: "+", label: "lines added",
                                color: GlasshousePalette.mint, size: 34, loading: loading)
                    Text(ActivityNumberFormat.exact(entry.snapshot.deletions, sign: "−") + " removed")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(GlasshousePalette.rose)
                    Spacer(minLength: 0)
                    caption("net \(ActivityNumberFormat.compact(entry.snapshot.net, sign: entry.snapshot.net < 0 ? "−" : "+")) · \(entry.snapshot.averagePerCommit) avg")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    caption(entry.rhythmCaption)
                    Spacer(minLength: 0)
                    glassBars(cells: entry.snapshot.activity, height: 44)
                    glassAxis()
                    GlassDivider()
                    HStack {
                        Text("Peak").foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(entry.peakLabel).foregroundStyle(GlasshousePalette.text)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { GlassDivider(vertical: true).offset(x: -9) }
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassHeader(entry: entry)
            GlassDivider()
            HStack(alignment: .top, spacing: 20) {
                GlassMetric(value: entry.snapshot.additions, sign: "+", label: "lines added",
                            color: GlasshousePalette.mint, size: 38, loading: loading, caption: "lines added")
                GlassMetric(value: entry.snapshot.deletions, sign: "−", label: "lines deleted",
                            color: GlasshousePalette.rose, size: 28, loading: loading, caption: "lines deleted")
            }
            statsRow
            GlassDivider()
            VStack(alignment: .leading, spacing: 5) {
                caption(entry.rhythmCaption)
                glassBars(cells: entry.snapshot.activity, height: 32)
                glassAxis()
            }
            reposList(limit: min(preferences.repositoryDetail.largeLimit, 3))
            Spacer(minLength: 0)
        }
    }

    private var pet: some View {
        CommitPetView(
            commits: entry.snapshot.commits,
            perBlock: preferences.snakeCommitsPerBlock,
            net: entry.snapshot.net,
            bodyColor: GlasshousePalette.mint,
            headColor: GlasshousePalette.text,
            foodColor: GlasshousePalette.rose,
            trackColor: GlasshousePalette.hair,
            textColor: GlasshousePalette.text
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassHeader(entry: entry)
            GlassDivider()
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    GlassMetric(value: entry.snapshot.additions, sign: "+", label: "lines added",
                                color: GlasshousePalette.mint, size: 48, loading: loading, caption: "lines added")
                    GlassMetric(value: entry.snapshot.deletions, sign: "−", label: "lines deleted",
                                color: GlasshousePalette.rose, size: 34, loading: loading, caption: "lines deleted")
                    statsRow
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    caption(entry.rhythmCaption)
                    glassBars(cells: entry.snapshot.activity, height: 100)
                    glassAxis()
                    GlassDivider()
                    HStack {
                        Text("Peak \(entry.peakLabel)").foregroundStyle(GlasshousePalette.text)
                        Spacer()
                        Text("\(entry.snapshot.activeIntervals)/\(max(entry.snapshot.activity.count, 1)) active")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.system(size: 12, weight: .medium))
                    GlassDivider()
                    pet
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { GlassDivider(vertical: true).offset(x: -12) }

                VStack(alignment: .leading, spacing: 8) {
                    caption("repositories · \(entry.snapshot.repositories.count)")
                    reposList(limit: preferences.repositoryDetail.extraLargeLimit)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) { GlassDivider(vertical: true).offset(x: -12) }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            glassStat(ActivityNumberFormat.compact(entry.snapshot.net, sign: entry.snapshot.net < 0 ? "−" : "+"), "net")
            glassStat(entry.peakLabel, "peak")
            glassStat("\(entry.snapshot.averagePerCommit)", "avg / commit")
        }
    }

    private func glassStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 15, weight: .medium)).monospacedDigit()
            caption(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reposList(limit: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(entry.snapshot.visibleRepositories(limit: limit)) { repo in
                HStack {
                    Text(repo.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(ActivityNumberFormat.compact(repo.additions, sign: "+"))
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        .foregroundStyle(GlasshousePalette.mint)
                }
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) { GlassDivider() }
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
    }

    private func glassAxis() -> some View {
        let labels = entry.intervalLabels()
        return HStack(spacing: 2) {
            ForEach(labels.indices, id: \.self) { i in
                Text(labels[i]).font(.system(size: 8, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity)
            }
        }
    }

    private func glassBars(cells: [ActivityCell], height: CGFloat) -> some View {
        let peak = max(cells.map(\.totalChanged).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(cells) { cell in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(cell.totalChanged > 0 ? GlasshousePalette.mint : GlasshousePalette.quiet)
                    .frame(height: max(3, height * CGFloat(cell.totalChanged) / CGFloat(peak)))
                    .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

private struct GlassHeader: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: ActivityEntry
    var compact = false

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(GlasshousePalette.mint).frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
            Text(entry.username.isEmpty ? "github" : entry.username)
                .font(.system(size: compact ? 12 : 13, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Link(destination: URL(string: "widtget://refresh")!) {
                Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(entry.snapshot.state == .error ? GlasshousePalette.rose : .white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .accessibilityLabel("Refresh GitHub activity")
            Button(intent: SetActivityPeriodIntent(
                period: entry.period.toggled,
                family: ActivityWidgetFamily(widgetFamily: widgetFamily),
                configuredPeriod: entry.configuredPeriod
            )) {
                Text(entry.period.rawValue.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
        .foregroundStyle(GlasshousePalette.text)
    }
}

private struct GlassMetric: View {
    let value: Int
    let sign: Character
    let label: String
    let color: Color
    let size: CGFloat
    let loading: Bool
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let caption {
                Text(caption).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
            Text(loading ? "\(sign)—" : ActivityNumberFormat.exact(value, sign: sign))
                .font(.system(size: size, weight: .semibold)).monospacedDigit()
                .foregroundStyle(loading ? .white.opacity(0.3) : color)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .accessibilityLabel("\(value) \(label)")
        }
    }
}

private struct GlassDivider: View {
    var vertical = false
    var body: some View {
        Rectangle().fill(GlasshousePalette.hair)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
    }
}
