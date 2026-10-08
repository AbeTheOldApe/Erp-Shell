'use strict';

// Development-only proxy (docs/api-contract.md section 7.1).
//   /api/*  -> https://test.opticode.com.tr (Host/Origin rewritten, Set-Cookie untouched)
//   others  -> http://localhost:5000 (flutter run -d web-server --web-port 5000)
// No dependencies: uses only Node built-ins.

const http = require('node:http');
const https = require('node:https');
const net = require('node:net');

const LISTEN_PORT = Number(process.env.PORT || 8080);
const API_ORIGIN = new URL(process.env.API_ORIGIN || 'https://test.opticode.com.tr');
const APP_HOST = process.env.APP_HOST || 'localhost';
const APP_PORT = Number(process.env.APP_PORT || 5000);

function forward(req, res, { transport, host, port, rewriteHeaders }) {
  const headers = rewriteHeaders({ ...req.headers });
  const upstream = transport.request(
    { host, port, method: req.method, path: req.url, headers },
    (up) => {
      // Headers (including every Set-Cookie) are passed through as received.
      res.writeHead(up.statusCode || 502, up.statusMessage, up.rawHeaders);
      up.pipe(res);
    },
  );
  upstream.on('error', (err) => {
    console.error(`[proxy] ${req.method} ${req.url} -> ${host}:${port}: ${err.message}`);
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' });
    res.end(`Bad gateway: ${err.message}`);
  });
  // A browser that goes away (reload, closed tab) must not leave its upstream
  // connection behind: the Flutter dev server keeps counting such clients and
  // hot restart then waits for answers that never come.
  res.on('close', () => upstream.destroy());
  req.pipe(upstream);
}

const server = http.createServer((req, res) => {
  if (req.url === '/api' || req.url.startsWith('/api/')) {
    forward(req, res, {
      transport: API_ORIGIN.protocol === 'https:' ? https : http,
      host: API_ORIGIN.hostname,
      port: Number(API_ORIGIN.port) || (API_ORIGIN.protocol === 'https:' ? 443 : 80),
      rewriteHeaders: (h) => {
        h.host = API_ORIGIN.host;
        if (h.origin) h.origin = API_ORIGIN.origin;
        if (h.referer) h.referer = API_ORIGIN.origin + new URL(h.referer).pathname;
        return h;
      },
    });
    return;
  }
  forward(req, res, {
    transport: http,
    host: APP_HOST,
    port: APP_PORT,
    rewriteHeaders: (h) => h,
  });
});

// Flutter's dev server uses a WebSocket for hot reload/hot restart; every
// upgrade request outside /api is tunnelled to it (the API needs none).
server.on('upgrade', (req, socket, head) => {
  if (req.url === '/api' || req.url.startsWith('/api/')) {
    socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');
    return;
  }
  console.log(`[proxy] upgrade ${req.url} -> ${APP_HOST}:${APP_PORT}`);
  socket.setNoDelay(true);
  const upstream = net.connect(APP_PORT, APP_HOST, () => {
    upstream.setNoDelay(true);
    const lines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      lines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
    }
    upstream.write(lines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) upstream.write(head);
    socket.pipe(upstream);
    upstream.pipe(socket);
  });
  // Either side closing closes the other, so no half-open tunnels remain.
  upstream.on('error', (err) => {
    console.error(`[proxy] upgrade ${req.url}: ${err.message}`);
    socket.destroy();
  });
  upstream.on('close', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
  socket.on('close', () => upstream.destroy());
});

server.listen(LISTEN_PORT, 'localhost', () => {
  console.log(`dev-proxy: http://localhost:${LISTEN_PORT}`);
  console.log(`  /api/*  -> ${API_ORIGIN.origin}`);
  console.log(`  others  -> http://${APP_HOST}:${APP_PORT}`);
});
