# DeskBoard

DeskBoard is a native iOS/iPadOS shortcut dashboard that sends commands to a paired receiver over local network. For actions that iOS cannot run in background, DeskBoard can forward execution to a macOS relay.

## What is included

- Native iOS app (`Sources/DeskBoard`)
- MultipeerConnectivity pairing and LAN transport
- Sender acknowledgements (`received`, `queued`, `forwarded`, `success`, `failed`, `timeout`)
- APNs silent wake support via Cloudflare worker (`backend/push-gateway`)
- macOS relay executor (`backend/mac-receiver`)
- macOS agent scaffold (`backend/mac-agent`)
- Widget + Control Center controls extension (`Sources/DeskBoardWidget`)

## Project structure

```text
Sources/DeskBoard/
  App/
  Core/
    Models/
    Networking/
    Services/
    Storage/
    Utilities/
  Features/
    Sender/
    Receiver/
    Pairing/
    Settings/
backend/
  push-gateway/
  mac-receiver/
  mac-agent/
```

## Requirements

- macOS 13+
- Xcode 15+
- Ruby + Bundler
- Homebrew

## Setup

```bash
bash scripts/setup.sh
```

Then fill `.env` with your Apple developer credentials.

## Build and test

```bash
bundle exec fastlane generate
bundle exec fastlane test
bundle exec fastlane build_debug
```

## Background execution model

- iOS/iPad receiver supports a subset of actions in background.
- Foreground-required actions are handled by policy:
  - relay to macOS
  - queue until receiver returns to foreground
  - fail immediately
- Experimental audio keep-alive is off by default and must be explicitly enabled from Settings > Debug.
- Intent-driven quick actions are available via App Intents, Home Screen widget, and Control Center controls (iOS 18+).

## Relay setup

See:
- `backend/mac-receiver/README.md`
- `backend/push-gateway/README.md`
- `backend/mac-agent/README.md`

## Notes

- `project.yml` is the source of truth for project configuration.
- Keep generated `DeskBoard.xcodeproj` aligned with `project.yml`.
