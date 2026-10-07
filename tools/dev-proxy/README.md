# dev-proxy

Development-only proxy. Serves the Flutter dev server and the test API from one origin
(`http://localhost:8080`), because the API accepts only same-origin requests
(`docs/api-contract.md` §7.1). Not part of any deployment.

| Request | Goes to |
|---|---|
| `/api/*` | `https://test.opticode.com.tr/api/*` (`Host` and `Origin` rewritten; `Set-Cookie` passed through unchanged) |
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

Quick check that the API is reachable through the proxy:

```bash
curl -i http://localhost:8080/api/v1/health
```

Optional environment variables: `PORT` (8080), `APP_HOST` (localhost), `APP_PORT` (5000),
`API_ORIGIN` (`https://test.opticode.com.tr`).
