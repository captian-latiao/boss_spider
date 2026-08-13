import SwiftUI

struct StartupProgressView: View {
    @State private var progress: Double = 0

    private let timer = Timer.publish(
        every: 0.5,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)

            HStack {
                Text("当前进度 \(Int(progress * 100))%")
                Spacer()
                Text("预计还需 \(estimatedRemainingSeconds) 秒")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .onReceive(timer) { _ in
            guard progress < 0.95 else { return }
            progress = min(0.95, progress + 0.025)
        }
    }

    private var estimatedRemainingSeconds: Int {
        max(1, Int(ceil((1 - progress) * 30)))
    }
}
