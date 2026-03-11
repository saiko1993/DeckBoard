import { SignJWT, importPKCS8 } from "jose";

const SERVICE_VERSION = "1.1.0";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type,x-deskboard-key"
};

let cachedToken = {
  value: null,
  expiresAtMs: 0,
  keyId: "",
  teamId: ""
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/health" && request.method === "GET") {
      return json(
        {
          ok: true,
          service: "deskboard-push-gateway",
          version: SERVICE_VERSION,
          apnsTopic: env.APNS_BUNDLE_ID || null,
          apnsUseSandbox: env.APNS_USE_SANDBOX === "true",
          configured: hasRequiredApnsConfig(env)
        },
        200
      );
    }

    if (!authorizeRequest(request, env)) {
      return json({ error: "unauthorized" }, 401);
    }

    if (path === "/v1/register" && request.method === "POST") {
      return handleRegister(request, env);
    }

    if (path === "/v1/wake" && request.method === "POST") {
      return handleWake(request, env);
    }

    return json({ error: "not_found" }, 404);
  }
};

async function handleRegister(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const {
    deviceUUID,
    pairingToken,
    apnsToken,
    role = "unset",
    deviceName = "DeskBoard Device",
    appVersion = "1.0.0"
  } = body ?? {};

  if (!isValidDeviceUUID(deviceUUID)) {
    return json({ error: "invalid_device_uuid" }, 400);
  }
  if (!isValidToken(pairingToken, 16, 4096)) {
    return json({ error: "invalid_pairing_token" }, 400);
  }
  if (!isValidToken(apnsToken, 32, 512)) {
    return json({ error: "invalid_apns_token" }, 400);
  }

  const record = {
    deviceUUID,
    pairingHash: await sha256Hex(pairingToken),
    apnsToken,
    role: String(role),
    deviceName: String(deviceName).slice(0, 128),
    appVersion: String(appVersion).slice(0, 64),
    updatedAt: new Date().toISOString()
  };

  await env.DEVICE_STORE.put(deviceKey(deviceUUID), JSON.stringify(record));
  return json({ ok: true, registered: true }, 200);
}

async function handleWake(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const {
    fromDeviceUUID,
    fromPairingToken,
    targetDeviceUUID,
    reason = "wake_request"
  } = body ?? {};

  if (!isValidDeviceUUID(fromDeviceUUID) || !isValidDeviceUUID(targetDeviceUUID)) {
    return json({ error: "invalid_device_uuid" }, 400);
  }
  if (!isValidToken(fromPairingToken, 16, 4096)) {
    return json({ error: "invalid_pairing_token" }, 400);
  }

  const sourceRecord = await readRecord(env, fromDeviceUUID);
  if (!sourceRecord) {
    return json({ error: "source_not_registered" }, 404);
  }

  const sourcePairingHash = await sha256Hex(fromPairingToken);
  if (sourceRecord.pairingHash !== sourcePairingHash) {
    return json({ error: "invalid_source_credentials" }, 403);
  }

  const targetRecord = await readRecord(env, targetDeviceUUID);
  if (!targetRecord) {
    return json({ error: "target_not_registered" }, 404);
  }

  const apns = await sendSilentPush({
    env,
    apnsToken: targetRecord.apnsToken,
    targetDeviceUUID,
    reason: String(reason).slice(0, 64)
  });

  if (!apns.ok) {
    return json(
      {
        error: "apns_failed",
        status: apns.status,
        response: apns.responseBody
      },
      502
    );
  }

  return json({ ok: true, woke: true, status: apns.status }, 200);
}

async function sendSilentPush({ env, apnsToken, targetDeviceUUID, reason }) {
  const jwt = await getApnsJwt(env);
  const host = env.APNS_USE_SANDBOX === "true" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const url = `https://${host}/3/device/${apnsToken}`;

  const payload = {
    aps: { "content-available": 1 },
    deskboard: {
      kind: "wake",
      targetDeviceUUID,
      reason,
      timestamp: new Date().toISOString()
    }
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": env.APNS_BUNDLE_ID,
      "apns-push-type": "background",
      "apns-priority": "5",
      "apns-expiration": "0",
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  return {
    ok: response.ok,
    status: response.status,
    responseBody: await response.text()
  };
}

async function getApnsJwt(env) {
  const nowMs = Date.now();
  const ttlMs = 50 * 60 * 1000;
  if (
    cachedToken.value &&
    cachedToken.expiresAtMs > nowMs &&
    cachedToken.keyId === env.APNS_KEY_ID &&
    cachedToken.teamId === env.APNS_TEAM_ID
  ) {
    return cachedToken.value;
  }

  validateEnv(env);
  const privateKey = normalizePem(env.APNS_PRIVATE_KEY);
  const key = await importPKCS8(privateKey, "ES256");
  const issuedAt = Math.floor(nowMs / 1000);

  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APNS_KEY_ID })
    .setIssuer(env.APNS_TEAM_ID)
    .setIssuedAt(issuedAt)
    .sign(key);

  cachedToken = {
    value: token,
    expiresAtMs: nowMs + ttlMs,
    keyId: env.APNS_KEY_ID,
    teamId: env.APNS_TEAM_ID
  };
  return token;
}

function validateEnv(env) {
  for (const key of ["APNS_KEY_ID", "APNS_TEAM_ID", "APNS_BUNDLE_ID", "APNS_PRIVATE_KEY"]) {
    if (!env[key] || String(env[key]).trim() === "") {
      throw new Error(`missing_env_${key}`);
    }
  }
}

function hasRequiredApnsConfig(env) {
  for (const key of ["APNS_KEY_ID", "APNS_TEAM_ID", "APNS_BUNDLE_ID", "APNS_PRIVATE_KEY"]) {
    if (!env[key] || String(env[key]).trim() === "") {
      return false;
    }
  }
  return true;
}

function normalizePem(raw) {
  return String(raw).includes("\\n") ? String(raw).replace(/\\n/g, "\n") : String(raw);
}

function authorizeRequest(request, env) {
  if (!env.WAKE_API_KEY) return true;
  const headerValue = request.headers.get("x-deskboard-key");
  return !!headerValue && headerValue === env.WAKE_API_KEY;
}

function deviceKey(uuid) {
  return `device:${uuid}`;
}

async function readRecord(env, uuid) {
  const data = await env.DEVICE_STORE.get(deviceKey(uuid));
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
}

async function sha256Hex(value) {
  const data = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(digest);
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function isValidDeviceUUID(value) {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length >= 8 && trimmed.length <= 128;
}

function isValidToken(value, minLength, maxLength) {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length >= minLength && trimmed.length <= maxLength;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "content-type": "application/json",
      ...corsHeaders
    }
  });
}
