const http = require('http');
const { execFile } = require('child_process');

const PORT = Number(process.env.PORT || 7788);
const API_KEY = process.env.DESKBOARD_API_KEY || '';
const MAX_BODY_BYTES = 256 * 1024;
const PROTOCOL_VERSION = 2;
const SERVICE_VERSION = '1.1.0';
const IDEMPOTENCY_TTL_MS = 2 * 60 * 1000;

const startedAtMs = Date.now();
const idempotencyCache = new Map();

const APP_NAME_BY_ID = {
  youtube: 'YouTube',
  chrome: 'Google Chrome',
  safari: 'Safari',
  notes: 'Notes',
  mail: 'Mail',
  calendar: 'Calendar',
  reminders: 'Reminders',
  terminal: 'Terminal',
  slack: 'Slack',
  zoom: 'zoom.us',
  teams: 'Microsoft Teams',
  spotify: 'Spotify',
  figma: 'Figma',
  notion: 'Notion',
  xcode: 'Xcode',
  vscode: 'Visual Studio Code',
  finder: 'Finder',
  system_settings: 'System Settings',
  activity_monitor: 'Activity Monitor',
  console: 'Console',
  keynote: 'Keynote',
  pages: 'Pages',
  numbers: 'Numbers',
  telegram: 'Telegram',
  whatsapp: 'WhatsApp'
};

const SPECIAL_KEY_CODES = {
  return: 36,
  enter: 36,
  tab: 48,
  space: 49,
  delete: 51,
  escape: 53,
  esc: 53,
  left: 123,
  right: 124,
  down: 125,
  up: 126
};

const MODIFIER_MAP = {
  cmd: 'command down',
  command: 'command down',
  shift: 'shift down',
  option: 'option down',
  alt: 'option down',
  ctrl: 'control down',
  control: 'control down'
};

const ACTION_CAPABILITIES = [
  'open_url',
  'open_deep_link',
  'send_text',
  'open_app',
  'run_shortcut',
  'run_script',
  'keyboard_shortcut',
  'toggle_dark_mode',
  'screenshot',
  'screen_record',
  'sleep_display',
  'lock_screen',
  'open_terminal',
  'force_quit_app',
  'empty_trash',
  'toggle_dnd',
  'presentation_next',
  'presentation_previous',
  'presentation_start',
  'presentation_end',
  'media_play',
  'media_pause',
  'media_play_pause',
  'media_next',
  'media_previous',
  'media_volume_up',
  'media_volume_down',
  'media_mute',
  'macro'
];

const CAPABILITY_METADATA = {
  open_url: { category: 'general', foregroundRequired: false },
  open_deep_link: { category: 'general', foregroundRequired: false },
  send_text: { category: 'general', foregroundRequired: false },
  open_app: { category: 'apps', foregroundRequired: false },
  run_shortcut: { category: 'shortcuts', foregroundRequired: false },
  run_script: { category: 'shortcuts', foregroundRequired: false },
  keyboard_shortcut: { category: 'keyboard', foregroundRequired: false },
  toggle_dark_mode: { category: 'device', foregroundRequired: false },
  screenshot: { category: 'device', foregroundRequired: false },
  screen_record: { category: 'device', foregroundRequired: false },
  sleep_display: { category: 'device', foregroundRequired: false },
  lock_screen: { category: 'device', foregroundRequired: false },
  open_terminal: { category: 'apps', foregroundRequired: false },
  force_quit_app: { category: 'device', foregroundRequired: false },
  empty_trash: { category: 'device', foregroundRequired: false },
  toggle_dnd: { category: 'device', foregroundRequired: false },
  presentation_next: { category: 'presentation', foregroundRequired: false },
  presentation_previous: { category: 'presentation', foregroundRequired: false },
  presentation_start: { category: 'presentation', foregroundRequired: false },
  presentation_end: { category: 'presentation', foregroundRequired: false },
  media_play: { category: 'media', foregroundRequired: false },
  media_pause: { category: 'media', foregroundRequired: false },
  media_play_pause: { category: 'media', foregroundRequired: false },
  media_next: { category: 'media', foregroundRequired: false },
  media_previous: { category: 'media', foregroundRequired: false },
  media_volume_up: { category: 'media', foregroundRequired: false },
  media_volume_down: { category: 'media', foregroundRequired: false },
  media_mute: { category: 'media', foregroundRequired: false },
  macro: { category: 'macro', foregroundRequired: false }
};

