// Updater.swift
// AIDEV-NOTE: Sparkle auto-update. Feed = appcast.xml on the latest GitHub Release (SUFeedURL in Info.plist),
// written by scripts/make-appcast.sh during the release; updates are EdDSA-signed (SUPublicEDKey).

import AppKit
import Observation
import Sparkle

@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    private(set) var canCheck = false
    var automaticallyChecks = false {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    var automaticallyInstalls = false {
        didSet { controller?.updater.automaticallyDownloadsUpdates = automaticallyInstalls }
    }

    private init() {}

    func start() {
        guard controller == nil else { return }
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
        controller = updaterController
        let updater = updaterController.updater
        automaticallyChecks = updater.automaticallyChecksForUpdates
        automaticallyInstalls = updater.automaticallyDownloadsUpdates
        canCheck = updater.canCheckForUpdates
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.new]) { updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in Updater.shared.canCheck = value }
        }
    }

    func checkForUpdates() {
        // Menu bar (accessory) apps must come forward or Sparkle's window opens behind others.
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
