# DeskBoard Push Gateway (Cloudflare Worker)

This worker allows two paired DeskBoard devices to wake each other using APNs silent push.

## What it does

1. `POST /v1/register` stores each device APNs token keyed by its stable device UUID.
2. `POST /v1/wake` verifies caller identity using pairing token, then sends silent push to target UUID.
3. APNs push payload includes:
   - `aps.content-available = 1`
   - `deskboard.kind = "wake"`

## Prerequisites

1. Cloudflare account
2. Apple Push Key (`.p8`) from Apple Developer
3. APNs metadata:
   - `APNS_KEY_ID`
   - `APNS_TEAM_ID`
   - `APNS_BUNDLE_ID` (must match app bundle id, e.g. `com.deskboard.app`)

## Deploy

From this folder:

```bash
npm install
```

Create KV namespace:

```bash
npx wrangler kv namespace create DEVICE_STORE
```

Copy generated namespace `id` into [`wrangler.toml`](/Users/ahmed/Downloads/DeckBoard/backend/push-gateway/wrangler.toml).

Set secrets:

```bash
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_BUNDLE_ID
npx wrangler secret put APNS_PRIVATE_KEY
npx wrangler secret put WAKE_API_KEY
```

Optional:

```bash
npx wrangler secret put APNS_USE_SANDBOX
```

Deploy:

```bash
npm run deploy
```

## App configuration

In DeskBoard settings on both devices:

1. Enable `Silent Push Wake`
2. Set `Gateway URL` to your worker URL, e.g. `https://deskboard-push-gateway.<subdomain>.workers.dev`
3. Set `Gateway API Key` to `WAKE_API_KEY` if configured

## API payloads

### Register

`POST /v1/register`

```json
{
  "deviceUUID": "uuid-string",
  "pairingToken": "pairing-token",
  "apnsToken": "hex-apns-token",
  "role": "receiver",
  "deviceName": "Ahmed iPad",
  "appVersion": "1.0.0"
}
```

### Wake

`POST /v1/wake`

```json
{
  "fromDeviceUUID": "uuid-source",
  "fromPairingToken": "pairing-token-source",
  "targetDeviceUUID": "uuid-target",
  "reason": "connection_lost"
}
```
