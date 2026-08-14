import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 900, height: 640)),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureWindow() {
        guard let window else { return }

        window.title = "BossHelper"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .automatic
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("BossHelperMainWindow")
        window.minSize = NSSize(width: 720, height: 540)
        window.center()
        window.delegate = self

        let hostingController = NSHostingController(
            rootView: ContentView().environmentObject(appState)
        )
        hostingController.sceneBridgingOptions = [.toolbars, .title]
        window.contentViewController = hostingController
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
