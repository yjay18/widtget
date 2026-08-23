import SwiftUI
import WidgetKit

// Broadsheet: newsprint set with hairlines and a high-contrast serif (system New
// York). Front-page figure, a day book with dotted leaders, activity engraved as
// bars, press red on deletions.
// ponytail: system serif stands in for Bodoni Moda; bundle the face for a closer
// match if the mockup's contrast matters.
enum BroadsheetPalette {
    static let paper = Color(red: 0.914, green: 0.894, blue: 0.835)
    static let ink = Color(red: 0.098, green: 0.090, blue: 0.059)
    static let red = Color(red: 0.620, green: 0.184, blue: 0.106)
    static let muted = Color(red: 0.427, green: 0.396, blue: 0.333)
    static let hair = Color(red: 0.765, green: 0.733, blue: 0.651)
}

struct BroadsheetWidgetView: View {
    // Broadsheet is the only light theme, so vibrant (de-emphasized) mode is where
    // it breaks worst: a bright paper ground whites out and dark ink drops away.
    // In vibrant mode clear the ground and render content as bright semantic
    // colours so it reads as light-on-material like the dark themes do.
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily

    private var vibrant: Bool { renderingMode != .fullColor }
    private var paperC: Color { vibrant ? .clear : BroadsheetPalette.paper }
    private var inkC: Color { vibrant ? .primary : BroadsheetPalette.ink }
    private var redC: Color { vibrant ? .primary : BroadsheetPalette.red }
    private var mutedC: Color { vibrant ? .secondary : BroadsheetPalette.muted }
    private var hairC: Color { vibrant ? Color.secondary.opacity(0.4) : BroadsheetPalette.hair }

    var body: some View {
        Group {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            case .extraLarge: extraLarge
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(paperC)
        .foregroundStyle(inkC)
    }

    private var loading: Bool { entry.snapshot.state == .loading }
    private var netSign: Character { entry.snapshot.net < 0 ? "−" : "+" }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Rectangle().fill(inkC).frame(height: 1).padding(.top, 2)
            kicker("Lines set this week").padding(.top, 9)
            figure(entry.snapshot.additions, sign: "+", size: 44)
            kicker("\(signedExact(entry.snapshot.deletions, sign: "−")) struck out", color: redC)
                .padding(.top, 4)
            Spacer(minLength: 0)
            engrave(height: 30)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Rectangle().fill(inkC).frame(height: 1).padding(.top, 2)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    kicker("Lines set").padding(.top, 8)
                    figure(entry.snapshot.additions, sign: "+", size: 44)
                    kicker("\(signedExact(entry.snapshot.deletions, sign: "−")) struck · net \(signedExact(entry.snapshot.net, sign: netSign))",
                           color: redC).padding(.top, 5)
                    Spacer(minLength: 0)
                    engrave(height: 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(hairC).frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    kicker("The day book").padding(.vertical, 8)
                    dayBook(limit: 5)
                    Spacer(minLength: 0)
                    Rectangle().fill(inkC).frame(height: 1).padding(.bottom, 5)
                    kicker("\(entry.snapshot.commits) commits · \(entry.snapshot.averagePerCommit) avg")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Rectangle().fill(inkC).frame(height: 1).padding(.top, 2)
            kicker("Lines set this week").padding(.top, 9)
            figure(entry.snapshot.additions, sign: "+", size: 56)
            kicker("\(signedExact(entry.snapshot.deletions, sign: "−")) struck · net \(signedExact(entry.snapshot.net, sign: netSign))",
                   color: redC).padding(.top, 4)
            engrave(height: 42).padding(.vertical, 10)
            Rectangle().fill(inkC).frame(height: 1)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    kicker("The day book").padding(.vertical, 8)
                    dayBook(limit: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(hairC).frame(width: 1)
                VStack(alignment: .leading, spacing: 0) {
                    kicker("Repositories").padding(.vertical, 8)
                    repoLedger(limit: preferences.repositoryDetail.largeLimit)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(inkC).frame(height: 1).padding(.top, 6)
            pet
        }
    }

    private var pet: some View {
        CommitPetView(
            commits: entry.snapshot.commits,
            perBlock: preferences.snakeCommitsPerBlock,
            net: entry.snapshot.net,
            bodyColor: inkC,
            headColor: redC,
            foodColor: redC,
            trackColor: hairC,
            textColor: inkC,
            caption: "Commit streak"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Rectangle().fill(inkC).frame(height: 1).padding(.top, 2)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    kicker("Lines set this week").padding(.top, 9)
                    figure(entry.snapshot.additions, sign: "+", size: 62)
                    kicker("\(signedExact(entry.snapshot.deletions, sign: "−")) struck", color: redC)
                        .padding(.top, 5)
                    kicker("net \(signedExact(entry.snapshot.net, sign: netSign)) · \(entry.snapshot.averagePerCommit) avg")
                        .padding(.top, 3)
                    Spacer(minLength: 0)
                    engrave(height: 60)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(hairC).frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    kicker("The day book").padding(.bottom, 8)
                    dayBook(limit: 8)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(hairC).frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    kicker("Repositories · \(entry.snapshot.repositories.count)").padding(.bottom, 8)
                    repoLedger(limit: preferences.repositoryDetail.extraLargeLimit)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("The commit record")
                .font(.system(size: family == .small ? 12 : 14, weight: .semibold, design: .serif))
            Spacer()
            Text(mastheadMeta)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1).foregroundStyle(mutedC).lineLimit(1)
        }
    }

    private var mastheadMeta: String {
        let period = entry.period.rawValue.capitalized
        return entry.username.isEmpty ? period : "\(period) · @\(entry.username)"
    }

    private func figure(_ value: Int, sign: Character, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(String(sign)).font(.system(size: size * 0.42, weight: .regular, design: .serif))
            Text(loading ? "—" : ActivityNumberFormat.exact(value, sign: " ").trimmingCharacters(in: .whitespaces))
                .font(.system(size: size, weight: .semibold, design: .serif))
        }
        .lineLimit(1).minimumScaleFactor(0.5)
        .accessibilityLabel("\(value) lines set")
    }

