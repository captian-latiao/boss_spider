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
        Form {
            Section("CSV 导出目录") {
                LabeledContent("路径") {
                    Text(csvDirectory.path)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("在访达中打开") {
                    NSWorkspace.shared.open(csvDirectory)
                }
            }

            Section("数据库目录") {
                LabeledContent("路径") {
                    Text(databaseDirectory.path)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("在访达中打开") {
                    NSWorkspace.shared.open(databaseDirectory)
                }
            }

            Section("操作") {
                Button("导入历史数据") {
                    chooseFilesToImport()
                }
            }

            if let errorMessage = appState.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
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
