import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("autoStartBackend") private var autoStartBackend = true
    @AppStorage("appTheme") private var appTheme = "system"
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @AppStorage("dailyLimit") private var dailyLimit = 120

    @State private var tempLimit: Double = 120
    @State private var hasSavedLimit = false

    var body: some View {
        Form {
            // Section 1: Delivery Strategy
            Section("投递策略与安全") {
                LabeledContent("每日投递上限") {
                    HStack(spacing: 12) {
                        Slider(value: $tempLimit, in: 20...300, step: 10)
                            .frame(width: 160)

                        Text("\(Int(tempLimit)) 次")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)

                        Button("保存上限") {
                            dailyLimit = Int(tempLimit)
                            Task {
                                await appState.setDeliveryLimit(dailyLimit)
                                hasSavedLimit = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    hasSavedLimit = false
                                }
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentColor(accent: accentColorKey))
                    }
                }

                if hasSavedLimit {
                    Text("✓ 已同步至后端配置")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("到达设定上限后，插件将自动停止发起打招呼，有效防止账号触发平台风控机制。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Section 2: Background Service
            Section("本地后台服务") {
                Toggle(isOn: $autoStartBackend) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("打开应用时自动启动后台服务")
                        Text("在后台持续运行本地 SQLite 数据库与数据接收服务，保障浏览器插件实时同步。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                LabeledContent("监听地址") {
                    Text(appState.listenAddress)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }

            // Section 3: Appearance & Accent Theme
            Section("外观与个性化") {
                Picker("外观模式", selection: $appTheme) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)

                Picker("主题强调色", selection: $accentColorKey) {
                    ForEach(AccentColorOption.allCases) { option in
                        HStack {
                            Circle()
                                .fill(option.lightColor)
                                .frame(width: 8, height: 8)
                            Text(option.title)
                        }
                        .tag(option.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            // Section 4: Data Management
            Section("数据存储") {
                LabeledContent("数据库目录") {
                    HStack(spacing: 8) {
                        Text(appState.processManager.dataDirectory.path)
                            .font(.body.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        Button("打开") {
                            NSWorkspace.shared.open(appState.processManager.dataDirectory)
                        }
                        .controlSize(.small)
                    }
                }

                LabeledContent("CSV 导出目录") {
                    HStack(spacing: 8) {
                        let csvDir = URL(fileURLWithPath: NSHomeDirectory())
                            .appendingPathComponent("Documents/BossHelperData")

                        Text(csvDir.path)
                            .font(.body.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        Button("打开") {
                            NSWorkspace.shared.open(csvDir)
                        }
                        .controlSize(.small)
                    }
                }
            }

            // Section 5: About Herooo
            Section {
                AboutHeroooPane()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 16, for: .scrollContent)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .onAppear {
            tempLimit = Double(appState.metrics?.deliveryLimit ?? dailyLimit)
        }
    }
}

private struct AboutHeroooPane: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @Environment(\.colorScheme) private var colorScheme

    private var themeAccent: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(version) (Build \(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [themeAccent, themeAccent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: themeAccent.opacity(0.3), radius: 6, y: 3)

                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Herooo for Mac")
                        .font(.system(size: 15, weight: .bold))

                    Text(versionText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Herooo 智能求职副驾 — 专为高效、精准、安全的求职体验打造的 Mac 本地控制中心与数据大脑。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("后端版本") {
                Text(appState.health?.version ?? "0.1.0")
                    .font(.body.monospaced())
            }

            LabeledContent("运行 PID") {
                Text("\(appState.health?.pid ?? 0)")
                    .font(.body.monospaced())
            }

            LabeledContent("技术架构") {
                Text("SwiftUI + Native AppKit + Local Python/SQLite")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
