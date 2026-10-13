// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import AppKit
import Foundation
import MonitorCore
import SwiftUI

@main
@MainActor
enum DougMonitorApp {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            DiagnosticCommand.run()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = MonitorStore()
    private let speedTest = SpeedTestStore()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu-bar utility deliberately has no Dock icon or permanent window.
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "Monitor")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.title = " C —  R —"
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let root = MonitorView(store: store, speedTest: speedTest) { NSApp.terminate(nil) }
        let controller = NSHostingController(rootView: root)
        popover.contentViewController = controller
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        store.didSample = { [weak self] snapshot in
            let title = " C \(MetricFormat.percent(snapshot.cpu))  R \(MetricFormat.percent(snapshot.memoryFraction))"
            self?.statusItem?.button?.title = title
            self?.statusItem?.button?.toolTip = "Monitor · CPU \(MetricFormat.percent(snapshot.cpu)) · RAM \(MetricFormat.percent(snapshot.memoryFraction))"
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.stop(); self?.speedTest.cancel() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.start() }
        })
        store.start()
        // Show the finished panel at launch; later it opens from the menu bar.
        DispatchQueue.main.async { [weak self] in self?.showPopover() }
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        speedTest.cancel()
        store.stop()
        for token in observers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}
