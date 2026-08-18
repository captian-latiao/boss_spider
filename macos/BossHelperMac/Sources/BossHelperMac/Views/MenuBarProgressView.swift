import SwiftUI

struct MenuBarProgressView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"

    private var accentColor: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private var metrics: MetricsResponse? {
        appState.metrics
    }

    private var resolvedLimit: Int {
        metrics?.deliveryLimit ?? 120
    }

    private var progress: Double {
        guard resolvedLimit > 0 else { return 0 }
        return min(max(Double(metrics?.success ?? 0) / Double(resolvedLimit), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentColor)

                Text("今日投递进度")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }

            ProgressView(value: progress)
                .tint(accentColor)

            if let metrics {
                Text(
                    "已投递 \(metrics.success) / \(resolvedLimit) 次"
                        + "（\(Int((progress * 100).rounded()))%）"
                )
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                Text("暂无投递数据")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
