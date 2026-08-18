import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum JobStatusFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case success = "success"
    case filter = "warning"
    case danger = "danger"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .success: return "已投递"
        case .filter: return "已过滤"
        case .danger: return "异常"
        }
    }
}

struct JobsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"

    @State private var statusFilter: JobStatusFilter = .all
    @State private var selectedJob: JobItem?
    @State private var isInspectorPresented = false

    private var themeAccentColor: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private var databaseDirectory: URL {
        appState.processManager.dataDirectory
    }

    private var csvDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/BossHelperData")
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Status Tabs
                TabView(selection: $statusFilter) {
                    ForEach(JobStatusFilter.allCases) { filter in
                        jobsContent
                            .tabItem { Text(filter.title) }
                            .tag(filter)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Data Toolstrip
                bottomDataToolbar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Apple Native macOS Inspector Drawer
        .inspector(isPresented: $isInspectorPresented) {
            if let job = selectedJob {
                JobInspectorView(job: job, themeAccent: themeAccentColor) {
                    isInspectorPresented = false
                }
                .inspectorColumnWidth(min: 340, ideal: 400, max: 540)
            } else {
                ContentUnavailableView("未选定职位", systemImage: "briefcase", description: Text("请在左侧列表中点击任一职位查看 JD 详情。"))
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 540)
            }
        }
        .task {
            await appState.fetchJobs(status: statusFilter.rawValue)
        }
        .onChange(of: statusFilter) { _, newValue in
            Task {
                await appState.fetchJobs(status: newValue.rawValue)
            }
        }
    }

    // MARK: - Jobs Content
    private var jobsContent: some View {
        Group {
            if appState.isJobsLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView("正在加载职位资产…")
                    Spacer()
                }
            } else if appState.jobs.isEmpty {
                emptyJobsView
            } else {
                jobsList
            }
        }
    }

    // MARK: - Jobs List
    private var jobsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(appState.jobs) { job in
                    JobCardRow(
                        job: job,
                        isSelected: selectedJob?.id == job.id && isInspectorPresented,
                        themeAccent: themeAccentColor
                    ) {
                        guard job.isFilter else { return }
                        selectedJob = job
                        isInspectorPresented = true
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State
    private var emptyJobsView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "briefcase")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.6))

            Text(statusFilter == .filter ? "暂未查询到已过滤的职位" : "暂未查询到职位数据")
                .font(.title3.bold())

            Text("插件在 BOSS 直聘工作时抓取或过滤的职位会自动入库。您也可以点击下方“导入历史数据”同步已有记录。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("重新检索") {
                Task {
                    await appState.fetchJobs(status: statusFilter.rawValue)
                }
            }
            .controlSize(.regular)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Data Toolbar
    private var bottomDataToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Text("\(appState.jobs.count) 条展示")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                Task {
                    await appState.fetchJobs(status: statusFilter.rawValue)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新职位列表")
            .controlSize(.regular)

            Button {
                NSWorkspace.shared.open(csvDirectory)
            } label: {
                Label("CSV 目录", systemImage: "folder")
                    .lineLimit(1)
            }
            .controlSize(.regular)

            Button {
                NSWorkspace.shared.open(databaseDirectory)
            } label: {
                Label("数据库", systemImage: "cylinder.split.1x2")
                    .lineLimit(1)
            }
            .controlSize(.regular)

            Button {
                chooseFilesToImport()
            } label: {
                Label("导入历史", systemImage: "square.and.arrow.down")
                    .lineLimit(1)
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .tint(themeAccentColor)
        }
    }

    private func chooseFilesToImport() {
        let panel = NSOpenPanel()
        panel.title = "选择要导入的 CSV 或 data.js"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .commaSeparatedText,
            .javaScript,
            .folder
        ]

        if panel.runModal() == .OK {
            let paths = panel.urls.map(\.path)
            Task {
                await appState.importPaths(paths)
                await appState.fetchJobs(status: statusFilter.rawValue)
            }
        }
    }
}

// MARK: - Job Card Row
private struct JobCardRow: View {
    let job: JobItem
    let isSelected: Bool
    let themeAccent: Color
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(AppTheme.statusColor(for: job.deliverStatus ?? ""))
                    .frame(width: 9, height: 9)

                // Main Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(job.jobName?.isEmpty == false ? job.jobName! : "未命名职位")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let salary = job.salaryRange, !salary.isEmpty {
                            Text(salary)
                                .font(.callout.bold())
                                .foregroundStyle(themeAccent)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }

                        Spacer(minLength: 4)

                        Text(job.displayStatus)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(AppTheme.statusColor(for: job.deliverStatus ?? "").opacity(0.14))
                            .foregroundStyle(AppTheme.statusColor(for: job.deliverStatus ?? ""))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .layoutPriority(1)
                    }

                    HStack(spacing: 8) {
                        if let company = job.jobCompany, !company.isEmpty {
                            Text(company)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let area = job.jobArea, !area.isEmpty {
                            Text("· \(area)")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        if let exp = job.jobExperience, !exp.isEmpty {
                            Text("· \(exp)")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        // Filter keyword badge on card if matched
                        if let kw = job.matchedKeyword {
                            Text("命中 [\(kw)]")
                                .font(.caption.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18))
                                .foregroundStyle(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else if let boss = job.bossName, !boss.isEmpty {
                            Text("\(boss) \(job.bossTitle ?? "")")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .modifier(
                MaterialSurface(
                    cornerRadius: 8,
                    borderColor: isSelected ? themeAccent : AppTheme.cardBorder(colorScheme: colorScheme),
                    borderWidth: isSelected ? 1.5 : 0.8,
                    tint: isSelected ? themeAccent.opacity(0.09) : .clear
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pure JD Inspector View (Safe Area Adjusted, Zero Toolbar Mask Cut)
private struct JobInspectorView: View {
    let job: JobItem
    let themeAccent: Color
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Top Clearance for macOS Titlebar Safe Area
            HStack(alignment: .center, spacing: 8) {
                Text("岗位描述 (JD)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭详情")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16) // Clear the toolbar shadow mask
            .padding(.bottom, 12)

            // Pure JD Body
            if let desc = job.postDescription, !desc.isEmpty {
                ScrollView {
                    Text(highlightedJD(text: desc, keyword: job.matchedKeyword))
                        .font(.system(size: AppFontSize.body))
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "暂无岗位 JD 详情",
                    systemImage: "doc.text",
                    description: Text("该职位未包含详细的职位描述文本。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - JD Keyword Highlighting Engine
    private func highlightedJD(text: String, keyword: String?) -> AttributedString {
        var attr = AttributedString(text)
        guard let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty else {
            return attr
        }

        var searchRange = attr.startIndex..<attr.endIndex
        while let range = attr[searchRange].range(of: keyword, options: .caseInsensitive) {
            attr[range].backgroundColor = Color.orange.opacity(0.35)
            attr[range].foregroundColor = Color.red
            attr[range].font = .system(size: AppFontSize.body, weight: .bold)
            if range.upperBound >= attr.endIndex { break }
            searchRange = range.upperBound..<attr.endIndex
        }
        return attr
    }
}
