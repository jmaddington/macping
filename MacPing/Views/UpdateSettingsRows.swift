// UpdateSettingsRows.swift
// AIDEV-NOTE: Update controls shown in the Settings section of MenuContentView (kept separate: that view is at lint limits)

import SwiftUI

struct UpdateSettingsRows: View {
    @Bindable var updater = Updater.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Check for Updates Automatically", isOn: $updater.automaticallyChecks)
                .controlSize(.small)
            Toggle("Install Updates Automatically", isOn: $updater.automaticallyInstalls)
                .controlSize(.small)
                .disabled(!updater.automaticallyChecks)
            HStack {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .controlSize(.small)
                    .disabled(!updater.canCheck)
                Spacer()
                Text("v\(Updater.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
