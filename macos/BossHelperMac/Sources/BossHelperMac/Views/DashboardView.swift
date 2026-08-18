import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @State private var pulse = false

    private var themeAccentColor: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private var successCount: Int {
        appState.metrics?.success ?? 0
    }

    private var deliveryLimit: Int {
        appState.metrics?.deliveryLimit ?? 120
    }

    private var deliveryProgress: Double {
        guard deliveryLimit > 0 else { return 0 }
        return min(max(Double(successCount) / Double(deliveryLimit), 0), 1)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 1. Top Hero Service Control Banner
            heroControlBanner

            // 2. Metrics Grid (4 Equal Minimal Cards)
            metricsGrid

            // 3. Live Activity Feed (Fixed Height with Independent Scroll, No Scrollbar, Insertion Animation)
            liveActivitySection
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Hero Control Banner (8pt Grid Standardized)
    private var heroControlBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            // Pulsing status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                if appState.backendRunning && !reduceMotion {
                    Circle()
                        .stroke(statusColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)
            }
            .onAppear { updatePulse() }
            .onChange(of: appState.backendRunning) { _, _ in updatePulse() }

            // Status Title
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.statusTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Large Service Toggle Button
            if appState.isStarting || appState.isStopping {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text(appState.isStarting ? "正在启动后台服务…" : "正在停止…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else if appState.backendRunning {
                Button {
                    Task { await appState.stopBackend() }
                } label: {
                    Label("停止服务", systemImage: "power")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button {
                    Task { await appState.startBackend() }
                } label: {
                    Label("启动服务", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeAccentColor)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground(colorScheme: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardBorder(colorScheme: colorScheme), lineWidth: 1)
                )
        )
    }

    // MARK: - Metrics Grid (8pt Grid Standardized)
    private var metricsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
            spacing: 16
        ) {
            // Card 1: 成功
            DashboardMetricCard(
                title: "成功",
                value: "\(successCount)",
                icon: "paperplane.fill",
                accentColor: themeAccentColor,
                progress: deliveryProgress,
                showProgress: true
            )

            // Card 2: 拦截
            DashboardMetricCard(
                title: "拦截",
                value: "\(appState.metrics?.warning ?? 0)",
                icon: "shield.lefthalf.filled",
                accentColor: .orange,
                progress: nil,
                showProgress: false
            )

            // Card 3: 异常
            DashboardMetricCard(
                title: "异常",
                value: "\(appState.metrics?.danger ?? 0)",
                icon: "exclamationmark.triangle.fill",
                accentColor: (appState.metrics?.danger ?? 0) == 0 ? .secondary : .red,
                progress: nil,
                showProgress: false
            )

            // Card 4: 耗时
            DashboardMetricCard(
                title: "耗时",
                value: formatElapsed(appState.metrics?.elapsedSeconds ?? 0),
                icon: "clock.fill",
                accentColor: .blue,
                progress: nil,
                showProgress: false
            )
        }
    }

    // MARK: - Live Activity Feed (Hidden Scrollbar + Spring Animation)
    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeAccentColor)

                    Text("实时动态")
                        .font(.system(size: 14, weight: .bold))

                    Text("\(appState.recentEvents.count)")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(themeAccentColor.opacity(0.15))
                        .foregroundStyle(themeAccentColor)
                        .clipShape(Capsule())
                }

                Spacer()

                Text("实时自动同步")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if appState.recentEvents.isEmpty {
                emptyFeedCard
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.recentEvents) { event in
                            LiveEventRow(event: event, themeAccent: themeAccentColor)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.vertical, 2)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78),
                        value: appState.recentEvents.count
                    )
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .frame(minHeight: 280, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground(colorScheme: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardBorder(colorScheme: colorScheme), lineWidth: 1)
                )
        )
    }

    private var emptyFeedCard: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle()
                    .fill(themeAccentColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(themeAccentColor)
            }

            Text("等待投递数据注入…")
                .font(.system(size: 13, weight: .semibold))

            Text("在 Chrome 浏览器中打开 BOSS 直聘并启用插件，实时投递与过滤详情将即刻在此展现。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func formatElapsed(_ seconds: Int) -> String {
        if seconds <= 0 { return "--" }
        let mins = seconds / 60
        if mins < 60 {
            return "\(mins) 分钟"
        }
        let hours = mins / 60
        let remainMins = mins % 60
        return "\(hours)h \(remainMins)m"
    }
}

// MARK: - Subcomponents (8pt Standardized)

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: Color
    let progress: Double?
    let showProgress: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            if showProgress, let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.8), accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(1, progress)) * geo.size.width, height: 5)
                    }
                }
                .frame(height: 5)
            } else {
                Spacer()
                    .frame(height: 5)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cardBackground(colorScheme: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardBorder(colorScheme: colorScheme), lineWidth: 0.8)
                )
        )
    }
}

private struct LiveEventRow: View {
    let event: DeliveryEventItem
    let themeAccent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon badge
            statusBadge

            // Job Title & Company
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(event.jobName?.isEmpty == false ? event.jobName! : "职位投递事件")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let salary = event.salaryRange, !salary.isEmpty {
                        Text(salary)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(themeAccent)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }

                    if let area = event.jobArea, !area.isEmpty {
                        Text(area)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    if let company = event.jobCompany, !company.isEmpty {
                        Text(company)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let boss = event.bossName, !boss.isEmpty {
                        Text("· \(boss) \(event.bossTitle ?? "")")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            // Filter reason / result detail
            VStack(alignment: .trailing, spacing: 2.5) {
                if event.isSuccess {
                    Text("打招呼已发送")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                } else if event.isFilter {
                    Text(event.filterReason?.isEmpty == false ? event.filterReason! : "已智能过滤")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(event.filterReason?.isEmpty == false ? event.filterReason! : "投递失败")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                Text(event.formattedTime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
    }

    private var statusBadge: some View {
        Group {
            if event.isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if event.isFilter {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 15))
    }

    private var rowBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.035)
            : Color.black.opacity(0.025)
    }
}
