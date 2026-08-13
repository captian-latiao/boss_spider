import SwiftUI

struct BackendInfoSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 24) {
            infoItem("状态", appState.statusTitle)
            infoItem("PID", "\(appState.health?.pid ?? 0)")
            infoItem("版本", appState.health?.version ?? "--")
            infoItem("地址", appState.listenAddress)
        }
    }

    private func infoItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
