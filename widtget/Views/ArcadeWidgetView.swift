import SwiftUI
import WidgetKit

// Arcade: four-colour Game Boy palette built around the commit-snek pane. Commits
// are score, the peak day is a hi-score, the playfield lights up from the same
// block count the snek pane uses.
// ponytail: .monospaced stands in for a pixel face; bundle Silkscreen for the true
// arcade look.
enum ArcadePalette {
    static let darkest = Color(red: 0.059, green: 0.220, blue: 0.059)
    static let dark = Color(red: 0.188, green: 0.384, blue: 0.188)
    static let empty = Color(red: 0.114, green: 0.302, blue: 0.114)
    static let light = Color(red: 0.545, green: 0.675, blue: 0.059)
    static let lightest = Color(red: 0.608, green: 0.737, blue: 0.059)
    static let food = Color(red: 0.851, green: 0.310, blue: 0.118)
}

struct ArcadeWidgetView: View {
    // Clear the opaque ground when macOS de-emphasizes the widget (vibrant mode).
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
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(renderingMode == .fullColor ? ArcadePalette.darkest : Color.clear)
        .foregroundStyle(ArcadePalette.light)
    }

    private var loading: Bool { entry.snapshot.state == .loading }

    // Same mapping the snek pane uses: one block per N commits, capped at 20.
    private var blocks: Int {
        let perBlock = min(max(preferences.snakeCommitsPerBlock,
                               CommitSnakeLimits.commitsPerBlockRange.lowerBound),
                           CommitSnakeLimits.commitsPerBlockRange.upperBound)
        return min(max(Int(ceil(Double(entry.snapshot.commits) / Double(perBlock))), 0),
                   CommitSnakeLimits.visualBlockCount)
    }

    private func score(_ value: Int, sign: Character) -> String {
        loading ? "\(sign)—" : "\(sign)\(abs(value))"
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArcadeHUD(entry: entry)
            tag("LINES")
            PixelScore(text: score(entry.snapshot.additions, sign: "+"), size: 22, color: ArcadePalette.lightest)
            PixelScore(text: score(entry.snapshot.deletions, sign: "-"), size: 13, color: ArcadePalette.food)
            playfield(cols: 10, rows: 2)
            Spacer(minLength: 0)
            HStack {
                tag("LV.\(blocks)")
                Spacer()
                tag("\(entry.snapshot.repositories.count) REPOS")
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArcadeHUD(entry: entry)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    panel { tag("LINES MADE"); PixelScore(text: score(entry.snapshot.additions, sign: "+"), size: 22, color: ArcadePalette.lightest) }
                    panel { tag("REMOVED"); PixelScore(text: score(entry.snapshot.deletions, sign: "-"), size: 14, color: ArcadePalette.food) }
                    HStack { tag("LV.\(blocks)"); Spacer(); tag("HI \(entry.peakLabel.uppercased())") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    tag("SNEK · 1 BLOCK = \(preferences.snakeCommitsPerBlock) COMMITS")
                    playfield(cols: 12, rows: 3)
                    Spacer(minLength: 0)
                    HStack { tag("\(blocks)/\(CommitSnakeLimits.visualBlockCount) BLOCKS"); Spacer(); tag("\(entry.snapshot.averagePerCommit) AVG") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 9) {
            ArcadeHUD(entry: entry)
            HStack(alignment: .top, spacing: 12) {
                panel { tag("LINES MADE"); PixelScore(text: score(entry.snapshot.additions, sign: "+"), size: 26, color: ArcadePalette.lightest) }
                panel { tag("REMOVED"); PixelScore(text: score(entry.snapshot.deletions, sign: "-"), size: 18, color: ArcadePalette.food) }
            }
            tag("SNEK · 1 BLOCK = \(preferences.snakeCommitsPerBlock) COMMITS")
            playfield(cols: 16, rows: 5)
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                tag("LV.\(blocks)")
                tag("HI \(entry.peakLabel.uppercased())")
                tag("\(blocks)/\(CommitSnakeLimits.visualBlockCount) BLOCKS")
                Spacer()
                tag("\(entry.snapshot.averagePerCommit) AVG")
            }
        }
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArcadeHUD(entry: entry)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    panel { tag("LINES MADE"); PixelScore(text: score(entry.snapshot.additions, sign: "+"), size: 30, color: ArcadePalette.lightest) }
                    panel { tag("REMOVED"); PixelScore(text: score(entry.snapshot.deletions, sign: "-"), size: 20, color: ArcadePalette.food) }
                    panel {
                        HStack { tag("LV.\(blocks)"); Spacer(); tag("HI \(entry.peakLabel.uppercased())") }
                        HStack { tag("\(entry.snapshot.commits) COMMITS"); Spacer(); tag("\(entry.snapshot.averagePerCommit) AVG") }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 190)

                VStack(alignment: .leading, spacing: 8) {
                    tag("SNEK · 1 BLOCK = \(preferences.snakeCommitsPerBlock) COMMITS")
                    playfield(cols: 20, rows: 8)
                    HStack { tag("\(blocks)/\(CommitSnakeLimits.visualBlockCount) BLOCKS"); Spacer(); tag("\(entry.snapshot.repositories.count) REPOS") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(ArcadePalette.light).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .overlay { Rectangle().stroke(ArcadePalette.dark, lineWidth: 2) }
    }

    // Fills `blocks` cells as the snake (head lightest), one food cell after the head.
    private func playfield(cols: Int, rows: Int) -> some View {
        let total = cols * rows
        let head = blocks - 1
        let food = blocks < total ? blocks : -1
        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<cols, id: \.self) { col in
                        let i = row * cols + col
                        Rectangle().fill(cellColor(index: i, head: head, food: food))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cellColor(index: Int, head: Int, food: Int) -> Color {
        if index == food { return ArcadePalette.food }
        if index == head && head >= 0 { return ArcadePalette.lightest }
        if index < blocks { return ArcadePalette.light }
        return ArcadePalette.empty
    }
}

private struct ArcadeHUD: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.username.isEmpty ? "GITHUB" : entry.username.uppercased())
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Link(destination: URL(string: "widtget://refresh")!) {
                Text("↻").foregroundStyle(entry.snapshot.state == .error ? ArcadePalette.food : ArcadePalette.dark)
            }
            .accessibilityLabel("Refresh GitHub activity")
            Button(intent: SetActivityPeriodIntent(
                period: entry.period.toggled,
                family: ActivityWidgetFamily(widgetFamily: widgetFamily),
                configuredPeriod: entry.configuredPeriod
            )) {
                Text(entry.period.rawValue.uppercased()).foregroundStyle(ArcadePalette.lightest)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(ArcadePalette.light)
    }
}

// Hard 2px offset shadow, the arcade score look, without a bundled pixel font.
private struct PixelScore: View {
    let text: String
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text).foregroundStyle(ArcadePalette.dark).offset(x: 2, y: 2)
            Text(text).foregroundStyle(color)
        }
        .font(.system(size: size, weight: .heavy, design: .monospaced))
        .lineLimit(1).minimumScaleFactor(0.5)
    }
}
