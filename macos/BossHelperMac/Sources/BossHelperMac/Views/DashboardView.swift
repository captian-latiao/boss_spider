import SwiftUI
import AppKit
import Charts

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @State private var pulse = false
    @State private var hoveredPoint: DailySpeedPoint?

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
        GlassEffectContainer {
            VStack(spacing: 16) {
                // 1+2. Unified 4-column grid: service(1) + efficiency(3),
                // then the four metric cards (1 each)
                mainGrid

                // 3. Live Activity Feed
                liveActivitySection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Main Grid (8pt Grid Standardized)
    private var mainGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                serviceStatusCard
                    .gridCellColumns(1)

                deliveryEfficiencyCard
                    .gridCellColumns(3)
            }

            GridRow {
                // Card 1: 成功
                DashboardMetricCard(
                    title: "成功",
                    value: "\(successCount)",
                    icon: "paperplane.fill",
                    accentColor: themeAccentColor,
                    progress: deliveryProgress,
                    showProgress: true,
                    progressCaption: "\(successCount) / \(deliveryLimit)"
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
    }

    // MARK: - Service Status Card
    private var serviceStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Pulsing status indicator
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 28, height: 28)

                    if appState.backendRunning && !reduceMotion {
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .opacity(pulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    }

                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                }
                .onAppear { updatePulse() }
                .onChange(of: appState.backendRunning) { _, _ in updatePulse() }

                Text(appState.statusTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Large Service Toggle Button
            if appState.isStarting || appState.isStopping {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text(appState.isStarting ? "正在启动后台服务…" : "正在停止…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            } else if appState.backendRunning {
                Button {
                    Task { await appState.stopBackend() }
                } label: {
                    Label("停止服务", systemImage: "power")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button {
                    Task { await appState.startBackend() }
                } label: {
                    Label("启动服务", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeAccentColor)
                .controlSize(.large)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(
            MaterialSurface(
                cornerRadius: 12,
                borderColor: .clear,
                borderWidth: 0,
                hasShadow: true
            )
        )
    }

    // MARK: - Delivery Efficiency Card (Native Swift Charts Line Chart)
    private var deliveryEfficiencyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("投递效率")
                    .font(.system(size: 14, weight: .bold))

                Text(speedText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeAccentColor)

                Spacer(minLength: 4)

                Text(speedDetailText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if dailySpeedPoints.isEmpty {
                Text("暂无投递数据")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 90, maxHeight: .infinity, alignment: .center)
            } else {
                Chart(dailySpeedPoints) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("速度", point.speed)
                    )
                    .foregroundStyle(themeAccentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("速度", point.speed)
                    )
                    .foregroundStyle(themeAccentColor)
                    .symbolSize(28)

                    if let hoveredPoint {
                        RuleMark(x: .value("日期", hoveredPoint.date))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .annotation(
                                position: .top,
                                spacing: 4,
                                overflowResolution: .init(x: .disabled, y: .disabled)
                            ) {
                                VStack(spacing: 2) {
                                    Text(hoveredPoint.dateLabel)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)

                                    Text(
                                        "\(String(format: "%.1f", hoveredPoint.speed)) 条/小时 · \(hoveredPoint.total) 条"
                                    )
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(.regularMaterial)
                                )
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYScale(domain: 0...speedUpperBound)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let date: Date = proxy.value(atX: location.x) else {
                                        return
                                    }
                                    hoveredPoint = dailySpeedPoints.min {
                                        abs($0.date.timeIntervalSince(date))
                                            < abs($1.date.timeIntervalSince(date))
                                    }
                                case .ended:
                                    hoveredPoint = nil
                                }
                        }
                    }
                }
                .frame(minHeight: 90, maxHeight: .infinity)
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(
            MaterialSurface(
                cornerRadius: 12,
                borderColor: .clear,
                borderWidth: 0,
                hasShadow: true
            )
        )
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
        .modifier(
            MaterialSurface(
                cornerRadius: 12,
                borderColor: .clear,
                borderWidth: 0,
                hasShadow: true
            )
        )
    }

    // MARK: - Delivery Speed Chart Data
    private var dailySpeedPoints: [DailySpeedPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return appState.dailySpeed.compactMap { item in
            guard let date = formatter.date(from: item.date) else {
                return nil
            }
            return DailySpeedPoint(date: date, speed: item.speedPerHour, total: item.total)
        }
    }

    private var speedUpperBound: Double {
        let maxSpeed = appState.dailySpeed.map(\.speedPerHour).max() ?? 0
        return max(maxSpeed * 1.2, 1)
    }

    private var speedText: String {
        guard let speed = appState.metrics?.speedPerHour else {
            return "--"
        }
        return String(format: "%.1f 条/小时", speed)
    }

    private var speedDetailText: String {
        guard let metrics = appState.metrics else {
            return "暂无活跃数据"
        }
        var parts = ["活跃 \(formatActiveTime(metrics.activeSeconds ?? 0))"]
        if let pauseCount = metrics.pauseCount, pauseCount > 0 {
            parts.append(
                "暂停 \(pauseCount) 次（\(formatActiveTime(metrics.pauseSeconds ?? 0))）"
            )
        }
        return parts.joined(separator: " · ")
    }

    private func formatActiveTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "0 分钟" }
        return formatElapsed(seconds)
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
    var progressCaption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            Group {
                if showProgress, let progress {
                    VStack(alignment: .leading, spacing: 2) {
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
                                    .frame(
                                        width: max(0, min(1, progress)) * geo.size.width,
                                        height: 5
                                    )
                            }
                        }
                        .frame(height: 5)

                        Text("\(progressCaption ?? "—")（\(Int(progress * 100))%）")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Color.clear
                }
            }
            .frame(height: 20, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(
            MaterialSurface(
                cornerRadius: 12,
                borderColor: .clear,
                borderWidth: 0,
                hasShadow: true
            )
        )
    }
}

private struct DailySpeedPoint: Identifiable {
    let date: Date
    let speed: Double
    let total: Int
    var id: Date { date }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
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
