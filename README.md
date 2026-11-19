# MacLatency

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-15+-blue)](https://github.com/jmaddington/maclatency)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)

A lightweight macOS menu bar app that monitors network latency to your gateway and custom hosts. See at a glance if your network is healthy.

## Background

I've wanted an app like this for years, but didn't want to learn Swift to make it happen. With the advent of LLMs, I finally have my application.

[NirSoft's PingInfoView](https://www.nirsoft.net/utils/multiple_ping_tool.html) was what I wanted on Windows, but this new app is even closer to what I need on my Mac - a simple menu bar indicator showing network health at a glance.

This project started as a fork of [MacThrottle](https://github.com/angristan/MacThrottle) by angristan, which was a thermal monitoring app. I used [Claude Code](https://claude.ai/claude-code) and GPT-5 (via Xcode) to transform it into a network latency monitor.

> **Warning**: I still don't know Swift. This entire codebase was written by AI. Use at your own risk, and PRs from actual Swift developers are very welcome!

## Features

- Displays network latency status in the menu bar with color-coded icons
- Auto-discovers and monitors your network gateway(s)
- Add custom hosts to monitor (IP addresses or hostnames)
- History graph showing latency over the last 10 minutes
- Statistics showing time spent in each latency state
- Configurable latency thresholds (default: <50ms excellent, <100ms good, <200ms fair)
- Configurable poll interval (1-30 seconds)
- Notifications for:
  - Poor latency (>200ms by default)
  - Host offline/unreachable
  - Recovery to good status
  - Optional notification sounds
- Launch at Login option
- No admin privileges required

## Latency States

| Color  | State     | Default Threshold |
| ------ | --------- | ----------------- |
| Green  | Excellent | < 50ms            |
| Yellow | Good      | 50-100ms          |
| Orange | Fair      | 100-200ms         |
| Red    | Poor      | > 200ms           |
| Red    | Offline   | Timeout           |

## Installation

Download the signed, notarized **DMG** or **ZIP** from [Releases](https://github.com/jmaddington/macping/releases/latest). MacPing updates itself after that (see [Updates](#updates)).

### Build Locally

```bash
# Clone the repo
git clone https://github.com/jmaddington/maclatency.git
cd maclatency

# Build with Xcode
xcodebuild -project MacPing.xcodeproj \
  -scheme MacPing \
  -configuration Release \
  -derivedDataPath build

# Run the app
open build/Build/Products/Release/MacPing.app
```

Or open `MacPing.xcodeproj` in Xcode and press `Cmd+R` to build and run.

## How It Works

### Latency Monitoring

MacLatency uses ICMP ping to measure round-trip time to monitored hosts. It automatically discovers your network gateway(s) by querying the system routing table, and you can add additional hosts to monitor.

The app polls all enabled hosts at a configurable interval (default: 5 seconds) and displays the worst latency in the menu bar. Individual host latencies are shown in the dropdown menu.

### Gateway Discovery

On startup and when you click "Refresh", the app discovers active network interfaces and their default gateways using the system routing table. This allows it to monitor your actual network path rather than just an arbitrary external server.

## Updates

MacPing updates itself with [Sparkle](https://sparkle-project.org) 2. It checks once a day, and Settings has toggles for automatic checks and automatic install, plus **Check for Updates…**.

- **Feed:** `SUFeedURL` points at `releases/latest/download/appcast.xml`. GitHub redirects that to the newest release, so nothing else needs hosting.
- **Signing:** each update DMG is EdDSA-signed in CI, and the app only accepts updates that verify against `SUPublicEDKey` in `MacPing/Info.plist`.
- **The key:** the private key's backup lives in the maintainer's login keychain (account `sparkle-macping`). **If it's lost, existing installs can't verify future updates.** Export a backup with `$(scripts/ci/sparkle-tools.sh)/generate_keys --account sparkle-macping -x macping-sparkle.key`.
- **Versioning:** the build number is `major×1,000,000 + minor×1,000 + patch` (`scripts/set-version.sh`), so newer versions always compare higher.
- **Upgrading Sparkle:** bump the package version in Xcode and `SPARKLE_VERSION`/`SPARKLE_SHA256` in `scripts/ci/sparkle-tools.sh` together.
- Versions before the first Sparkle-enabled release have to update by hand once.

## Releases

Releases are automatic. [semantic-release](https://semantic-release.gitbook.io) runs on every push to `main`. A `feat:` commit cuts a minor release and a `fix:` commit a patch, while `chore:`/`docs:`/`style:`/`ci:` commits don't release. Each release:

1. Bumps the version (`scripts/set-version.sh`) and updates `CHANGELOG.md`.
2. Builds, signs with the Developer ID (hardened runtime), notarizes and staples the app and DMG (`scripts/build-release.sh`). This runs before the release commit and tag are pushed, so a signing failure leaves nothing half-released. CI refuses to build an unsigned release.
3. Publishes the GitHub Release with the DMG, ZIP and `SHA256SUMS.txt`, then adds the Sparkle `appcast.xml`.

Repository secrets:

| Secret | What |
|---|---|
| `DEVELOPER_ID_APP_P12` / `DEVELOPER_ID_APP_PASSWORD` | `base64 -i DeveloperIDApplication.p12` and its password |
| `ASC_API_KEY_P8` | Contents of `AuthKey_XXXX.p8` (App Store Connect › Users and Access › Integrations › Team Keys) |
| `ASC_API_KEY_ID` / `ASC_API_ISSUER_ID` | From the same page |
| `SPARKLE_ED_PRIVATE_KEY` | EdDSA key that signs updates |

Troubleshooting: `Notary API key rejected … 403 … agreement` means Apple has an agreement waiting. The Account Holder accepts it at [developer.apple.com/account](https://developer.apple.com/account) and in App Store Connect › Business. It took about 10 minutes to clear last time.

## Requirements

- macOS 15.0+ (Sequoia)

## Credits

- Original [MacThrottle](https://github.com/angristan/MacThrottle) by [angristan](https://github.com/angristan)
- Transformed to latency monitor using [Claude Code](https://claude.ai/claude-code) and GPT-5

## License

MIT License - see [LICENSE](LICENSE) for details.
