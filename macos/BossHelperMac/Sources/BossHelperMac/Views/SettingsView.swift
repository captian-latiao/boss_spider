import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("autoStartBackend") private var autoStartBackend = true
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        Form {
            Section("外观") {
                Picker("外观", selection: $appTheme) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("后台服务") {
                Toggle(isOn: $autoStartBackend) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启动时自动启动后台服务")
                        Text("打开应用时自动运行本地数据服务，接收浏览器插件投递的数据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Section {
                DisclosureGroup("关于") {
                    AboutDetailsView()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

private struct AboutDetailsView: View {
    @EnvironmentObject private var appState: AppState

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("BossHelper")
                        .font(.headline)
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Boss 直聘数据接收与监控的本地辅助工具。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

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
        .padding(.vertical, 4)
    }
}
