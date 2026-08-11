# okf-memory

A personal memory system: capture memories by voice or photo from an iPhone, store them
as an [OKF v0.2](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
bundle on a Mac mini, browse them in a native viewer, query them by voice with spoken
answers, and get reminders whose schedule is defined in the OKF data itself.

## Architecture

```
iPhone (SwiftUI app "Recall")
   │  HTTPS over Tailscale
   ▼
Mac mini — FastAPI server (launchd-managed)
   ├─ POST /api/capture        audio/photo → Whisper → GPT-5.6 → OKF concept files
   ├─ GET  /api/memories       OKF viewer data
   ├─ POST /api/query          voice question → GPT-5.6 over the bundle → TTS audio answer
   └─ GET  /api/notifications  schedule extracted from OKF frontmatter
   ▼
~/memories-okf — OKF v0.2 bundle (private git repo, auto-pushed)
```

- **Memories are OKF v0.2 concepts**: one markdown file per memory with YAML frontmatter
  (`type`, `title`, `tags`, `generated`, `sources`, `status`, …).
- **Notifications live in the data**: a memory may carry a `notifications:` list
  (`at` + `title` + `body`), written by GPT-5.6 when it thinks something is worth
  remembering. The iPhone app syncs that schedule and registers local notifications —
  no push servers involved.
- **Privacy split**: this repo holds only code. The memory bundle and `.env`
  (API keys, tokens) never leave the Mac mini except to a private repo.

## Server setup

```sh
cd server
uv sync
cp .env.example .env   # fill in OPENAI_API_KEY and API_TOKEN
uv run uvicorn app.main:app --port 8090
```

Run it permanently + expose over the tailnet:

```sh
scripts/install-launchd.sh
tailscale serve --bg --https=8443 http://127.0.0.1:8090
```

## iOS app

`ios/Recall` is an XcodeGen project (SwiftUI, iOS 17+):

```sh
scripts/deploy-ios.sh   # generates the project, builds, installs to the paired iPhone
```

Tabs: **Memories** (OKF viewer), **Capture** (voice / photo), **Ask** (voice Q → spoken A).

## Tests

```sh
cd server && uv run pytest
```
