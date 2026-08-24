import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

private enum HostSection: String, CaseIterable, Identifiable {
    case dashboard
    case widgets
    case connections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .widgets: "Widget Studio"
        case .connections: "Connections"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "waveform.path.ecg"
        case .widgets: "square.grid.3x3.fill"
        case .connections: "key.horizontal.fill"
        }
    }
}

struct WidgetSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var github = GitHubAccountModel()
    @State private var showingDisconnectConfirmation = false
    @State private var showingRemoveOrganizationConfirmation = false
    @State private var organizationPendingRemoval: GitHubConnectionSummary?
    @State private var isReplacingAccountToken = false
    @State private var isAddingOrganization = false
    @State private var selectedSection: HostSection = .dashboard
    @State private var dashboardWindowMode = SharedPreferences.windowMode
    @State private var paneOrder = SharedPreferences.modularPreferences.paneOrder
    @State private var enabledPanes = SharedPreferences.modularPreferences.enabledPanes
    @State private var blockworkColorway = SharedPreferences.modularPreferences.colorway
    @State private var visualTheme = SharedPreferences.modularPreferences.visualTheme
    @State private var familyLayouts = SharedPreferences.modularPreferences.familyLayouts
    @State private var blockColors = SharedPreferences.modularPreferences.blockColors
    @State private var refreshInterval = SharedPreferences.refreshInterval
    @State private var snakeBlockBasis = SharedPreferences.snakeBlockBasis
    @State private var snakeUnitsPerBlock = SharedPreferences.snakeUnitsPerBlock
    @State private var themeOverrides: [WidgetLayoutFamily: WidgetVisualTheme] = Dictionary(
        uniqueKeysWithValues: WidgetLayoutFamily.allCases.compactMap { family in
            SharedPreferences.themeOverride(for: family).map { (family, $0) }
        }
    )
    @State private var selectedBlock: WidgetPane = .additions
    @State private var draggedPane: WidgetPane?
    @State private var draggedOrigin: WidgetSlotOrigin?

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Group {
                switch selectedSection {
                case .dashboard:
                    if visualTheme == .blockwork {
                        BlockworkAnalyticsDashboardView(
                            github: github,
                            windowMode: $dashboardWindowMode,
                            openConnections: { selectedSection = .connections }
                        )
                    } else {
                        AnalyticsDashboardView(
                            github: github,
                            windowMode: $dashboardWindowMode,
                            openConnections: { selectedSection = .connections }
                        )
                        .environment(\.themePalette, visualTheme.dashboardPalette)
                    }
                case .widgets:
                    widgetStudioContent
                case .connections:
                    connectionsContent
                }
            }
        }
        .frame(minWidth: 880, minHeight: 640)
        .background(DashboardPalette.ink)
        .preferredColorScheme(.dark)
        .task {
            migrateToFixedDefaultIfNeeded()
            reloadWidgets()
            await github.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await github.handleActivation() }
        }
        .onChange(of: paneOrder) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: enabledPanes) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: blockworkColorway) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: visualTheme) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: dashboardWindowMode) { _, newValue in
            SharedPreferences.windowMode = newValue
            reloadWidgets()
        }
        .onChange(of: familyLayouts) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: blockColors) { _, _ in
            saveWidgetStudio()
        }
        .onOpenURL { url in
            guard url.scheme == "widtget", url.host == "refresh" else { return }
            Task { await github.refresh(scope: .recentBranches) }
        }
        .confirmationDialog(
            "Disconnect @\(github.username)?",
            isPresented: $showingDisconnectConfirmation
        ) {
            Button("Disconnect GitHub", role: .destructive) {
                github.disconnect()
            }
        } message: {
            Text("The Keychain token and cached widget activity will be removed from this Mac.")
        }
        .confirmationDialog(
            "Remove \(organizationPendingRemoval?.owner ?? "organization")?",
            isPresented: $showingRemoveOrganizationConfirmation
        ) {
            Button("Remove organization", role: .destructive) {
                guard let id = organizationPendingRemoval?.id else { return }
                Task { await github.removeOrganization(id: id) }
            }
        } message: {
            Text("Its token will be removed from Keychain and its repositories will stop contributing to the widget.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DashboardPalette.green)
                    Text("W")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(DashboardPalette.ink)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("widtget")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text("GITHUB SIGNAL")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(DashboardPalette.muted)
                }
            }
            .padding(.horizontal, 14)

            VStack(spacing: 5) {
                ForEach(HostSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 18)
                            Text(section.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundStyle(selectedSection == section ? DashboardPalette.text : DashboardPalette.text.opacity(0.68))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            selectedSection == section ? DashboardPalette.lifted : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(alignment: .leading) {
                            if selectedSection == section {
                                Capsule()
                                    .fill(DashboardPalette.green)
                                    .frame(width: 3, height: 18)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)

            Spacer()

            if github.hasStoredToken {
                VStack(alignment: .leading, spacing: 5) {
                    Text(github.username.isEmpty ? "CONNECTED" : "@\(github.username)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(github.phase == .failed ? DashboardPalette.coral : DashboardPalette.green)
                            .frame(width: 6, height: 6)
                        Text(github.phase == .failed ? "REFRESH NEEDED" : "SNAPSHOT READY")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(DashboardPalette.muted)
                    }
                }
                .padding(14)
            }
        }
        .padding(.vertical, 14)
        .frame(width: 176)
        .background(DashboardPalette.panel.opacity(0.9))
        .overlay(alignment: .trailing) {
            Rectangle().fill(DashboardPalette.line).frame(width: 1)
        }
        .foregroundStyle(DashboardPalette.text)
    }

    private func resolvedStudioTheme(_ family: WidgetLayoutFamily) -> WidgetVisualTheme {
        themeOverrides[family] ?? visualTheme
    }

    private var widgetStudioContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WIDGET STUDIO")
                            .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(1)
                            .foregroundStyle(DashboardPalette.green)
                        Text("A theme for every size")
                            .font(.system(size: 24, weight: .black, design: .rounded)).tracking(-0.6)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("DASHBOARD THEME")
                            .font(.system(size: 8, weight: .black, design: .monospaced)).tracking(0.9)
                            .foregroundStyle(DashboardPalette.muted)
                        Picker("", selection: $visualTheme) {
                            ForEach(WidgetVisualTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu).frame(width: 180)
                    }
                }

                ForEach(WidgetLayoutFamily.allCases) { family in
                    widgetSizeCard(family)
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(DashboardPalette.text)
        .background(DashboardPalette.ink)
    }

    private func widgetSizeCard(_ family: WidgetLayoutFamily) -> some View {
        let theme = resolvedStudioTheme(family)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(family.displayName.uppercased()) WIDGET")
                    .font(.system(size: 11, weight: .black, design: .monospaced)).tracking(0.8)
                Spacer()
                Picker("", selection: themeOverrideBinding(family)) {
                    Text("Default \u{00B7} \(visualTheme.displayName)").tag(WidgetVisualTheme?.none)
                    ForEach(WidgetVisualTheme.allCases) { option in
                        Text(option.displayName).tag(WidgetVisualTheme?.some(option))
                    }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 220)
            }

            if theme == .blockwork {
                DisclosureGroup {
                    blockworkSettings(family).padding(.top, 12)
                } label: {
                    Label("Settings", systemImage: "square.grid.2x2")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .tint(DashboardPalette.green)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    fixedThemePreview(
                        family,
                        width: previewSize(family).width,
                        height: previewSize(family).height,
                        theme: theme
                    )
                }
            }
        }
        .padding(16)
        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DashboardPalette.line, lineWidth: 1)
        }
    }

    private func previewSize(_ family: WidgetLayoutFamily) -> (width: CGFloat, height: CGFloat) {
        switch family {
        case .small: (190, 190)
        case .medium: (380, 190)
        case .large: (320, 320)
        case .extraLarge: (620, 300)
        }
    }

    private func blockworkSettings(_ family: WidgetLayoutFamily) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("BLOCKS")
                    .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                VStack(spacing: 0) {
                    ForEach(WidgetPane.allCases) { pane in
                        blockLibraryRow(pane)
                    }
                }
                .overlay { Rectangle().stroke(studioInk, lineWidth: 2) }
                blockColorEditor
            }
            .frame(width: 300)

            ScrollView(.horizontal, showsIndicators: false) {
                familyComposer(
                    family,
                    width: composerSize(family).width,
                    height: composerSize(family).height
                )
            }
        }
        .padding(16)
        .background(studioPaper)
        .foregroundStyle(studioInk)
    }

    private func composerSize(_ family: WidgetLayoutFamily) -> (width: CGFloat, height: CGFloat) {
        switch family {
        case .small: (180, 180)
        case .medium: (380, 180)
        case .large: (360, 320)
        case .extraLarge: (620, 300)
        }
    }

    private func fixedDefaultPreview(
        _ family: WidgetLayoutFamily,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(family.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.9)
                Spacer()
                Text("FIXED")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(DashboardPalette.green)
            }

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    if family != .small {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(DashboardPalette.green)
                    }
                    Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("DAILY")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .overlay { Capsule().stroke(DashboardPalette.line, lineWidth: 1) }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)

                defaultPreviewBody(family)
                    .padding(family == .small ? 9 : 10)
            }
            .frame(width: width, height: height)
            .background(DashboardPalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 14, y: 9)
        }
    }

    @ViewBuilder
    private func defaultPreviewBody(_ family: WidgetLayoutFamily) -> some View {
        switch family {
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                defaultPreviewMetric("+25,036", color: DashboardPalette.green, size: 25)
                defaultPreviewMetric("−1,031", color: DashboardPalette.coral, size: 21)
                Spacer(minLength: 0)
                defaultPreviewSummary
                defaultPreviewBars(height: 8)
            }
        case .medium:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    defaultPreviewMetric("+25,036", color: DashboardPalette.green, size: 24)
                    defaultPreviewMetric("−1,031", color: DashboardPalette.coral, size: 21)
                    defaultPreviewSummary
                }
                Rectangle().fill(DashboardPalette.line).frame(width: 1)
                VStack(alignment: .leading, spacing: 7) {
                    defaultPreviewRepos(rows: 2)
                    Spacer(minLength: 0)
                    defaultPreviewBars(height: 13)
                }
            }
        case .large:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    defaultPreviewCard("+25,036", color: DashboardPalette.green)
                    defaultPreviewCard("−1,031", color: DashboardPalette.coral)
                }
                defaultPreviewSummary
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVITY").font(.system(size: 7, weight: .bold, design: .rounded))
                        defaultPreviewBars(height: 38)
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DashboardPalette.green.opacity(0.5))
                                    .frame(height: 10)
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))

                    defaultPreviewRepos(rows: 4)
                        .padding(9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                }
            }
        case .extraLarge:
            HStack(spacing: 10) {
                VStack(spacing: 8) {
                    defaultPreviewCard("+25,036", color: DashboardPalette.green)
                    defaultPreviewCard("−1,031", color: DashboardPalette.coral)
                    defaultPreviewSummary
                }
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ACTIVITY").font(.system(size: 7, weight: .bold, design: .rounded))
                        defaultPreviewBars(height: 48)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index < 8 ? DashboardPalette.green : DashboardPalette.lifted)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                }
                defaultPreviewRepos(rows: 6)
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func defaultPreviewMetric(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var defaultPreviewSummary: some View {
        HStack(spacing: 7) {
            Text("29 commits")
            Rectangle().fill(DashboardPalette.line).frame(width: 1, height: 9)
            Text("3 repositories")
            Spacer(minLength: 0)
        }
        .font(.system(size: 7, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardPalette.muted)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 7))
    }

    private func defaultPreviewCard(_ text: String, color: Color) -> some View {
        defaultPreviewMetric(text, color: color, size: 25)
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private func defaultPreviewBars(height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array([0.22, 0.68, 0.34, 0.92, 0.08, 0.56, 0.75].enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DashboardPalette.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, height * value))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
        .clipped()
    }

    private func defaultPreviewRepos(rows: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(0..<rows), id: \.self) { index in
                VStack(spacing: 3) {
                    HStack {
                        Text(["widtget", "studio", "signal", "tools", "notes", "parser"][index % 6])
                        Spacer()
                        Text("+\(index + 1)k")
                            .foregroundStyle(DashboardPalette.green)
                    }
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DashboardPalette.lifted)
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DashboardPalette.green)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: 1 - Double(index) * 0.12, anchor: .leading)
                        }
                }
            }
        }
    }

    // MARK: - Themed fixed-layout previews
    //
    // Host-local mocks so the studio shows each fixed theme differently, the same
    // way Default and Blockwork are mocked here. The real widget views live in the
    // widget target and can't be instantiated from the app, so these mirror their
    // look (palette, type, signature treatment) rather than importing them.

    private struct ThemePreviewStyle {
        let theme: WidgetVisualTheme
        let base: Color
        let text: Color
        let add: Color
        let del: Color
        let muted: Color
        let panel: Color
        let font: Font.Design
        let corner: CGFloat
    }

    private func themePreviewStyle(_ theme: WidgetVisualTheme) -> ThemePreviewStyle {
        switch theme {
        case .glasshouse:
            ThemePreviewStyle(
                theme: .glasshouse,
                base: Color(red: 0.110, green: 0.114, blue: 0.129),
                text: Color(red: 0.949, green: 0.953, blue: 0.961),
                add: Color(red: 0.494, green: 0.886, blue: 0.659),
                del: Color(red: 0.941, green: 0.525, blue: 0.549),
                muted: Color.white.opacity(0.5), panel: Color.white.opacity(0.06),
                font: .default, corner: 20)
        case .phosphor:
            ThemePreviewStyle(
                theme: .phosphor,
                base: Color(red: 0.024, green: 0.035, blue: 0.039),
                text: Color(red: 0.290, green: 0.941, blue: 0.541),
                add: Color(red: 0.290, green: 0.941, blue: 0.541),
                del: Color(red: 1.0, green: 0.702, blue: 0.251),
                muted: Color(red: 0.173, green: 0.561, blue: 0.345), panel: Color.white.opacity(0.04),
                font: .monospaced, corner: 12)
        case .broadsheet:
            ThemePreviewStyle(
                theme: .broadsheet,
                base: Color(red: 0.914, green: 0.894, blue: 0.835),
                text: Color(red: 0.098, green: 0.090, blue: 0.059),
                add: Color(red: 0.098, green: 0.090, blue: 0.059),
                del: Color(red: 0.620, green: 0.184, blue: 0.106),
                muted: Color(red: 0.427, green: 0.396, blue: 0.333),
                panel: Color(red: 0.098, green: 0.090, blue: 0.059).opacity(0.06),
                font: .serif, corner: 4)
        case .arcade:
            ThemePreviewStyle(
                theme: .arcade,
                base: Color(red: 0.059, green: 0.220, blue: 0.059),
                text: Color(red: 0.545, green: 0.675, blue: 0.059),
                add: Color(red: 0.608, green: 0.737, blue: 0.059),
                del: Color(red: 0.851, green: 0.310, blue: 0.118),
                muted: Color(red: 0.188, green: 0.384, blue: 0.188),
                panel: Color(red: 0.114, green: 0.302, blue: 0.114),
                font: .monospaced, corner: 6)
        case .defaultTheme, .blockwork:
            ThemePreviewStyle(
                theme: .defaultTheme, base: DashboardPalette.ink, text: DashboardPalette.text,
                add: DashboardPalette.green, del: DashboardPalette.coral, muted: DashboardPalette.muted,
                panel: DashboardPalette.panel, font: .rounded, corner: 20)
        }
    }

    @ViewBuilder
    private func fixedThemePreview(_ family: WidgetLayoutFamily, width: CGFloat, height: CGFloat, theme: WidgetVisualTheme) -> some View {
        if theme == .defaultTheme {
            fixedDefaultPreview(family, width: width, height: height)
        } else {
            themedPreviewCard(themePreviewStyle(theme), family: family, width: width, height: height)
        }
    }

    private func themedPreviewCard(
        _ style: ThemePreviewStyle,
        family: WidgetLayoutFamily,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(family.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(0.9)
                Spacer()
                Text(style.theme.displayName.uppercased())
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(DashboardPalette.green)
            }

            VStack(spacing: 0) {
                themedPreviewHeader(style)
                    .padding(.horizontal, 11).frame(height: 28)
                themedPreviewBody(style, family: family)
                    .padding(family == .small ? 10 : 11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: width, height: height)
            .background(style.base)
            .clipShape(RoundedRectangle(cornerRadius: style.corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: style.corner, style: .continuous)
                    .stroke(style.text.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 14, y: 9)
        }
    }

    @ViewBuilder
    private func themedPreviewHeader(_ style: ThemePreviewStyle) -> some View {
        let user = github.username.isEmpty ? "yjay18" : github.username
        HStack(spacing: 6) {
            switch style.theme {
            case .phosphor:
                Text("~/\(user)").foregroundStyle(style.text)
            case .broadsheet:
                Text("The commit record").font(.system(size: 10, weight: .semibold, design: .serif))
            case .arcade:
                Text(user.uppercased()).foregroundStyle(style.text)
            default:
                Circle().fill(style.add).frame(width: 10, height: 10)
                Text(user).foregroundStyle(style.text)
            }
            Spacer()
            Text(style.theme == .broadsheet ? "Daily" : (style.theme == .arcade ? "DAILY" : "daily"))
                .foregroundStyle(style.theme == .arcade ? style.add : style.muted)
                .padding(.horizontal, style.theme == .glasshouse ? 6 : 0).padding(.vertical, 3)
                .background {
                    if style.theme == .glasshouse {
                        Capsule().fill(Color.white.opacity(0.12))
                    }
                }
        }
        .font(.system(size: 9, weight: .semibold, design: style.font))
        .foregroundStyle(style.muted)
    }

    @ViewBuilder
    private func themedPreviewBody(_ style: ThemePreviewStyle, family: WidgetLayoutFamily) -> some View {
        let wide = family != .small
        switch style.theme {
        case .phosphor:
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("$ git log --stat").font(.system(size: 8, design: .monospaced)).foregroundStyle(style.muted)
                    Text("+25,036").font(.system(size: wide ? 30 : 24, weight: .bold, design: .monospaced)).foregroundStyle(style.add)
                    Text("−1,031").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(style.del)
                    Text("▃▅▁█▆▄▁").font(.system(size: 16, design: .monospaced)).foregroundStyle(style.add)
                    Spacer(minLength: 0)
                    Text("m t w t f s s · net +24k").font(.system(size: 8, design: .monospaced)).foregroundStyle(style.muted)
                }
                if wide { phosphorRepoColumn(style) }
            }
        case .broadsheet:
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(style.text).frame(height: 1)
                    Text("LINES SET THIS WEEK").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1)
                        .foregroundStyle(style.muted).padding(.top, 8)
                    Text("+25,036").font(.system(size: wide ? 40 : 34, weight: .semibold, design: .serif)).foregroundStyle(style.text)
                    Text("−1,031 STRUCK").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1)
                        .foregroundStyle(style.del).padding(.top, 3)
                    Spacer(minLength: 0)
                    themedBars(style, height: 22, ink: true)
                }
                if wide { broadsheetDayBook(style) }
            }
        case .arcade:
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LINES MADE").font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundStyle(style.muted)
                    Text("+25036").font(.system(size: wide ? 28 : 22, weight: .heavy, design: .monospaced)).foregroundStyle(style.add)
                    Text("-1031").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(style.del)
                    Spacer(minLength: 0)
                    HStack { Text("LV.4"); Spacer(); Text("HI THU") }
                        .font(.system(size: 8, weight: .heavy, design: .monospaced)).foregroundStyle(style.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                arcadePlayfield(style, cols: wide ? 12 : 8, rows: wide ? 5 : 3)
                    .frame(maxWidth: .infinity)
            }
        default: // glasshouse
            let metrics = VStack(alignment: .leading, spacing: 4) {
                Text("lines added").font(.system(size: 9, weight: .medium)).foregroundStyle(style.muted)
                Text("+25,036").font(.system(size: wide ? 36 : 28, weight: .semibold)).foregroundStyle(style.add)
                Text("−1,031 removed").font(.system(size: 11, weight: .medium)).foregroundStyle(style.del)
            }
            let rhythm = VStack(alignment: .leading, spacing: 6) {
                Text("seven day rhythm").font(.system(size: 9, weight: .medium)).foregroundStyle(style.muted)
                Spacer(minLength: 0)
                themedBars(style, height: wide ? 44 : 30, ink: false)
            }
            if wide {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        metrics
                        Spacer(minLength: 0)
                        Text("net +24k · 913 avg").font(.system(size: 9, weight: .medium)).foregroundStyle(style.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    rhythm
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(style.text.opacity(0.12)).frame(width: 1).offset(x: -6)
                        }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    metrics
                    Spacer(minLength: 0)
                    themedBars(style, height: 26, ink: false)
                }
            }
        }
    }

    private func themedBars(_ style: ThemePreviewStyle, height: CGFloat, ink: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array([0.33, 0.55, 0.12, 0.92, 0.70, 0.41, 0.08].enumerated()), id: \.offset) { index, value in
                Rectangle()
                    .fill(index == 3 && ink ? style.del : (value > 0.15 ? style.add : style.muted.opacity(0.5)))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, height * value))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
    }

    private func phosphorRepoColumn(_ style: ThemePreviewStyle) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("4 repositories").font(.system(size: 8, design: .monospaced)).foregroundStyle(style.muted)
            ForEach(Array(["studio", "linguist", "widtget", "notes"].enumerated()), id: \.offset) { index, name in
                HStack(spacing: 5) {
                    Text(name).foregroundStyle(style.text).lineLimit(1)
                    Spacer(minLength: 3)
                    Text(String(repeating: "█", count: 8 - index * 2) + String(repeating: "░", count: index * 2))
                        .foregroundStyle(style.muted)
                    Text("+\(12 - index * 3)k").foregroundStyle(style.add)
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func broadsheetDayBook(_ style: ThemePreviewStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THE DAY BOOK").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1)
                .foregroundStyle(style.muted).padding(.bottom, 6)
            ForEach(Array(["Mon", "Tue", "Wed", "Thu", "Fri"].enumerated()), id: \.offset) { index, day in
                HStack(spacing: 5) {
                    Text(day).font(.system(size: 11, design: .serif))
                    Rectangle().fill(style.muted.opacity(0.4)).frame(height: 1)
                    Text(["3,204", "5,411", "1,102", "9,812", "6,904"][index])
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(index == 3 ? style.del : style.text)
                }
                .padding(.vertical, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(style.muted.opacity(0.4)).frame(width: 1).offset(x: -7) }
    }

    private func arcadePlayfield(_ style: ThemePreviewStyle, cols: Int, rows: Int) -> some View {
        let lit = min(cols * rows - 1, Int(Double(cols * rows) * 0.45))
        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<cols, id: \.self) { col in
                        let i = row * cols + col
                        Rectangle()
                            .fill(i == lit ? style.del : (i < lit ? style.add : style.panel))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func blockLibraryRow(_ block: WidgetPane) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedBlock = block
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(studioMuted)

                Image(systemName: block.studioSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.displayName)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                    Text(block.detail)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(studioMuted)
                        .lineLimit(1)
                }

                Spacer()

                if selectedBlock == block {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(studioOrange)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 46)
            .background(selectedBlock == block ? studioLime.opacity(0.26) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(studioInk.opacity(0.22)).frame(height: 1)
        }
        .onDrag {
            selectedBlock = block
            draggedPane = block
            draggedOrigin = nil
            return NSItemProvider(object: block.rawValue as NSString)
        }
    }

    private var blockColorEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED BLOCK")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(studioMuted)
                    Text(selectedBlock.displayName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                Spacer()
                Image(systemName: selectedBlock.studioSymbol)
                    .font(.system(size: 15, weight: .black))
            }

            HStack(spacing: 8) {
                ForEach(WidgetBlockColor.allCases) { color in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            blockColors[selectedBlock] = color
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(studioSwatch(color))
                                .frame(width: 24, height: 24)
                            if selectedBlockColor == color {
                                Image(systemName: color == .automatic ? "a.circle.fill" : "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(color == .ink ? studioPaper : studioInk)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }

            Text("Auto uses Blockwork's semantic poster color for this block.")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(studioMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(studioInk.opacity(0.055))
        .overlay {
            Rectangle().stroke(studioInk, lineWidth: 2)
        }
    }

    private func familyComposer(
        _ family: WidgetLayoutFamily,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(family.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.9)
                Spacer()
                Text("\(family.slotCount) \(family.slotCount == 1 ? "SLOT" : "SLOTS")")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(studioMuted)
            }

            VStack(spacing: 0) {
                HStack {
                    Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                    Spacer()
                    Text("W")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .foregroundStyle(studioInk)
                        .background(studioLime)
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .foregroundStyle(studioPaper)
                .background(studioInk)

                GeometryReader { proxy in
                    familySlotLayout(family, size: proxy.size)
                        .padding(3)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .background(studioInk)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 9)
        }
    }

    @ViewBuilder
    private func familySlotLayout(_ family: WidgetLayoutFamily, size: CGSize) -> some View {
        let slots = familyLayouts[family]
            ?? WidgetModularPreferences.defaults.familyLayouts[family]
            ?? []
        let spacing: CGFloat = 3

        switch family {
        case .small:
            if let block = slots.first {
                composerSlot(family: family, index: 0, block: block)
            }
        case .medium:
            HStack(spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, block in
                    composerSlot(family: family, index: index, block: block)
                }
            }
        case .large:
            VStack(spacing: spacing) {
                if let first = slots.first {
                    composerSlot(family: family, index: 0, block: first)
                        .frame(height: max(0, (size.height - spacing) * 0.44))
                }
                HStack(spacing: spacing) {
                    ForEach(Array(slots.dropFirst().enumerated()), id: \.offset) { offset, block in
                        composerSlot(family: family, index: offset + 1, block: block)
                    }
                }
            }
        case .extraLarge:
            HStack(spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, block in
                    composerSlot(family: family, index: index, block: block)
                }
            }
        }
    }

    private func composerSlot(
        family: WidgetLayoutFamily,
        index: Int,
        block: WidgetPane
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedBlock = block
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: block.studioSymbol)
                    Spacer()
                    Text("\(index + 1)")
                }
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .opacity(0.68)

                Spacer(minLength: 0)

                Text(block.displayName)
                    .font(.system(size: family == .extraLarge ? 10 : 9, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(blockPreviewValue(block))
                    .font(.system(size: family == .small ? 18 : 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(family == .small ? 9 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(studioBlockForeground(block))
            .background(studioBlockFill(block))
            .overlay {
                Rectangle()
                    .stroke(
                        selectedBlock == block ? studioOrange : Color.clear,
                        lineWidth: 3
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            selectedBlock = block
            draggedPane = block
            draggedOrigin = WidgetSlotOrigin(family: family, index: index)
            return NSItemProvider(object: block.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: WidgetSlotDropDelegate(
                destination: WidgetSlotOrigin(family: family, index: index),
                layouts: $familyLayouts,
                draggedPane: $draggedPane,
                draggedOrigin: $draggedOrigin
            )
        )
    }

    private var selectedBlockColor: WidgetBlockColor {
        blockColors[selectedBlock] ?? .automatic
    }

    private func studioSwatch(_ color: WidgetBlockColor) -> Color {
        switch color {
        case .automatic:
            studioPaper
        case .orange: studioOrange
        case .lime: studioLime
        case .sky: studioSky
        case .ink: studioInk
        case .paper: studioPaper
        }
    }

    private func studioBlockFill(_ block: WidgetPane) -> Color {
        let selected = blockColors[block] ?? .automatic
        if selected != .automatic {
            return studioSwatch(selected)
        }
        switch block {
        case .additions: return studioOrange
        case .deletions, .snake: return studioInk
        case .summary, .insights: return studioLime
        case .activity, .activityTable: return studioSky
        case .repositories: return studioPaper
        }
    }

    private func studioBlockForeground(_ block: WidgetPane) -> Color {
        let selected = blockColors[block] ?? .automatic
        let fillChoice: WidgetBlockColor
        if selected == .automatic {
            fillChoice = block == .deletions || block == .snake ? .ink : .paper
        } else {
            fillChoice = selected
        }
        return fillChoice == .ink ? studioPaper : studioInk
    }

    private func blockPreviewValue(_ block: WidgetPane) -> String {
        switch block {
        case .additions: "+25k"
        case .deletions: "−1k"
        case .summary: "29 / 3"
        case .activity: "▂▇▃▅"
        case .activityTable: "▦ ▦"
        case .insights: "+24k"
        case .repositories: "3 repos"
        case .snake: "snek happy"
        }
    }

    private func paneLibraryRow(_ pane: WidgetPane) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(studioMuted)

            Image(systemName: pane.studioSymbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(pane.displayName)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Text(pane.detail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(studioMuted)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: paneEnabledBinding(pane))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .frame(height: 54)
        .background(enabledPanes.contains(pane) ? studioLime.opacity(0.24) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(studioInk.opacity(0.24)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onDrag {
            draggedPane = pane
            return NSItemProvider(object: pane.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: WidgetPaneDropDelegate(
                destination: pane,
                panes: $paneOrder,
                draggedPane: $draggedPane
            )
        )
    }

    private var studioWidgetPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                Spacer()
                Text("WEEKLY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(studioInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(studioLime)
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(studioLime)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .foregroundStyle(studioPaper)
            .background(studioInk)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 3),
                    GridItem(.flexible(), spacing: 3)
                ],
                spacing: 3
            ) {
                ForEach(paneOrder.filter(enabledPanes.contains)) { pane in
                    studioPanePreview(pane)
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(studioInk)
        }
        .frame(maxWidth: 590, minHeight: 360, maxHeight: 430)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 22, y: 14)
        .hueRotation(studioHueRotation)
        .saturation(blockworkColorway == .mono ? 0 : 1)
        .animation(.snappy(duration: 0.28), value: paneOrder)
        .animation(.snappy(duration: 0.28), value: enabledPanes)
    }

    @ViewBuilder
    private func studioPanePreview(_ pane: WidgetPane) -> some View {
        switch pane {
        case .additions:
            studioPreviewTile(title: "LINES MADE", value: "+25,036", color: studioOrange)
        case .deletions:
            studioPreviewTile(
                title: "LINES REMOVED",
                value: "−1,031",
                color: studioInk,
                foreground: studioPaper,
                valueColor: studioOrange
            )
        case .summary:
            studioPreviewTile(title: "SUMMARY", value: "29 / 3", color: studioLime)
        case .activity:
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVITY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array([0.92, 0.72, 0.23, 0.05, 0.78, 0.69, 0.66].enumerated()), id: \.offset) { _, value in
                        Rectangle()
                            .fill(studioInk)
                            .frame(height: 52 * value)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(studioSky)
        case .activityTable:
            studioPreviewTile(title: "ACTIVITY TABLE", value: "▦ ▦ ▦", color: studioSky)
        case .insights:
            studioPreviewTile(title: "NET / PEAK / AVG", value: "+24k", color: studioLime)
        case .repositories:
            VStack(alignment: .leading, spacing: 8) {
                Text("REPOSITORIES / 03")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                ForEach(["linguist  +19k", "Studio  +5k", "storymode  +659"], id: \.self) { repository in
                    Text(repository)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(studioInk).frame(height: 1)
                        }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(studioPaper)
        case .snake:
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(studioLime)
                VStack(alignment: .leading, spacing: 2) {
                    Text("snek happy")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text("29 COMMITS")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(studioLime)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .foregroundStyle(studioPaper)
            .background(studioInk)
        }
    }

    private func studioPreviewTile(
        title: String,
        value: String,
        color: Color,
        foreground: Color? = nil,
        valueColor: Color? = nil
    ) -> some View {
        let foreground = foreground ?? studioInk
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
            Text(value)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .tracking(-1.4)
                .foregroundStyle(valueColor ?? foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(foreground)
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(color)
    }

    private func paneEnabledBinding(_ pane: WidgetPane) -> Binding<Bool> {
        Binding {
            enabledPanes.contains(pane)
        } set: { isEnabled in
            withAnimation(.snappy(duration: 0.22)) {
                if isEnabled {
                    enabledPanes.insert(pane)
                } else {
                    enabledPanes.remove(pane)
                }
            }
        }
    }

    private var studioInk: Color {
        Color(red: 0.063, green: 0.067, blue: 0.059)
    }

    private var studioPaper: Color {
        Color(red: 0.937, green: 0.898, blue: 0.804)
    }

    private var studioOrange: Color {
        Color(red: 0.953, green: 0.357, blue: 0.173)
    }

    private var studioLime: Color {
        Color(red: 0.725, green: 0.863, blue: 0.235)
    }

    private var studioSky: Color {
        Color(red: 0.412, green: 0.729, blue: 0.859)
    }

    private var studioMuted: Color {
        Color(red: 0.46, green: 0.45, blue: 0.41)
    }

    private var studioHueRotation: Angle {
        blockworkColorway == .cobalt ? .degrees(198) : .zero
    }

    private var connectionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !github.hasStoredToken {
                    githubConnectionSection
                } else {
                    connectionManagementSection
                    if let message = github.message {
                        connectionError(message)
                    }
                    if let notice = github.notice {
                        connectionNotice(notice)
                    }
                }
                refreshIntervalSection
                snekBlockSection
                widgetConfigurationGuide
            }
            .padding(28)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var refreshIntervalSection: some View {
        GroupBox("Widget refresh") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("How often widgets reload", selection: $refreshInterval) {
                    ForEach(WidgetRefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)

                Text("Applies to every widtget widget. Automatic uses a system-tuned default; macOS still meters refreshes against the daily budget, so very short intervals are not guaranteed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: refreshInterval) { _, newValue in
            SharedPreferences.refreshInterval = newValue
            reloadWidgets()
        }
    }

    private var snekBlockSection: some View {
        GroupBox("Commit snek blocks") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Each block counts", selection: $snakeBlockBasis) {
                    ForEach(SnakeBlockBasis.allCases) { basis in
                        Text(basis.displayName).tag(basis)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("\(snakeBlockBasis.unitNoun.capitalized) per block")
                    Spacer()
                    TextField("", value: $snakeUnitsPerBlock, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                Text("The commit snek grows one block per \(snakeUnitsPerBlock) \(snakeBlockBasis.unitNoun), across every theme. Line-based options want a larger number than commits.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: snakeBlockBasis) { _, newValue in
            SharedPreferences.snakeBlockBasis = newValue
            snakeUnitsPerBlock = newValue.defaultPerBlock
            SharedPreferences.snakeUnitsPerBlock = snakeUnitsPerBlock
            reloadWidgets()
        }
        .onChange(of: snakeUnitsPerBlock) { _, newValue in
            SharedPreferences.snakeUnitsPerBlock = max(1, newValue)
            reloadWidgets()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color(red: 0.22, green: 0.80, blue: 0.46))
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(github.hasStoredToken && !github.username.isEmpty ? "@\(github.username)" : "GitHub activity")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if github.hasStoredToken, let lastRefresh = github.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Connect GitHub and configure the widget")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if github.hasStoredToken {
                if github.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(github.phase == .refreshing ? "Refreshing…" : "Refresh") {
                    Task { await github.refresh(scope: .allBranches) }
                }
                .disabled(github.isBusy)
                .help("Discover activity across every accessible branch")

                Button {
                    showingDisconnectConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Disconnect GitHub")
                .disabled(github.isBusy)
            }
        }
    }

    private var githubConnectionSection: some View {
        GroupBox("GitHub activity") {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Fine-grained personal access token", text: $github.tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canConnect else { return }
                        Task { await github.connect() }
                    }

                HStack {
                    Link(
                        "Create a fine-grained token",
                        destination: GitHubTokenTemplate.url()
                    )
                    .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if github.isBusy {
                        ProgressView().controlSize(.small)
                    }

                    Button(github.phase == .connecting ? "Connecting…" : "Connect GitHub") {
                        Task { await github.connect() }
                    }
                    .disabled(!github.canConnect)
                }

                Text("Choose your account as the resource owner, select the repositories to include, and leave the prefilled Contents permission at read-only. Organization connections can be added next.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = github.message {
                    connectionError(message)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var connectionManagementSection: some View {
        GroupBox("GitHub connections") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(github.connections) { connection in
                    connectionRow(connection)
                    if connection.id != github.connections.last?.id {
                        Divider()
                    }
                }

                Divider()

                tokenDisclosure(title: "Replace account token", isExpanded: $isReplacingAccountToken) {
                    VStack(alignment: .leading, spacing: 8) {

                    HStack {
                        Link(
                            "Create replacement token",
                            destination: GitHubTokenTemplate.url()
                        )
                        .font(.system(size: 10, weight: .medium))

                        Spacer()

                        Text("Include your private repositories and Contents: Read-only.")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    SecureField(
                        "Paste replacement account token",
                        text: $github.replacementAccountTokenInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canReplaceAccountToken else { return }
                        Task { await github.replaceAccountToken() }
                    }

                    HStack(alignment: .top) {
                        Text("widtget checks the token belongs to @\(github.username), refreshes every branch, then replaces the saved Keychain token. Your current token stays active if validation fails.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Button(github.phase == .connecting ? "Replacing…" : "Replace token") {
                            Task { await github.replaceAccountToken() }
                        }
                        .disabled(!github.canReplaceAccountToken)
                    }
                    }
                }

                Divider()

                tokenDisclosure(title: "Add organization", isExpanded: $isAddingOrganization) {
                    VStack(alignment: .leading, spacing: 8) {

                    TextField("GitHub organization name", text: $github.organizationInput)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Link(
                            "1. Create read-only token on GitHub",
                            destination: github.organizationTokenURL
                        )
                        .font(.system(size: 10, weight: .medium))
                        .disabled(!github.canCreateOrganizationToken)

                        Spacer()

                        Text("Select the repositories on GitHub, then generate the token.")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    SecureField(
                        "2. Paste the organization token",
                        text: $github.additionalTokenInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canAddToken else { return }
                        Task { await github.addOrganization() }
                    }

                    HStack(alignment: .top) {
                        Text("widtget verifies the organization and repository access before saving. If approval is required, ask an organization owner to approve the token first.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Button(github.phase == .connecting ? "Adding…" : "Add organization") {
                            Task { await github.addOrganization() }
                        }
                        .disabled(!github.canAddToken)
                    }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func connectionRow(_ connection: GitHubConnectionSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: connection.kind == .account ? "person.crop.circle.fill" : "building.2.fill")
                .font(.system(size: 17))
                .foregroundStyle(connection.kind == .account ? Color.secondary : Color.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.kind == .account ? "@\(connection.owner)" : connection.owner)
                    .font(.system(size: 12, weight: .semibold))

                if let repositoryCount = connection.repositoryCount,
                   let privateRepositoryCount = connection.privateRepositoryCount {
                    Text("\(repositoryCount) \(repositoryCount == 1 ? "repository" : "repositories") · \(privateRepositoryCount) private")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text(connection.kind == .account ? "GitHub account" : "Connected resource owner")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if connection.kind == .organization {
                Button {
                    organizationPendingRemoval = connection
                    showingRemoveOrganizationConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove \(connection.owner)")
                .disabled(github.isBusy)
            }
        }
    }

    private func connectionError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectionNotice(_ message: String) -> some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var widgetConfigurationGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DashboardPalette.green)
                    .frame(width: 34, height: 34)
                    .background(DashboardPalette.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Per-widget controls stay with the widget")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Right-click a widtget on the desktop and choose Edit Widget.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Each widget chooses its own period, window, repository detail, and commits per snek block. Widget Studio supplies the shared pane order and colorway.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tokenDisclosure<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded.wrappedValue ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(.tint)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    private var isAnyBlockwork: Bool {
        visualTheme == .blockwork || themeOverrides.values.contains(.blockwork)
    }

    private func themeOverrideBinding(_ family: WidgetLayoutFamily) -> Binding<WidgetVisualTheme?> {
        Binding(
            get: { themeOverrides[family] },
            set: { newValue in
                if let newValue {
                    themeOverrides[family] = newValue
                } else {
                    themeOverrides.removeValue(forKey: family)
                }
                SharedPreferences.setThemeOverride(newValue, for: family)
                reloadWidgets()
            }
        )
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidtgetWidgetKind.value)
    }

    private func migrateToFixedDefaultIfNeeded() {
        let currentVersion = SharedPreferences.defaults.integer(
            forKey: SharedPreferences.Key.themeScopeVersion
        )
        guard currentVersion < 1 else { return }

        visualTheme = .defaultTheme
        SharedPreferences.defaults.set(1, forKey: SharedPreferences.Key.themeScopeVersion)
        saveWidgetStudio()
    }

    private func saveWidgetStudio() {
        SharedPreferences.saveModularPreferences(
            WidgetModularPreferences(
                paneOrder: paneOrder,
                enabledPanes: enabledPanes,
                colorway: blockworkColorway,
                visualTheme: visualTheme,
                familyLayouts: familyLayouts,
                blockColors: blockColors
            )
        )
        reloadWidgets()
    }
}

private struct WidgetSlotOrigin: Equatable {
    let family: WidgetLayoutFamily
    let index: Int
}

private struct WidgetSlotDropDelegate: DropDelegate {
    let destination: WidgetSlotOrigin
    @Binding var layouts: [WidgetLayoutFamily: [WidgetPane]]
    @Binding var draggedPane: WidgetPane?
    @Binding var draggedOrigin: WidgetSlotOrigin?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedPane else { return false }

        var destinationLayout = layouts[destination.family]
            ?? WidgetModularPreferences.defaults.familyLayouts[destination.family]
            ?? []
        guard destinationLayout.indices.contains(destination.index) else { return false }

        let displaced = destinationLayout[destination.index]
        destinationLayout[destination.index] = draggedPane
        layouts[destination.family] = destinationLayout

        if let draggedOrigin,
           draggedOrigin != destination {
            var sourceLayout = layouts[draggedOrigin.family]
                ?? WidgetModularPreferences.defaults.familyLayouts[draggedOrigin.family]
                ?? []
            if sourceLayout.indices.contains(draggedOrigin.index) {
                sourceLayout[draggedOrigin.index] = displaced
                layouts[draggedOrigin.family] = sourceLayout
            }
        }

        self.draggedPane = nil
        self.draggedOrigin = nil
        return true
    }
}

private struct WidgetPaneDropDelegate: DropDelegate {
    let destination: WidgetPane
    @Binding var panes: [WidgetPane]
    @Binding var draggedPane: WidgetPane?

    func dropEntered(info: DropInfo) {
        guard let draggedPane,
              draggedPane != destination,
              let sourceIndex = panes.firstIndex(of: draggedPane),
              let destinationIndex = panes.firstIndex(of: destination)
        else {
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            panes.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPane = nil
        return true
    }
}

private extension WidgetPane {
    var studioSymbol: String {
        switch self {
        case .additions: "plus"
        case .deletions: "minus"
        case .summary: "number"
        case .activity: "chart.bar.fill"
        case .activityTable: "square.grid.3x3.fill"
        case .insights: "scope"
        case .repositories: "shippingbox.fill"
        case .snake: "circle.grid.3x3.fill"
        }
    }
}

#Preview {
    WidgetSettingsView()
}
