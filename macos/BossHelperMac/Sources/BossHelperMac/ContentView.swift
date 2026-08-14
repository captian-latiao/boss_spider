import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard
    case audit
    case data
    case general
    case appearance
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .dashboard: return "Herooo"
        case .audit: return "审计"
        case .data: return "数据"
        case .general: return "通用"
        case .appearance: return "外观"
        case .about: return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge"
        case .audit: return "list.bullet.rectangle"
        case .data: return "folder"
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme = "system"

    var body: some View {
        MainSplitView()
            .preferredColorScheme(resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct MainSplitView: View {
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

    private let contentTabs: [MainTab] = [.dashboard, .audit, .data]
    private let settingsTabs: [MainTab] = [.general, .appearance, .about]

    var body: some View {
        List(selection: $selectedTab) {
            Section("内容") {
                ForEach(contentTabs) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }

            Section("设置") {
                ForEach(settingsTabs) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollEdgeEffectStyleSoftIfAvailable()
        .navigationTitle("BossHelper")
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
            case .general:
                GeneralSettingsPane()
            case .appearance:
                AppearanceSettingsPane()
            case .about:
                AboutSettingsPane()
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