function sendJSON(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body)
  });
  res.end(body);
}

function logEvent(level, message, details = {}) {
  const row = {
    ts: new Date().toISOString(),
    level,
    msg: message,
    ...details
  };
  process.stdout.write(`${JSON.stringify(row)}\n`);
}

function readJSON(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;

    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        reject(new Error('Request body too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8').trim();
        resolve(raw ? JSON.parse(raw) : {});
      } catch (error) {
        reject(new Error('Invalid JSON body'));
      }
    });

    req.on('error', (error) => {
      reject(error);
    });
  });
}

function requireAuth(req) {
  if (!API_KEY) {
    return true;
  }
  const incoming = req.headers['x-deskboard-key'];
  return typeof incoming === 'string' && incoming === API_KEY;
}

function runFile(file, args, timeout = 15000) {
  return new Promise((resolve, reject) => {
    execFile(file, args, { timeout }, (error, stdout, stderr) => {
      if (error) {
        const message = (stderr || error.message || 'Command failed').trim();
        reject(new Error(message));
        return;
      }
      resolve({
        stdout: String(stdout || '').trim(),
        stderr: String(stderr || '').trim()
      });
    });
  });
}

function runAppleScript(script) {
  return runFile('/usr/bin/osascript', ['-e', script]);
}

function runShortcutByName(name) {
  const value = String(name || '').trim();
  if (!value) {
    throw new Error('Missing shortcut name');
  }
  return runFile('/usr/bin/shortcuts', ['run', value]);
}

function normalizeModifierList(modifiers) {
  if (!Array.isArray(modifiers)) {
    return [];
  }
  return modifiers
    .map((item) => String(item || '').trim().toLowerCase())
    .map((item) => MODIFIER_MAP[item])
    .filter(Boolean);
}

