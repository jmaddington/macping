// MenuContentView.swift
// AIDEV-NOTE: Main menu content for network latency monitor

import SwiftUI

func colorForLatency(_ ms: Double) -> Color {
    switch ms {
    case ..<50: return .green
    case 50..<100: return .yellow
    case 100..<200: return .orange
    default: return .red
    }
}

struct MenuContentView: View {
    @Bindable var monitor: LatencyMonitor
    @Environment(\.openWindow) private var openWindow
    @State private var newHostAddress: String = ""
    @State private var newHostLabel: String = ""
    @State private var showAddHost: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Network Status:")
                Text(monitor.overallStatus.displayName)
                    .foregroundColor(monitor.overallStatus.color)
                    .fontWeight(.semibold)
                Spacer()
                if let latency = monitor.worstLatency {
                    Text("\(Int(latency.rounded()))ms")
                        .foregroundColor(colorForLatency(latency))
                        .fontWeight(.semibold)
                        .help("Worst latency")
                }
            }
            .font(.headline)

            // Per-host latency readings
            if !monitor.sortedReadings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(monitor.sortedReadings) { reading in
                        HStack {
                            Circle()
                                .fill(reading.status.color)
                                .frame(width: 8, height: 8)
                            Text(reading.hostLabel)
                                .lineLimit(1)
                            Spacer()
                            Text(reading.displayLatency)
                                .foregroundColor(reading.status.color)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            }

            // History graph
            if monitor.history.count >= 2 {
                HistoryGraphView(history: monitor.history, hosts: monitor.hosts)
            }

            // Statistics
            if !monitor.timeInEachState.isEmpty {
                Divider()
                Text("Statistics")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TimeBreakdownView(
                    timeInEachState: monitor.timeInEachState,
                    totalDuration: monitor.totalHistoryDuration
                )
            }

            Divider()

            // Hosts section
            hostsSection

            Divider()

            // Settings
            Text("Settings")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Launch at Login", isOn: Binding(
                get: { LaunchAtLoginManager.shared.isEnabled },
                set: { LaunchAtLoginManager.shared.isEnabled = $0 }
            ))
            .controlSize(.small)

            Toggle("Show Latency in Menu Bar", isOn: $monitor.showLatencyInMenuBar)
                .controlSize(.small)

            Divider()

            Text("Notifications")
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                Toggle("On Poor (>200ms)", isOn: $monitor.notifyOnPoor)
                Toggle("On Offline", isOn: $monitor.notifyOnOffline)
                Toggle("On Recovery", isOn: $monitor.notifyOnRecovery)
                Toggle("Sound", isOn: $monitor.notificationSound)
            }
            .controlSize(.small)

            Divider()

            HStack {
                Button("About") {
                    openAboutWindow()
                }
                .controlSize(.small)

                Spacer()

                Button("Refresh") {
                    monitor.refreshHosts()
                }
                .controlSize(.small)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private var hostsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Monitored Hosts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddHost.toggle()
                } label: {
                    Image(systemName: showAddHost ? "minus.circle" : "plus.circle")
                }
                .buttonStyle(.plain)
                .help(showAddHost ? "Cancel" : "Add host")
            }

            if showAddHost {
                addHostForm
            }

            // List user-defined hosts with delete option
            ForEach(monitor.userDefinedHosts) { host in
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    Text(host.label)
                        .lineLimit(1)
                    Text("(\(host.address))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        monitor.removeHost(host)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove host")
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var addHostForm: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("IP or hostname", text: $newHostAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            HStack {
                TextField("Label (optional)", text: $newHostLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Add") {
                    if !newHostAddress.isEmpty {
                        monitor.addHost(address: newHostAddress, label: newHostLabel)
                        newHostAddress = ""
                        newHostLabel = ""
                        showAddHost = false
                    }
                }
                .controlSize(.small)
                .disabled(newHostAddress.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func openAboutWindow() {
        openWindow(id: "about")
        NSApp.activate(ignoringOtherApps: true)
    }
}
