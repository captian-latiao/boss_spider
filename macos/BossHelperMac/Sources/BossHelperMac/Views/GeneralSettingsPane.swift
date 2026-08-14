import SwiftUI

struct GeneralSettingsPane: View {
    @AppStorage("autoStartBackend") private var autoStartBackend = true

    var body: some View {
        Form {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
