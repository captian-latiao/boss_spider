import SwiftUI

struct BackendUnavailableView: View {
    enum State {
        case starting
        case stopped
        case failed(String)
    }

    @EnvironmentObject private var appState: AppState

    let state: State

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .starting:
                Text("服务启动中")
                    .font(.title2)

                StartupProgressView()
                    .frame(maxWidth: 420)

            case .stopped:
                Image(systemName: "stop.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("后端服务已停止")
                    .font(.title.bold())

                Text("你已手动停止本地后端服务。数据接收和监控功能暂停。")
                    .foregroundStyle(.secondary)

                Button("启动后台") {
                    Task {
                        await appState.startBackend()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("后端服务未就绪")
                    .font(.title.bold())

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                VStack(alignment: .leading, spacing: 8) {
                    Text("可以尝试：")
                        .font(.headline)
                    Text("1. 点击下方“重试”按钮")
                    Text("2. 确认 127.0.0.1:5005 没有被其他程序占用")
                    Text("3. 退出并重新打开 BossHelper")
                }
                .foregroundStyle(.secondary)

                Button("重试") {
                    Task {
                        await appState.retryBackend()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(36)
        .frame(minWidth: 620, minHeight: 420)
    }
}
