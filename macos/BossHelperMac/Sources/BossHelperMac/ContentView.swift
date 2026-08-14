import AppKit
import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case audit
    case data
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: return "Herooo"
        case .audit: return "审计"
        case .data: return "数据"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge"
        case .audit: return "list.bullet.rectangle"
        case .data: return "folder"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme = "system"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MainSplitView()
            .tint(accentColor)
            .onAppear {
                applyAppearance(appTheme)
            }
            .onChange(of: appTheme) { _, newValue in
                applyAppearance(newValue)
            }
    }

    private var accentColor: Color {
        AppTheme.accentColor(appTheme: appTheme, colorScheme: colorScheme)
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
    @AppStorage("appTheme") private var appTheme = "system"
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: MainTab? = .dashboard
    @State private var history: [MainTab] = [.dashboard]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var activeTab: MainTab {
        selectedTab ?? .dashboard
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            MainSidebarView(selectedTab: $selectedTab)
                .tint(AppTheme.accentColor(appTheme: appTheme, colorScheme: colorScheme))
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            MainDetailView(tab: activeTab)
        }
        .navigationTitle("BossHelper")
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button {
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
            }
        }
        .onChange(of: selectedTab) { _, _ in
            recordNavigation()
        }
    }

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    private func goBack() {
        guard canGoBack else { return }
        isHistoryNavigation = true
        historyIndex -= 1
        selectedTab = history[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func goForward() {
        guard canGoForward else { return }
        isHistoryNavigation = true
        historyIndex += 1
        selectedTab = history[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func recordNavigation() {
        guard !isHistoryNavigation else { return }
        guard let tab = selectedTab else { return }
        if history.last == tab { return }
        if historyIndex < history.count - 1 {
            history = Array(history.prefix(historyIndex + 1))
        }
        history.append(tab)
        historyIndex = history.count - 1
    }
}

struct MainSidebarView: View {
    @Binding var selectedTab: MainTab?

    private let topTabs: [MainTab] = [.dashboard, .audit, .data]

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(topTabs) { tab in
                MainSidebarTabLabel(tab: tab)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .scrollEdgeEffectStyleSoftIfAvailable()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            List(selection: $selectedTab) {
                MainSidebarTabLabel(tab: .settings)
                    .tag(MainTab.settings)
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
            .frame(height: 40)
        }
        .navigationTitle("BossHelper")
    }
}

private struct MainSidebarTabLabel: View {
    let tab: MainTab

    var body: some View {
        Label(tab.title, systemImage: tab.systemImage)
    }
}

struct MainDetailView: View {
    let tab: MainTab

    var body: some View {
        Group {
            switch tab {
            case .dashboard:
                DashboardView()
            case .audit:
                AuditView()
            case .data:
                DataView()
            case .settings:
                SettingsView()
            }
        }
        .navigationTitle(tab.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private extension View {
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
