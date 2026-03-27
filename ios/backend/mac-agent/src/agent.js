const http = require('http');

const PORT = Number(process.env.PORT || 7799);

const capabilities = [
  'app.activate',
  'shell.exec',
  'keyboard.shortcut',
  'system.screenshot',
  'system.lock',
  'media.control'
];

const server = http.createServer((req, res) => {
  if (!req.url) {
    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'not_found' }));
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(
      JSON.stringify({
        ok: true,
        service: 'deskboard-mac-agent-scaffold',
        protocolVersion: 2
      })
    );
    return;
  }

  if (req.method === 'GET' && req.url === '/v1/capabilities') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(
      JSON.stringify({
        ok: true,
        service: 'deskboard-mac-agent-scaffold',
        protocolVersion: 2,
        capabilities
      })
    );
    return;
  }

  res.writeHead(404, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'not_found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  process.stdout.write(`[deskboard-mac-agent] scaffold listening on :${PORT}\n`);
});
