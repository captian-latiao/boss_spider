import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    private var successCount: Int {
        appState.metrics?.success ?? 0
    }

    private var deliveryProgress: Double {
        guard let limit = appState.metrics?.deliveryLimit, limit > 0 else {
            return 0
        }
        return min(max(Double(successCount) / Double(limit), 0), 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日投递")
                            .font(.largeTitle.bold())
                        Text(appState.metrics?.date ?? "--")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    backendStatus

                    if appState.isStarting {
                        Button {
                        } label: {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("服务启动中…")
                            }
                        }
                        .disabled(true)
                    } else if appState.isStopping {
                        Button {
                        } label: {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("停止中…")
                            }
                        }
                        .disabled(true)
                    } else if appState.backendRunning {
                        Button("停止后台") {
                            Task { await appState.stopBackend() }
                        }
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button("启动后台") {
                            Task { await appState.startBackend() }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }

                BackendInfoSection()

                if appState.isStarting {
                    StartupProgressView()
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }

                Text("后台用于接收浏览器插件投递的数据；停止后数据不会被记录。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 16) {
                    MetricCard(
                        title: "总量",
                        value: String(appState.metrics?.total ?? 0)
                    )
                    MetricCard(
                        title: "成功",
                        value: String(appState.metrics?.success ?? 0)
                    )
                    MetricCard(
                        title: "失败/异常",
                        value: String(appState.metrics?.danger ?? 0)
                    )
                    MetricCard(
                        title: "投递消耗时间",
                        value: formattedElapsed(
                            appState.metrics?.elapsedSeconds ?? 0
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: deliveryProgress)

                    HStack {
                        Text("投递进度")
                        Spacer()
                        Text(progressText)
                            .foregroundStyle(.secondary)
                    }
                }

                if !appState.isStarting,
                   !appState.isStopping,
                   let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("运行进展")
                        .font(.headline)

                    Divider()

                    ForEach(Array(appState.processManager.progressEntries.suffix(8))) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(formattedTime(entry.timestamp))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            Text(entry.category.title)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(categoryColor(entry.category).opacity(0.14))
                                )
                                .foregroundStyle(categoryColor(entry.category))

                            Text(entry.text)
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .padding(24)
        }
    }

    private var backendStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    appState.isStarting || appState.isStopping
                        ? Color.orange
                        : (appState.backendRunning ? Color.green : Color.secondary)
                )
                .frame(width: 9, height: 9)
            Text(appState.statusTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var progressText: String {
        if let limit = appState.metrics?.deliveryLimit {
            return "\(successCount) / \(limit)"
        }
        return "\(successCount) / -"
    }

    private func categoryColor(_ category: BackendLogCategory) -> Color {
        switch category {
        case .delivery: return .blue
        case .polling: return .secondary
        case .system: return .gray
        case .error: return .red
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
