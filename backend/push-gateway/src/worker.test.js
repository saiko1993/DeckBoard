import test from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.js";

class InMemoryKV {
  #store = new Map();

  async put(key, value) {
    this.#store.set(key, value);
  }

  async get(key) {
    return this.#store.get(key) ?? null;
  }
}

function makeEnv(overrides = {}) {
  return {
    APNS_KEY_ID: "ABC123DEFG",
    APNS_TEAM_ID: "TEAM123456",
    APNS_BUNDLE_ID: "app.rork.qk8s5pz3bbw4sk3nw0gmq",
    APNS_PRIVATE_KEY: `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg/cc/hWooy6bsSlFD
UBO9txGUiMwuuAQPNsDpbnJwlMuhRANCAARJEDXUg3ZVbAusA1olVtilxFfHSXzX
nCYn9Y68CvNWw7MxCAsoi0A08jpKcj6/ALQLGGV7CzxvxL67gJGRpkaR
-----END PRIVATE KEY-----`,
    APNS_USE_SANDBOX: "true",
    DEVICE_STORE: new InMemoryKV(),
    WAKE_API_KEY: "",
    ...overrides
  };
}

const sourceUUID = "source-device-uuid";
const targetUUID = "target-device-uuid";
const pairingToken = "pairing-token-1234567890";

test("GET /health returns metadata and configured=true", async () => {
  const env = makeEnv();
  const request = new Request("https://gateway.example.com/health", { method: "GET" });
  const response = await worker.fetch(request, env);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.service, "deskboard-push-gateway");
  assert.equal(body.apnsTopic, "app.rork.qk8s5pz3bbw4sk3nw0gmq");
  assert.equal(body.configured, true);
});

test("register then wake succeeds with valid credentials", async () => {
  const env = makeEnv();
  let apnsRequest = null;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    apnsRequest = { url, options };
    return new Response("{}", { status: 200 });
  };

  try {
    const registerSource = new Request("https://gateway.example.com/v1/register", {
      method: "POST",
      body: JSON.stringify({
        deviceUUID: sourceUUID,
        pairingToken,
        apnsToken: "source-apns-token-12345678901234567890",
        role: "sender",
        deviceName: "Source Device",
        appVersion: "1.0.0"
      })
    });
    const sourceResponse = await worker.fetch(registerSource, env);
    assert.equal(sourceResponse.status, 200);

    const registerTarget = new Request("https://gateway.example.com/v1/register", {
      method: "POST",
      body: JSON.stringify({
        deviceUUID: targetUUID,
        pairingToken: "target-pairing-token-1234567890",
        apnsToken: "target-apns-token-12345678901234567890",
        role: "receiver",
        deviceName: "Target Device",
        appVersion: "1.0.0"
      })
    });
    const targetResponse = await worker.fetch(registerTarget, env);
    assert.equal(targetResponse.status, 200);

    const wake = new Request("https://gateway.example.com/v1/wake", {
      method: "POST",
      body: JSON.stringify({
        fromDeviceUUID: sourceUUID,
        fromPairingToken: pairingToken,
        targetDeviceUUID: targetUUID,
        reason: "test_wake"
      })
    });
    const wakeResponse = await worker.fetch(wake, env);
    const wakeBody = await wakeResponse.json();

    assert.equal(wakeResponse.status, 200);
    assert.equal(wakeBody.ok, true);
    assert.ok(apnsRequest);
    assert.match(String(apnsRequest.url), /api\.sandbox\.push\.apple\.com/);
    assert.equal(apnsRequest.options.headers["apns-topic"], "app.rork.qk8s5pz3bbw4sk3nw0gmq");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("wake rejects invalid source credentials", async () => {
  const env = makeEnv();
  const registerSource = new Request("https://gateway.example.com/v1/register", {
    method: "POST",
    body: JSON.stringify({
      deviceUUID: sourceUUID,
      pairingToken,
      apnsToken: "source-apns-token-12345678901234567890",
      role: "sender",
      deviceName: "Source Device",
      appVersion: "1.0.0"
    })
  });
  await worker.fetch(registerSource, env);

  const registerTarget = new Request("https://gateway.example.com/v1/register", {
    method: "POST",
    body: JSON.stringify({
      deviceUUID: targetUUID,
      pairingToken: "target-pairing-token-1234567890",
      apnsToken: "target-apns-token-12345678901234567890",
      role: "receiver",
      deviceName: "Target Device",
      appVersion: "1.0.0"
    })
  });
  await worker.fetch(registerTarget, env);

  const wake = new Request("https://gateway.example.com/v1/wake", {
    method: "POST",
    body: JSON.stringify({
      fromDeviceUUID: sourceUUID,
      fromPairingToken: "invalid-pairing-token",
      targetDeviceUUID: targetUUID,
      reason: "test_wake"
    })
  });

  const response = await worker.fetch(wake, env);
  const body = await response.json();
  assert.equal(response.status, 403);
  assert.equal(body.error, "invalid_source_credentials");
});
