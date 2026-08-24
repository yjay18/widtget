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

    // Larger widgets get a taller playfield so the snek fills the extra room.
    private var maxBlocks: Int {
        switch family {
        case .small, .extraLarge: 20
        case .medium: 40
        case .large: 60
        }
    }

    // One block per N commits, capped at the family's playfield size.
    private var blocks: Int {
        let perBlock = min(max(preferences.snakeCommitsPerBlock,
                               CommitSnakeLimits.commitsPerBlockRange.lowerBound),
                           CommitSnakeLimits.commitsPerBlockRange.upperBound)
        return min(max(Int(ceil(Double(entry.snapshot.commits) / Double(perBlock))), 0), maxBlocks)
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
            playfield(cols: 10)
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
                    playfield(cols: 10)
                    Spacer(minLength: 0)
                    HStack { tag("\(blocks)/\(maxBlocks) BLOCKS"); Spacer(); tag("\(entry.snapshot.averagePerCommit) AVG") }
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
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    tag("SNEK · 1 = \(preferences.snakeCommitsPerBlock) COMMITS")
                    playfield(cols: 10)
                    HStack { tag("\(blocks)/\(maxBlocks)"); Spacer(); tag("LV.\(blocks)") }
                }
                .frame(width: 150)

                VStack(alignment: .leading, spacing: 6) {
                    tag("REPOSITORIES · \(entry.snapshot.repositories.count)")
                    arcadeRepos(limit: preferences.repositoryDetail.largeLimit)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                tag("HI \(entry.peakLabel.uppercased())")
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
                    panel { tag("LINES MADE"); PixelScore(text: score(entry.snapshot.additions, sign: "+"), size: 28, color: ArcadePalette.lightest) }
                    panel { tag("REMOVED"); PixelScore(text: score(entry.snapshot.deletions, sign: "-"), size: 20, color: ArcadePalette.food) }
                    panel {
                        HStack { tag("LV.\(blocks)"); Spacer(); tag("HI \(entry.peakLabel.uppercased())") }
                        HStack { tag("\(entry.snapshot.commits) COMMITS"); Spacer(); tag("\(entry.snapshot.averagePerCommit) AVG") }
                    }
                    tag("SNEK · 1 = \(preferences.snakeCommitsPerBlock) COMMITS")
                    playfield(cols: 10)
                    tag("\(blocks)/\(maxBlocks) BLOCKS")
                    Spacer(minLength: 0)
                }
                .frame(width: 220)

                VStack(alignment: .leading, spacing: 8) {
                    tag("REPOSITORIES · \(entry.snapshot.repositories.count)")
                    arcadeRepos(limit: preferences.repositoryDetail.extraLargeLimit)
                    Spacer(minLength: 0)
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

    // Exactly the 20-block cap, laid out as a serpentine so the lit cells wind like a
    // snake instead of filling a plain rectangle: rounded body segments, a head with
    // eyes, and the food drawn as a pellet.
    private func playfield(cols: Int) -> some View {
        let total = maxBlocks
        let rows = (total + cols - 1) / cols
        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<cols, id: \.self) { col in
                        // Boustrophedon: even rows run left→right, odd rows right→left.
                        let position = row * cols + (row % 2 == 0 ? col : cols - 1 - col)
                        snekCell(position: position, valid: position < total)
                    }
                }
            }
        }
    }

    private var snakeHead: Int { blocks - 1 }
    private var snakeFood: Int { blocks < maxBlocks ? blocks : -1 }

    @ViewBuilder
    private func snekCell(position: Int, valid: Bool) -> some View {
        let cell = Rectangle().fill(Color.clear)
        if !valid {
            cell.aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
        } else if position == snakeFood {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(ArcadePalette.empty)
                Circle().fill(ArcadePalette.food).padding(4)
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
        } else if position == snakeHead {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(ArcadePalette.lightest)
                HStack(spacing: 3) {
                    Circle().fill(ArcadePalette.darkest).frame(width: 3, height: 3)
                    Circle().fill(ArcadePalette.darkest).frame(width: 3, height: 3)
                }
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(position < blocks ? ArcadePalette.light : ArcadePalette.empty)
                .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
        }
    }

    private func arcadeRepos(limit: Int) -> some View {
        let peak = max(entry.snapshot.repositories.map(\.additions).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 6) {
            if entry.snapshot.repositories.isEmpty {
                tag("NO REPO ACTIVITY")
            }
            ForEach(entry.snapshot.visibleRepositories(limit: limit)) { repo in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(repo.name.uppercased()).lineLimit(1).minimumScaleFactor(0.6)
                            .foregroundStyle(ArcadePalette.light)
                        Spacer(minLength: 4)
                        Text(ActivityNumberFormat.compact(repo.additions, sign: "+"))
                            .foregroundStyle(ArcadePalette.lightest)
                    }
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    arcadeBar(fraction: Double(repo.additions) / Double(peak))
                }
            }
        }
    }

    private func arcadeBar(fraction: Double) -> some View {
        let cells = 14
        let filled = min(max(Int((Double(cells) * fraction).rounded()), 0), cells)
        return HStack(spacing: 2) {
            ForEach(0..<cells, id: \.self) { i in
                Rectangle().fill(i < filled ? ArcadePalette.light : ArcadePalette.empty).frame(height: 5)
            }
        }
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
