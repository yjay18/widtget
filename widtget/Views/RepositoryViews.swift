import SwiftUI

struct RepositoryList: View {
    let snapshot: ActivitySnapshot
    let limit: Int
    var compact = false

    private var maximumChange: CGFloat {
        CGFloat(max(snapshot.repositories.map(\.totalChanged).max() ?? 0, 1))
    }

    var body: some View {
        VStack(spacing: compact ? 7 : 9) {
            if snapshot.repositories.isEmpty {
                emptyRow
            } else {
                ForEach(snapshot.visibleRepositories(limit: limit)) { repository in
                    RepositoryRow(repository: repository, maximumChange: maximumChange, compact: compact)
                }
            }

            let hidden = snapshot.hiddenRepositoryCount(limit: limit)
            if hidden > 0 {
                HStack {
                    Text("+\(hidden) more")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidtgetPalette.secondaryText)
                    Spacer()
                }
            }
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(snapshot.state == .loading ? "Loading repositories" : "No repository activity")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
            Capsule()
                .fill(WidtgetPalette.neutral)
                .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RepositoryRow: View {
    let repository: RepositoryActivity
    let maximumChange: CGFloat
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            HStack(spacing: 6) {
                Text(repository.name)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidtgetPalette.primaryText)
                    .lineLimit(1)

                Text("\(repository.commits)c")
                    .font(.system(size: compact ? 8 : 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(WidtgetPalette.secondaryText)

                Spacer(minLength: 3)

                Text(ActivityNumberFormat.compact(repository.additions, sign: "+"))
                    .foregroundStyle(WidtgetPalette.green)
                Text(ActivityNumberFormat.compact(repository.deletions, sign: "−"))
                    .foregroundStyle(WidtgetPalette.coral)
            }
            .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
            .monospacedDigit()

            GeometryReader { proxy in
                let totalWidth = proxy.size.width * CGFloat(repository.totalChanged) / maximumChange
                let additionsWidth = repository.totalChanged == 0 ? 0 : totalWidth * CGFloat(repository.additions) / CGFloat(repository.totalChanged)

                HStack(spacing: 1) {
                    Capsule().fill(WidtgetPalette.green).frame(width: additionsWidth)
                    Capsule().fill(WidtgetPalette.coral).frame(width: max(0, totalWidth - additionsWidth))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WidtgetPalette.neutral)
                .clipShape(Capsule())
            }
            .frame(height: compact ? 3 : 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(repository.name), \(repository.commits) commits, \(repository.additions) additions, \(repository.deletions) deletions")
    }
}
