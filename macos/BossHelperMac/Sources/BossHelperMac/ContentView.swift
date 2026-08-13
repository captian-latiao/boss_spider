import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.backendState {
        case .ready, .stopped, .stopping:
            mainView

        case .starting:
            if appState.hasReachedReady {
                mainView
            } else {
                BackendUnavailableView(state: .starting)
            }

        case .failed(let message):
            if appState.hasReachedReady {
                mainView
            } else {
                BackendUnavailableView(state: .failed(message))
            }
        }
    }

    private var mainView: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("总览", systemImage: "gauge")
                }

            AuditView()
                .tabItem {
                    Label("审计", systemImage: "list.bullet.rectangle")
                }

            DataView()
                .tabItem {
                    Label("数据", systemImage: "folder")
                }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
