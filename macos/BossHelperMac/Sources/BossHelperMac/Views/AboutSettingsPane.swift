import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @EnvironmentObject private var appState: AppState

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    Group {
                        if let icon = NSApp.applicationIconImage {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                        } else {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 48))
                                .frame(width: 72, height: 72)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("BossHelper")
                            .font(.largeTitle.bold())

                        Text(versionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Boss 直聘数据接收与监控的本地辅助工具。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("诊断信息") {
                LabeledContent("后端地址") {
                    Text(appState.listenAddress)
                        .font(.body.monospaced())
                }

                LabeledContent("版本") {
                    Text(appState.health?.version ?? "--")
                        .font(.body.monospaced())
                }

                LabeledContent("PID") {
                    Text("\(appState.health?.pid ?? 0)")
                        .font(.body.monospaced())
                }

                LabeledContent("数据目录") {
                    Text(appState.processManager.dataDirectory.path)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
