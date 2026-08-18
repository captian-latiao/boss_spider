import SwiftUI

enum AccentColorOption: String, CaseIterable, Identifiable {
    case pink = "pink"
    case blue = "blue"
    case purple = "purple"
    case green = "green"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pink: return "珊瑚粉 (Herooo)"
        case .blue: return "科技蓝"
        case .purple: return "幻影紫"
        case .green: return "薄荷绿"
        }
    }

    var lightColor: Color {
        switch self {
        case .pink: return Color(red: 251 / 255, green: 94 / 255, blue: 138 / 255)
        case .blue: return Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
        case .purple: return Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
        case .green: return Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
        }
    }

    var darkColor: Color {
        switch self {
        case .pink: return Color(red: 255 / 255, green: 120 / 255, blue: 160 / 255)
        case .blue: return Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255)
        case .purple: return Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
        case .green: return Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255)
        }
    }

    func resolvedColor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColor : lightColor
    }
}

/// 全项目字号唯一事实来源：5 档文字体系 + 侧边栏例外。
/// 新 UI 请优先复用这里的档位，避免重新引入散乱字号。
enum AppFontSize {
    static let display: CGFloat = 22      // 指标大数字（rounded bold）
    static let title: CGFloat = 15        // 卡片标题 / 空态标题 / 状态标题
    static let body: CGFloat = 13         // 正文 / 列表标题
    static let callout: CGFloat = 12      // 次要信息
    static let caption: CGFloat = 11      // 元数据 / 页脚 / 图表提示
    static let mono: CGFloat = 12         // 日志正文（等宽）
    static let sidebarTitle: CGFloat = 14 // 侧边栏标签（有意比正文大一号）
    static let sidebarIcon: CGFloat = 15  // 侧边栏图标
}

enum AppTheme {
    static func accentColor(
        accent: String = "pink",
        colorScheme: ColorScheme = .light
    ) -> Color {
        let option = AccentColorOption(rawValue: accent) ?? .pink
        return option.resolvedColor(colorScheme: colorScheme)
    }

    // Legacy compatibility method
    static func accentColor(appTheme: String, colorScheme: ColorScheme) -> Color {
        let accentKey = UserDefaults.standard.string(forKey: "accentColor") ?? "pink"
        return accentColor(accent: accentKey, colorScheme: colorScheme)
    }

    static func cardBorder(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.07)
    }

    static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "success", "投递成功", "已投递":
            return Color.green
        case "warning", "filter", "已过滤", "规则拦截", "筛除":
            return Color.orange
        case "danger", "error", "失败", "异常":
            return Color.red
        default:
            return Color.secondary
        }
    }
}