    private func kicker(_ text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .tracking(1).foregroundStyle(color ?? mutedC).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func dayBook(limit: Int) -> some View {
        let labels = entry.intervalLabels(style: .expanded)
        let cells = Array(entry.snapshot.activity.enumerated().prefix(limit))
        return VStack(spacing: 0) {
            ForEach(cells, id: \.offset) { index, cell in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(labels.indices.contains(index) ? labels[index] : "—")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                    DottedLeader().stroke(style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                        .foregroundStyle(hairC).frame(height: 1)
                    Text(loading ? "—" : "\(cell.totalChanged)")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(index == entry.snapshot.peakIndex ? redC : inkC)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func repoLedger(limit: Int) -> some View {
        let cells = entry.snapshot.visibleRepositories(limit: limit)
        return VStack(spacing: 0) {
            if entry.snapshot.repositories.isEmpty {
                kicker("No repository activity")
            }
            ForEach(cells) { repo in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(repo.name).font(.system(size: 12, weight: .regular, design: .serif)).lineLimit(1)
                    DottedLeader().stroke(style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                        .foregroundStyle(hairC).frame(height: 1)
                    Text(ActivityNumberFormat.compact(repo.additions, sign: "+"))
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func engrave(height: CGFloat) -> some View {
        let peak = max(entry.snapshot.activity.map(\.totalChanged).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(entry.snapshot.activity.enumerated()), id: \.offset) { index, cell in
                Rectangle()
                    .fill(index == entry.snapshot.peakIndex ? redC : inkC)
                    .frame(height: max(2, height * CGFloat(cell.totalChanged) / CGFloat(peak)))
                    .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: height, alignment: .bottom)
    }

    private func signedExact(_ value: Int, sign: Character) -> String {
        loading ? "\(sign)—" : ActivityNumberFormat.exact(value, sign: sign)
    }
}

private struct DottedLeader: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
