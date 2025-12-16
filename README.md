# MacThrottle

A macOS menu bar app that monitors thermal pressure and alerts you when your Mac is being throttled.

## Features

- Displays thermal pressure state in the menu bar using different thermometer icons
- Notifies you when thermal throttling begins
- Lightweight background monitoring via a launch daemon

## Thermal States

| Icon                   | State             | Description               |
| ---------------------- | ----------------- | ------------------------- |
| `thermometer.low`      | Nominal           | Normal operation          |
| `thermometer.medium`   | Moderate          | Elevated thermal pressure |
| `thermometer.high`     | Heavy             | Active throttling         |
| `thermometer.sun.fill` | Trapping/Sleeping | Severe throttling         |

## Installation

1. Build and run the app in Xcode
2. Click "Install Helper..." in the menu bar dropdown
3. Enter your admin password to install the monitoring daemon

The helper runs `powermetrics` to read thermal data and writes the current state to `/tmp/mac-throttle-thermal-state`.

## Why a Helper?

### Why not `ProcessInfo.thermalState`?

macOS provides [`ProcessInfo.thermalState`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum) as a public API, but it has limited granularity—only 4 states vs the 5 states from `powermetrics`:

| `ProcessInfo.thermalState` | `powermetrics` |
| -------------------------- | -------------- |
| nominal                    | nominal        |
| **fair**                   | **moderate**   |
| **fair**                   | **heavy**      |
| serious                    | trapping       |
| critical                   | sleeping       |

The `moderate` and `heavy` states from `powermetrics` both map to `fair` in `ProcessInfo.thermalState`, however the difference between `moderate` and `heavy` thermal pressure is significant in terms of performance impact. `heavy` is when throttling really kicks in, so it's important to distinguish between these states for accurate monitoring.

### Why admin privileges?

MacThrottle uses `powermetrics -s thermal` to read the system's actual thermal pressure level. This tool:

- Accesses low-level hardware sensors and kernel data
- Requires root privileges to run
- Provides the real thermal pressure state that affects CPU/GPU frequency scaling

The helper is installed as a launch daemon (`/Library/LaunchDaemons/`) which runs as root and writes the thermal state to a world-readable file that the app can monitor without elevated privileges.

## Requirements

- macOS 14.0+
- Admin privileges (for helper installation)

## Uninstalling

Click "Uninstall Helper..." in the menu to remove the launch daemon and helper script.