function buildKeystrokeScript(keyValue, modifiers) {
  const key = String(keyValue || '').trim();
  if (!key) {
    throw new Error('Missing keyboard shortcut key');
  }

  const normalizedMods = normalizeModifierList(modifiers);
  const modsScript = normalizedMods.length > 0 ? ` using {${normalizedMods.join(', ')}}` : '';

  const lower = key.toLowerCase();
  if (SPECIAL_KEY_CODES[lower] !== undefined) {
    return `tell application "System Events" to key code ${SPECIAL_KEY_CODES[lower]}${modsScript}`;
  }

  const escaped = key.replace(/"/g, '\\"');
  return `tell application "System Events" to keystroke "${escaped}"${modsScript}`;
}

function pruneIdempotencyCache() {
  const now = Date.now();
  for (const [key, record] of idempotencyCache.entries()) {
    if (record.expiresAtMs <= now) {
      idempotencyCache.delete(key);
    }
  }
}

async function executeAction(action) {
  const kind = String(action.kind || '').trim();
  if (!ACTION_CAPABILITIES.includes(kind)) {
    return { ok: false, error: `Unsupported action kind: ${kind}`, errorCode: 'unsupported_action' };
  }

  switch (kind) {
    case 'none':
      return { ok: false, error: 'No action', errorCode: 'empty_action' };

    case 'open_url':
    case 'open_deep_link': {
      const value = String(action.value || '').trim();
      if (!value) {
        throw new Error('Missing URL value');
      }
      await runFile('/usr/bin/open', [value]);
      return { ok: true, detail: `Opened ${value}` };
    }

    case 'send_text': {
      const value = String(action.value || '').trim();
      await runAppleScript(`set the clipboard to \"${value.replace(/\"/g, '\\\\\"')}\"`);
      return { ok: true, detail: 'Copied text to clipboard' };
    }

    case 'open_app': {
      const appID = String(action.appID || '').trim();
      if (!appID) {
        throw new Error('Missing appID');
      }
      const appName = APP_NAME_BY_ID[appID] || appID;
      await runFile('/usr/bin/open', ['-a', appName]).catch(async () => {
        await runFile('/usr/bin/open', [appID]);
      });
      return { ok: true, detail: `Opened ${appName}` };
    }

    case 'run_shortcut':
    case 'run_script': {
      const shortcutName = String(action.value || '').trim();
      await runShortcutByName(shortcutName);
      return { ok: true, detail: `Ran shortcut ${shortcutName}` };
    }

    case 'open_terminal': {
      await runFile('/usr/bin/open', ['-a', 'Terminal']);
      return { ok: true, detail: 'Opened Terminal' };
    }

    case 'force_quit_app': {
      const script = [
        'tell application "System Events"',
        'set frontApp to name of first application process whose frontmost is true',
        'end tell',
        'if frontApp is not "Finder" then',
        'tell application frontApp to quit',
        'end if'
      ].join('\n');
      await runAppleScript(script);
      return { ok: true, detail: 'Quit front app' };
    }

    case 'empty_trash': {
      await runAppleScript('tell application "Finder" to empty the trash');
      return { ok: true, detail: 'Trash emptied' };
    }

    case 'toggle_dnd': {
      await runShortcutByName('Toggle Do Not Disturb');
      return { ok: true, detail: 'Toggled Do Not Disturb' };
    }

    case 'screen_record': {
      await runShortcutByName('Toggle Screen Recording');
      return { ok: true, detail: 'Toggled screen recording' };
    }

    case 'presentation_next': {
      await runAppleScript('tell application "System Events" to key code 124');
      return { ok: true, detail: 'Next slide' };
    }

    case 'presentation_previous': {
      await runAppleScript('tell application "System Events" to key code 123');
      return { ok: true, detail: 'Previous slide' };
    }

    case 'presentation_start': {
      await runShortcutByName('Start Presentation');
      return { ok: true, detail: 'Presentation started' };
    }

    case 'presentation_end': {
      await runShortcutByName('End Presentation');
      return { ok: true, detail: 'Presentation ended' };
    }

    case 'keyboard_shortcut': {
      const script = buildKeystrokeScript(action.key, action.modifiers);
      await runAppleScript(script);
      return { ok: true, detail: 'Sent keyboard shortcut' };
    }

    case 'toggle_dark_mode': {
      const script = [
        'tell application "System Events"',
        'tell appearance preferences',
        'set dark mode to not dark mode',
        'end tell',
        'end tell'
      ].join('\n');
      await runAppleScript(script);
      return { ok: true, detail: 'Toggled dark mode' };
    }

    case 'screenshot': {
      const fileName = `DeskBoard-${Date.now()}.png`;
      await runFile('/usr/sbin/screencapture', ['-x', `~/Desktop/${fileName}`]);
      return { ok: true, detail: `Saved ${fileName} on Desktop` };
    }

    case 'sleep_display': {
      await runFile('/usr/bin/pmset', ['displaysleepnow']);
      return { ok: true, detail: 'Display sleep command sent' };
    }

    case 'lock_screen': {
      await runAppleScript('tell application "System Events" to keystroke "q" using {control down, command down}');
      return { ok: true, detail: 'Lock screen command sent' };
    }

    case 'media_play': {
      await runAppleScript('tell application "Music" to play');
      return { ok: true, detail: 'Music play' };
    }

    case 'media_pause': {
      await runAppleScript('tell application "Music" to pause');
      return { ok: true, detail: 'Music pause' };
    }

    case 'media_play_pause': {
      await runAppleScript('tell application "Music" to playpause');
      return { ok: true, detail: 'Music play/pause' };
    }

    case 'media_next': {
      await runAppleScript('tell application "Music" to next track');
      return { ok: true, detail: 'Music next' };
    }

    case 'media_previous': {
      await runAppleScript('tell application "Music" to previous track');
      return { ok: true, detail: 'Music previous' };
    }

    case 'media_volume_up': {
      await runAppleScript('set volume output volume ((output volume of (get volume settings)) + 6)');
      return { ok: true, detail: 'Volume up' };
    }

    case 'media_volume_down': {
      await runAppleScript('set volume output volume ((output volume of (get volume settings)) - 6)');
      return { ok: true, detail: 'Volume down' };
    }

    case 'media_mute': {
      await runAppleScript('set volume with output muted');
      return { ok: true, detail: 'Muted' };
    }

    case 'macro': {
      const actions = Array.isArray(action.actions) ? action.actions : [];
      for (const step of actions) {
        const result = await executeAction(step);
        if (!result.ok) {
          return result;
        }
      }
      return { ok: true, detail: `Macro executed (${actions.length} steps)` };
    }

    default:
      return { ok: false, error: `Unsupported action kind: ${kind}`, errorCode: 'unsupported_action' };
  }
}

async function handleExecute(req, res) {
  if (!requireAuth(req)) {
    sendJSON(res, 401, { ok: false, error: 'Unauthorized', errorCode: 'unauthorized' });
    return;
  }

  let body;
  try {
    body = await readJSON(req);
  } catch (error) {
    sendJSON(res, 400, { ok: false, error: error.message, errorCode: 'invalid_json' });
    return;
  }

  const action = body && typeof body === 'object' ? body.action : null;
  if (!action || typeof action !== 'object') {
    sendJSON(res, 400, { ok: false, error: 'Missing action object', errorCode: 'missing_action' });
    return;
  }

  const traceID = String(body.traceID || req.headers['x-trace-id'] || '').trim() || 'trace-unknown';
  const idempotencyKey = String(body.idempotencyKey || req.headers['x-idempotency-key'] || '').trim();
  const reason = body.reason || null;
  const sourceDeviceName = body.sourceDeviceName || null;
  const attempt = Number(body.attempt || 1) > 0 ? Number(body.attempt) : 1;

  pruneIdempotencyCache();

  if (idempotencyKey && idempotencyCache.has(idempotencyKey)) {
    const cached = idempotencyCache.get(idempotencyKey);
    sendJSON(res, cached.statusCode, {
      ...cached.payload,
      deduplicated: true
    });
    return;
  }

  const startedMs = Date.now();

  try {
    const result = await executeAction(action);
    const latencyMs = Date.now() - startedMs;
    if (result.ok) {
      const payload = {
        ok: true,
        detail: result.detail || null,
        reason,
        sourceDeviceName,
        traceID,
        executor: 'mac_relay',
        latencyMs,
        protocolVersion: PROTOCOL_VERSION
      };
      if (idempotencyKey) {
        idempotencyCache.set(idempotencyKey, {
          statusCode: 200,
          payload,
          expiresAtMs: Date.now() + IDEMPOTENCY_TTL_MS
        });
      }
      logEvent('info', 'relay_execute_success', { traceID, action: action.kind, latencyMs, attempt });
      sendJSON(res, 200, payload);
    } else {
      const payload = {
        ok: false,
        error: result.error || 'Action failed',
        errorCode: result.errorCode || 'execution_failed',
        traceID,
        executor: 'mac_relay',
        latencyMs,
        protocolVersion: PROTOCOL_VERSION
      };
      if (idempotencyKey) {
        idempotencyCache.set(idempotencyKey, {
          statusCode: 422,
          payload,
          expiresAtMs: Date.now() + IDEMPOTENCY_TTL_MS
        });
      }
      logEvent('warn', 'relay_execute_rejected', { traceID, action: action.kind, latencyMs, attempt, errorCode: payload.errorCode });
      sendJSON(res, 422, payload);
    }
  } catch (error) {
    const latencyMs = Date.now() - startedMs;
    const payload = {
      ok: false,
      error: error.message || 'Execution failed',
      errorCode: 'execution_exception',
      traceID,
      executor: 'mac_relay',
      latencyMs,
      protocolVersion: PROTOCOL_VERSION
    };
    if (idempotencyKey) {
      idempotencyCache.set(idempotencyKey, {
        statusCode: 500,
        payload,
        expiresAtMs: Date.now() + IDEMPOTENCY_TTL_MS
      });
    }
    logEvent('error', 'relay_execute_error', { traceID, action: action.kind, latencyMs, attempt, error: payload.error });
    sendJSON(res, 500, payload);
  }
}

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    sendJSON(res, 404, { ok: false, error: 'Not found' });
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    pruneIdempotencyCache();
    sendJSON(res, 200, {
      ok: true,
      service: 'deskboard-mac-receiver',
      serviceVersion: SERVICE_VERSION,
      protocolVersion: PROTOCOL_VERSION,
      readiness: {
        apiKeyConfigured: API_KEY.length > 0,
        capabilitiesCount: ACTION_CAPABILITIES.length,
        idempotencyCacheSize: idempotencyCache.size
      },
      uptimeSeconds: Math.floor((Date.now() - startedAtMs) / 1000)
    });
    return;
  }

  if (req.method === 'GET' && req.url === '/v1/capabilities') {
    sendJSON(res, 200, {
      ok: true,
      service: 'deskboard-mac-receiver',
      serviceVersion: SERVICE_VERSION,
      protocolVersion: PROTOCOL_VERSION,
      capabilities: ACTION_CAPABILITIES,
      metadata: CAPABILITY_METADATA
    });
    return;
  }

  if (req.method === 'POST' && req.url === '/v1/execute') {
    await handleExecute(req, res);
    return;
  }

  sendJSON(res, 404, { ok: false, error: 'Not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  process.stdout.write(`[deskboard-mac-receiver] listening on :${PORT}\n`);
});
