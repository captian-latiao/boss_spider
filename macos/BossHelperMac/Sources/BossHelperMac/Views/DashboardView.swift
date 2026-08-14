import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

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
        Form {
            Section("服务") {
                HStack {
                    backendStatus
                    Spacer()

                    if appState.isStarting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("服务启动中…")
                                .foregroundStyle(.secondary)
                        }
                    } else if appState.isStopping {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("停止中…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(appState.backendRunning ? "停止后台" : "启动后台") {
                            Task {
                                if appState.backendRunning {
                                    await appState.stopBackend()
                                } else {
                                    await appState.startBackend()
                                }
                            }
                        }
                    }
                }

                if appState.isStarting {
                    StartupProgressView()
                }

                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section(appState.metrics?.date ?? "今日投递") {
                if let metrics = appState.metrics {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(metrics.success)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("成功")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text("总量 \(metrics.total) · 失败 \(metrics.danger) · 筛除 \(metrics.warning)")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let limit = metrics.deliveryLimit, limit > 0 {
                        ProgressView(value: deliveryProgress)

                        LabeledContent("今日限额") {
                            Text("\(metrics.success) / \(limit)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("等待投递数据…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private var backendStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            Text(appState.statusTitle)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        if appState.isStarting || appState.isStopping {
            return .orange
        }
        return appState.backendRunning ? .green : .secondary
    }
}
