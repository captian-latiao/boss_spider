import AppKit
import Combine
import SwiftUI

/// Menu bar status item showing today's delivery progress percentage.
@MainActor
final class MenuBarController: NSObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState) {
        self.appState = appState

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 112)
        self.popover = popover

        super.init()

        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .small),
                weight: .medium
            )
            button.toolTip = "Herooo 今日投递进度"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.contentViewController = NSHostingController(
            rootView: MenuBarProgressView().environmentObject(appState)
        )

        updateTitle()

        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTitle()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateTitle() {
        guard let metrics = appState.metrics else {
            statusItem.button?.title = "—"
            return
        }
        statusItem.button?.title =
            Self.percentText(success: metrics.success, limit: metrics.deliveryLimit) ?? "—"
    }

    /// Returns a clamped percentage string like "35%", or nil when the limit
    /// is missing or non-positive.
    nonisolated static func percentText(success: Int, limit: Int?) -> String? {
        guard let limit, limit > 0 else { return nil }
        let ratio = min(max(Double(success) / Double(limit), 0), 1)
        return "\(Int((ratio * 100).rounded()))%"
    }
}
