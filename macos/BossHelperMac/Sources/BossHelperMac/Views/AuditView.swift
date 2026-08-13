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
    @State private var filter: LogFilter = .all

    private var filteredEntries: [BackendLogEntry] {
        let entries = appState.processManager.logEntries
        guard filter != .all else { return entries }
        return entries.filter { $0.category.rawValue == filter.rawValue }
    }

    private var filteredText: String {
        filteredEntries.map { entry in
            "[\(formattedTime(entry.timestamp))] [\(entry.category.title)] \(entry.text)"
        }.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("审计")
                        .font(.largeTitle.bold())
                    Text("查看后台接收与运行日志")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            BackendInfoSection()

            HStack {
                infoItem("数据目录", appState.processManager.dataDirectory.path)
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("日志分类")
                    .font(.headline)
                Picker("日志分类", selection: $filter) {
                    ForEach(LogFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            SelectableTextView(text: filteredText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
        }
        .padding(24)
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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
