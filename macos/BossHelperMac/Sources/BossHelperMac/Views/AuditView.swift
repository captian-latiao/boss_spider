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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("日志分类", selection: $filter) {
                    ForEach(LogFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 360)

                Spacer()
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if filteredEntries.isEmpty {
                Spacer()
                Text("暂无日志")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                SelectableTextView(text: filteredText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20))
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
