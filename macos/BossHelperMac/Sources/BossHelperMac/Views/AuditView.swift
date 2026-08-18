import AppKit
import SwiftUI

private enum LogFilter: String, CaseIterable, Identifiable {
    case all
    case delivery
    case polling
    case system
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .delivery: return "投递"
        case .polling: return "轮询"
        case .system: return "系统"
        case .error: return "错误"
        }
    }
}

struct AuditView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"

    @State private var filter: LogFilter = .all
    @State private var searchKeyword = ""
    @State private var isRawTextView = false

    private var themeAccentColor: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private var filteredEntries: [BackendLogEntry] {
        let entries = appState.processManager.logEntries
        let categoryFiltered: [BackendLogEntry]
        if filter == .all {
            categoryFiltered = entries
        } else {
            categoryFiltered = entries.filter { $0.category.rawValue == filter.rawValue }
        }

        if searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter {
            $0.text.localizedCaseInsensitiveContains(searchKeyword)
        }
    }

    private var filteredRawText: String {
        filteredEntries.map { entry in
            "[\(formattedTime(entry.timestamp))] [\(entry.category.title)] \(entry.text)"
        }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Controls (8pt Standardized)
            HStack(spacing: 12) {
                // Category Filter
                Picker("日志分类", selection: $filter) {
                    ForEach(LogFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.regular)

                // Search in logs
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("搜索日志内容…", text: $searchKeyword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchKeyword.isEmpty {
                        Button {
                            searchKeyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.cardBackground(colorScheme: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(AppTheme.cardBorder(colorScheme: colorScheme), lineWidth: 0.8)
                        )
                )

                Spacer()

                // Toggle Raw Text / Card list
                Button {
                    isRawTextView.toggle()
                } label: {
                    Label(isRawTextView ? "卡片视图" : "终端视图", systemImage: isRawTextView ? "rectangle.grid.1x2" : "terminal")
                }
                .controlSize(.small)

                // Copy all
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(filteredRawText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("复制当前筛选的全部日志")
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Main log stream (8pt Standardized)
            if filteredEntries.isEmpty {
                emptyLogsView
            } else if isRawTextView {
                SelectableTextView(text: filteredRawText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(16)
            } else {
                structuredLogList
            }

            Divider()

            // Footer Diagnostics Bar (8pt Standardized)
            diagnosticsFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Structured Log List (8pt Standardized)
    private var structuredLogList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(filteredEntries) { entry in
                    StructuredLogRow(entry: entry, themeAccent: themeAccentColor)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State
    private var emptyLogsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 38))
                .foregroundStyle(.secondary.opacity(0.6))

            Text("暂无符合条件的运行日志")
                .font(.system(size: 14, weight: .semibold))

            Text("本地后端启动或处理投递事件时，实时诊断日志将在此处记录。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Diagnostics Footer (8pt Standardized)
    private var diagnosticsFooter: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.backendRunning ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)

                Text(appState.backendRunning ? "已连接后台服务" : "后台未运行")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("当前展示 \(filteredEntries.count) 条日志")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            if let err = appState.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct StructuredLogRow: View {
    let entry: BackendLogEntry
    let themeAccent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Time stamp
            Text(formattedTime(entry.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 58, alignment: .leading)
                .padding(.top, 2)

            // Category badge
            HStack(spacing: 4) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 9))

                Text(entry.category.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryBadgeColor.opacity(0.12))
            .foregroundStyle(categoryBadgeColor)
            .clipShape(Capsule())
            .padding(.top, 1)

            // Log content
            Text(entry.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString("[\(formattedTime(entry.timestamp))] [\(entry.category.title)] \(entry.text)", forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
    }

    private var categoryBadgeColor: Color {
        switch entry.category {
        case .delivery: return .green
        case .polling: return .blue
        case .system: return .purple
        case .error: return .red
        }
    }

    private var textColor: Color {
        if entry.category == .error {
            return .red
        }
        return .primary
    }

    private var rowBackground: Color {
        if entry.category == .error {
            return Color.red.opacity(0.06)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.03)
            : Color.black.opacity(0.02)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
