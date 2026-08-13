import SwiftUI
import WidgetKit

struct WidgetSettingsView: View {
    @AppStorage(SharedPreferences.Key.showRepositories, store: SharedPreferences.defaults)
    private var showRepositories = WidgetViewPreferences.defaults.showRepositories

    @AppStorage(SharedPreferences.Key.showActivity, store: SharedPreferences.defaults)
    private var showActivity = WidgetViewPreferences.defaults.showActivity

    @AppStorage(SharedPreferences.Key.showUpdateTime, store: SharedPreferences.defaults)
    private var showUpdateTime = WidgetViewPreferences.defaults.showUpdateTime

    @AppStorage(SharedPreferences.Key.repositoryDetail, store: SharedPreferences.defaults)
    private var repositoryDetail = WidgetViewPreferences.defaults.repositoryDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            GroupBox {
                VStack(spacing: 0) {
                    preferenceToggle(
                        title: "Repository breakdown",
                        detail: "Show ranked repositories and line-change bars.",
                        isOn: $showRepositories
                    )

                    Divider().padding(.leading, 38)

                    preferenceToggle(
                        title: "Activity visualization",
                        detail: "Show the two-color activity strip or grid.",
                        isOn: $showActivity
                    )

                    Divider().padding(.leading, 38)

                    preferenceToggle(
                        title: "Last update time",
                        detail: "Show fresh, stale, and error status text.",
                        isOn: $showUpdateTime
                    )
                }
            }

            HStack {
                Text("Repository detail")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Picker("Repository detail", selection: $repositoryDetail) {
                    ForEach(RepositoryDetail.allCases) { detail in
                        Text(detail.displayName).tag(detail)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .disabled(!showRepositories)

            HStack {
                Button("Reset appearance") {
                    showRepositories = WidgetViewPreferences.defaults.showRepositories
                    showActivity = WidgetViewPreferences.defaults.showActivity
                    showUpdateTime = WidgetViewPreferences.defaults.showUpdateTime
                    repositoryDetail = WidgetViewPreferences.defaults.repositoryDetail
                    reloadWidgets()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Label("Changes update automatically", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onChange(of: showRepositories) { _, _ in reloadWidgets() }
        .onChange(of: showActivity) { _, _ in reloadWidgets() }
        .onChange(of: showUpdateTime) { _, _ in reloadWidgets() }
        .onChange(of: repositoryDetail) { _, _ in reloadWidgets() }
        .onAppear { reloadWidgets() }
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
                Text("widtget")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Widget appearance")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func preferenceToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 10)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidtgetWidgetKind.value)
    }
}

#Preview {
    WidgetSettingsView()
}
