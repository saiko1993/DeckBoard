# DeskBoard macOS Receiver Relay

Relay service that executes background-blocked DeskBoard actions on macOS.

## Highlights (Protocol v2)

- Idempotent execution via `idempotencyKey` / `x-idempotency-key`
- Structured execution responses with `executor`, `latencyMs`, `errorCode`
- Capability metadata endpoint
- Readiness metrics in health endpoint

## Run

```bash
cd backend/mac-receiver
PORT=7788 DESKBOARD_API_KEY=your_key npm start
```

## Endpoints

- `GET /health`
  - Includes `serviceVersion`, `protocolVersion`, readiness and uptime
- `GET /v1/capabilities`
  - Includes capability list and metadata
- `POST /v1/execute`
  - Executes action payload with optional idempotency and trace values

## Execute payload

```json
{
  "sourceDeviceUUID": "...",
  "sourceDeviceName": "Ahmed iPad",
  "appVersion": "1.0.0",
  "reason": "receiver_background_foreground_required",
  "traceID": "2A2F...",
  "idempotencyKey": "2A2F...:1",
  "attempt": 1,
  "ttlSeconds": 12,
  "action": {
    "kind": "open_app",
    "appID": "chrome"
  }
}
```

## macOS permissions

Some commands require macOS prompts to be approved once:

- Accessibility (keyboard/system events)
- Automation (Terminal/Node controlling System Events)

Without these permissions, related commands will return execution errors.
