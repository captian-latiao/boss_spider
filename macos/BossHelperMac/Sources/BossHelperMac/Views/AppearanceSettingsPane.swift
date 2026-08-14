import SwiftUI

struct AppearanceSettingsPane: View {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
