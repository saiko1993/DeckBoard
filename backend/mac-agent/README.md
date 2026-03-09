# DeskBoard macOS Agent (Scaffold)

This folder is a **scaffold** for the future native-aligned macOS execution agent.

Current scope:
- `GET /health`
- `GET /v1/capabilities`

Run:

```bash
cd backend/mac-agent
npm install
npm start
```

This service is intentionally minimal and non-invasive. It is used to keep the migration path from Node relay to a richer macOS agent clear and incremental.
