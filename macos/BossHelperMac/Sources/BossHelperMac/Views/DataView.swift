import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DataView: View {
    @EnvironmentObject private var appState: AppState

    private var databaseDirectory: URL {
        appState.processManager.dataDirectory
    }

    private var csvDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/BossHelperData")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("本地数据")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("CSV 导出目录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(csvDirectory.path)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("数据库目录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(databaseDirectory.path)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }

            HStack {
                Button("打开 CSV 文件夹") {
                    NSWorkspace.shared.open(csvDirectory)
                }

                Button("打开数据库文件夹") {
                    NSWorkspace.shared.open(databaseDirectory)
                }

                Button("导入历史数据") {
                    chooseFilesToImport()
                }
            }

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            Task { await appState.importPaths(paths) }
        }
    }
}
