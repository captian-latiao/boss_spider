import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appTheme") private var appTheme = "system"
    @State private var pulse = false

    private var successCount: Int {
        appState.metrics?.success ?? 0
    }

    private var deliveryProgress: Double {
        guard let limit = appState.metrics?.deliveryLimit, limit > 0 else {
            return 0
        }
        return min(max(Double(successCount) / Double(limit), 0), 1)
    }

    private var isComplete: Bool {
        guard let metrics = appState.metrics,
              let limit = metrics.deliveryLimit,
              limit > 0 else {
            return false
        }
        return metrics.success >= limit
    }

    private var themeAccentColor: Color {
        AppTheme.accentColor(appTheme: appTheme, colorScheme: colorScheme)
    }

    private var metricAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    var body: some View {
        Form {
            Section("服务") {
                HStack {
                    backendStatus
                    Spacer()
                    backendActionButton
                }

                if appState.isStarting {
                    StartupProgressView()
                }

                if let errorMessage = appState.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.2),
                            value: appState.errorMessage
                        )
                }
            }

            Section(appState.metrics?.date ?? "今日投递") {
                if let metrics = appState.metrics {
                    if isComplete {
                        completionState(metrics)
                    } else {
                        metricsContent(metrics)
                            .animation(metricAnimation, value: metrics.success)
                            .animation(metricAnimation, value: deliveryProgress)
                    }
                } else {
                    emptyState
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    @ViewBuilder
    private var backendActionButton: some View {
        if appState.isStarting || appState.isStopping {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)

                Text(appState.isStarting ? "服务启动中…" : "停止中…")
                    .foregroundStyle(.secondary)
            }
        } else if appState.backendRunning {
            Button("停止后台") {
                Task {
                    await appState.stopBackend()
                }
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        } else {
            Button("启动后台") {
                Task {
                    await appState.startBackend()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeAccentColor)
        }
    }

    private func metricsContent(_ metrics: MetricsResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(metrics.success)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeAccentColor)
                    .contentTransition(.numericText())

                Text("成功")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                MetricValue(
                    title: "总量",
                    value: "\(metrics.total)",
                    tint: .primary
                )

                MetricValue(
                    title: "筛除",
                    value: "\(metrics.warning)",
                    tint: .secondary
                )

                MetricValue(
                    title: "失败",
                    value: "\(metrics.danger)",
                    tint: .red
                )
            }

            if let limit = metrics.deliveryLimit, limit > 0 {
                ShimmerProgressView(
                    progress: deliveryProgress,
                    tint: themeAccentColor,
                    reduceMotion: reduceMotion
                )

                LabeledContent("今日限额") {
                    Text("\(metrics.success) / \(limit)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func completionState(_ metrics: MetricsResponse) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeAccentColor.opacity(0.13))
                    .frame(width: 84, height: 84)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeAccentColor.opacity(0.82),
                                themeAccentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: themeAccentColor.opacity(0.32),
                        radius: 10,
                        y: 4
                    )
            }

            Text("今日投递已达标，祝您面试顺利！")
                .font(.headline)

            Text("成功 \(metrics.success) / \(metrics.deliveryLimit ?? metrics.success)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeAccentColor.opacity(0.13))
                    .frame(width: 76, height: 76)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeAccentColor.opacity(0.82),
                                themeAccentColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: themeAccentColor.opacity(0.3),
                        radius: 10,
                        y: 4
                    )
                    .symbolEffect(
                        .pulse,
                        options: .repeating,
                        isActive: !reduceMotion
                    )
            }

            Text("等待投递数据…")
                .font(.headline)

            Text("Chrome 插件完成投递后，结果会自动出现在这里。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var backendStatus: some View {
        HStack(spacing: 8) {
            ZStack {
                if appState.backendRunning && !reduceMotion {
                    Circle()
                        .stroke(statusColor.opacity(0.45), lineWidth: 2)
                        .frame(width: 9, height: 9)
                        .scaleEffect(pulse ? 2.4 : 1)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
            }

            Text(appState.statusTitle)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            updatePulse()
        }
        .onChange(of: appState.backendRunning) { _, _ in
            updatePulse()
        }
    }

    private var statusColor: Color {
        if appState.isStarting || appState.isStopping {
            return .orange
        }
        return appState.backendRunning ? .green : .secondary
    }

    private func updatePulse() {
        guard appState.backendRunning, !reduceMotion else {
            pulse = false
            return
        }
        pulse = true
    }
}

private struct MetricValue: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShimmerProgressView: View {
    let progress: Double
    let tint: Color
    let reduceMotion: Bool

    @State private var shimmerOffset: CGFloat = -0.8

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(0, min(1, progress)) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(tint)
                    .frame(width: fillWidth)
                    .overlay {
                        if !reduceMotion {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.55),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: fillWidth * 0.7)
                            .offset(x: shimmerOffset * fillWidth)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .linear(duration: 1.8).repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.5
            }
        }
    }
}
