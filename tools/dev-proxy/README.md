# dev-proxy

Development-only proxy. Serves the Flutter dev server and the test API from one origin
(`http://localhost:8080`), because the API accepts only same-origin requests
(`docs/api-contract.md` §7.1). Not part of any deployment.

| Request | Goes to |
|---|---|
| `/api/*` | `https://test.opticode.com.tr/api/*` (`Host` and `Origin` rewritten; `Set-Cookie` passed through unchanged) |
| WebSocket upgrade outside `/api` | tunnelled to `http://localhost:5000` (hot reload / hot restart) |
| everything else | `http://localhost:5000` (Flutter web-server) |

Chrome treats `localhost` as a secure context, so the `Secure` refresh cookie is accepted.

## Run

Needs Node 18+. No dependencies to install. Two terminals, from the repo root:

```bash
# 1. Flutter dev server (real API mode: no USE_MOCK; config.json says useMock=false)
flutter run -d web-server --web-port 5000

# 2. Proxy
node tools/dev-proxy
```

Open `http://localhost:8080` (not `:5000`).

Hot reload and hot restart (`r` / `R` in the `flutter run` terminal) work through the proxy: the
Flutter dev server's WebSocket is tunnelled, and when a browser tab goes away its upstream
connection is closed too, so the dev server does not wait for dead clients. `/api` needs no
WebSocket. If a hot restart times out, restart the proxy and reload the page once; the proxy logs
`[proxy] upgrade <path>` for every tunnelled WebSocket, so you can see whether the browser's
connection arrives.

Quick check that the API is reachable through the proxy:

```bash
curl -i http://localhost:8080/api/v1/health
```

Optional environment variables: `PORT` (8080), `APP_HOST` (localhost), `APP_PORT` (5000),
`API_ORIGIN` (`https://test.opticode.com.tr`).
