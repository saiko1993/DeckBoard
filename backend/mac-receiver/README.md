# DeskBoard macOS Receiver Relay

This relay lets your **iPad/iPhone receiver** forward commands that iOS cannot execute in background to a **MacBook on the same LAN**.

## What this solves

When the iOS receiver is in background, commands like `open app`, `open URL`, and `run shortcut` often require foreground.

With relay enabled:

- iOS keeps the connection alive.
- Foreground-required commands are POSTed to this macOS relay.
- The Mac executes supported actions using `open`, `shortcuts`, and `osascript`.

## Quick start

```bash
cd backend/mac-receiver
PORT=7788 DESKBOARD_API_KEY=your_key npm start
```

Health check:

```bash
curl http://127.0.0.1:7788/health
```

## iOS app settings

In DeskBoard receiver app:

1. Open **Settings**.
2. Go to **Mac Receiver Relay**.
3. Enable **Forward blocked background actions**.
4. Set URL (example): `http://192.168.1.20:7788`.
5. Set API key if configured.

## Endpoints

- `GET /health`
- `GET /v1/capabilities`
- `POST /v1/execute`

Request body format:

```json
{
  "sourceDeviceUUID": "...",
  "sourceDeviceName": "iPad Receiver",
  "appVersion": "1.0.0",
  "reason": "receiver_background_foreground_required",
  "action": {
    "kind": "open_app",
    "appID": "chrome"
  }
}
```

## Supported action kinds

- `open_url`, `open_deep_link`
- `open_app`
- `run_shortcut`, `run_script`
- `keyboard_shortcut`
- `toggle_dark_mode`, `screenshot`, `screen_record`, `sleep_display`, `lock_screen`
- `open_terminal`, `force_quit_app`, `empty_trash`, `toggle_dnd`
- `presentation_next`, `presentation_previous`, `presentation_start`, `presentation_end`
- `media_play`, `media_pause`, `media_play_pause`, `media_next`, `media_previous`, `media_volume_up`, `media_volume_down`, `media_mute`
- `macro`

## macOS permissions (required)

For keyboard shortcuts and some scripts, macOS may ask for:

- Accessibility permission (System Settings -> Privacy & Security -> Accessibility)
- Automation permission (Terminal/Node controlling System Events)

Grant them once on the Mac running the relay.
