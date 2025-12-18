# MacThrottle

A macOS menu bar app that monitors thermal pressure and alerts you when your Mac is being throttled.

![screenshot](./assets/screenshot.png)

## Features

- Displays thermal pressure state in the menu bar using different thermometer icons
- Shows CPU core temperature (reads directly from SMC)
- History graph showing thermal state and temperature over the last hour
- Statistics showing time spent in each thermal state
- Configurable notifications:
  - When heavy throttling begins
  - When critical throttling occurs (trapping/sleeping)
  - When throttling stops (recovery)
  - Optional notification sounds
- Lightweight background monitoring via a launch daemon
- Helper auto-update detection when a new version is available

## Thermal States

| Icon                   | State             | Description                    |
| ---------------------- | ----------------- | ------------------------------ |
| `thermometer.low`      | Nominal           | Normal operation               |
| `thermometer.medium`   | Moderate          | Elevated thermal pressure      |
| `thermometer.high`     | Heavy             | Active throttling              |
| `thermometer.sun.fill` | Trapping/Sleeping | Severe throttling              |
| `thermometer`          | Unknown           | Daemon not responding or stale |

## Installation

### Option 1: Download from Releases

1. Download the latest `.dmg` from [Releases](https://github.com/angristan/MacThrottle/releases)
2. Drag `MacThrottle.app` to your Applications folder
3. Right-click the app → "Open" → "Open" (required for unsigned apps)
4. Click "Install Helper..." in the menu bar dropdown
5. Enter your admin password to install the monitoring daemon

### Option 2: Build Locally

Building locally automatically signs the app with your development certificate, avoiding Gatekeeper issues.

```bash
# Clone the repo
git clone https://github.com/angristan/MacThrottle.git
cd MacThrottle

# Build with Xcode
xcodebuild -project MacThrottle.xcodeproj \
  -scheme MacThrottle \
  -configuration Release \
  -derivedDataPath build

# Run the app
open build/Build/Products/Release/MacThrottle.app
```

Or open `MacThrottle.xcodeproj` in Xcode and press `Cmd+R` to build and run.

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

## Temperature Reading

MacThrottle displays CPU temperature alongside thermal pressure. Reading temperature on macOS requires low-level hardware access through two methods:

### SMC (Primary)

The **System Management Controller (SMC)** is a hardware chip in every Mac that manages thermal sensors, fans, and power. MacThrottle reads directly from the SMC via IOKit to get actual CPU core temperatures.

- Reads chip-specific sensor keys (different for M1, M2, M3, and Intel Macs)
- Provides accurate per-core temperature readings
- Based on the approach used by [Stats](https://github.com/exelban/stats)
- No admin privileges required (unlike thermal pressure)

### IOHIDEventSystem (Fallback)

If SMC reading fails, MacThrottle falls back to the **IOHIDEventSystem** private API:

- Reads temperature events from PMU (Power Management Unit) sensors
- Simpler but less granular—returns aggregate "tdie" temperatures rather than per-core values
- May report slightly different (typically lower) values than SMC

The displayed temperature is the maximum reading across all available CPU sensors.

## Requirements

- macOS 14.0+
- Admin privileges (for helper installation)

## Uninstalling

Click "Uninstall Helper..." in the menu to remove the launch daemon and helper script.
