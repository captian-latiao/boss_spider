import AppKit
import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case jobs
    case audit
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: return "Herooo"
        case .jobs: return "投递分析"
        case .audit: return "运行审计"
        case .settings: return "偏好设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .jobs: return "chart.bar.xaxis"
        case .audit: return "doc.text.magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme = "system"
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MainSplitView()
            .tint(accentColor)
            .accentColor(accentColor)
            .onAppear {
                applyAppearance(appTheme)
            }
            .onChange(of: appTheme) { _, newValue in
                applyAppearance(newValue)
            }
    }

    private var accentColor: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    private func applyAppearance(_ theme: String) {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
}

struct MainSplitView: View {
    @AppStorage("accentColor") private var accentColorKey = "pink"
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab? = .dashboard

    private var activeTab: MainTab {
        selectedTab ?? .dashboard
    }

    private var themeAccent: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            MainSidebarView(selectedTab: $selectedTab)
                .tint(themeAccent)
                .accentColor(themeAccent)
                .navigationSplitViewColumnWidth(min: 195, ideal: 195, max: 195)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            MainDetailView(tab: activeTab)
        }
        .navigationTitle(activeTab.title)
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Global Quick Action: Open BOSS Direct
                Button {
                    if let url = URL(string: "https://www.zhipin.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("打开 BOSS 直聘", systemImage: "safari")
                }
                .help("在默认浏览器中打开 BOSS 直聘网页")

                // Global Refresh
                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新数据状态")
            }
        }
    }
}

struct MainSidebarView: View {
    @Binding var selectedTab: MainTab?
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColorKey = "pink"

    private let mainTabs: [MainTab] = [.dashboard, .jobs, .audit]

    private var themeAccent: Color {
        AppTheme.accentColor(accent: accentColorKey, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Herooo Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeAccent,
                                    themeAccent.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: themeAccent.opacity(0.3), radius: 3, y: 1.5)

                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Herooo")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text("智能求职副驾")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()

            // Main Tabs List (Theme Accent Selection & Full-Width Hit Test)
            VStack(spacing: 3) {
                ForEach(mainTabs) { tab in
                    SidebarTabRow(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        themeAccent: themeAccent
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()

            // Bottom Pinned Settings Tab
            VStack(spacing: 0) {
                SidebarTabRow(
                    tab: .settings,
                    isSelected: selectedTab == .settings,
                    themeAccent: themeAccent
                ) {
                    selectedTab = .settings
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SidebarTabRow: View {
    let tab: MainTab
    let isSelected: Bool
    let themeAccent: Color
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: 18)

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? themeAccent
                            : (isHovered ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)) : Color.clear)
                    )
                    .shadow(color: isSelected ? themeAccent.opacity(0.35) : Color.clear, radius: 4, y: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct MainDetailView: View {
    let tab: MainTab

    var body: some View {
        Group {
            switch tab {
            case .dashboard:
                DashboardView()
            case .jobs:
                JobsView()
            case .audit:
                AuditView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
