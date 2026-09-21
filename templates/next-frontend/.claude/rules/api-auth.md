# Rule — authenticated API calls

Referenced by `CLAUDE.md`.

- **A single wrapper** (`fetchWithAuth`, imported from `@/api/auth/fetch-with-auth`) for every
  endpoint needing credentials. Never a raw `fetch` with `credentials: "include"`.
- That wrapper owns token refresh: on a 401 `token_expired` it refreshes and replays the original
  request. No caller writes retry logic — which is the point, because the fifth caller would
  write it slightly differently.
- Real-time streams use the native `EventSource`. No third-party library for something the
  platform ships.
