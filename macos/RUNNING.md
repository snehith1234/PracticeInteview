# Running & Stopping InterviewPracticeListener

This app has two parts that run together:

1. **Backend** — the existing FastAPI server (Python) on `http://localhost:8000`.
2. **macOS app** — the native floating assistant that talks to that backend.

The macOS app is a client: it needs the backend running to generate answers.

---

## First-time setup (once)

```bash
# From the repo root
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Then edit `backend/.env` and set a model your OpenAI project can access:

```env
OPENAI_API_KEY=sk-...your key...
DEFAULT_MODEL=gpt-4.1-mini
```

> Note: this project's key does **not** have access to `gpt-4o-mini`. Use
> `gpt-4.1-mini` (or another model listed in the app's Settings that your
> project can use). You can also pick the model in the app's ⚙ Settings.

---

## Run the complete application

Use **two terminals**.

### Terminal 1 — start the backend

```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

Leave this running. Verify it's up (in any terminal):

```bash
curl http://localhost:8000/
# -> {"status":"ok","app":"Interview Practice Listener"}
```

### Terminal 2 — start the macOS app

Build a proper app bundle (needed for microphone/speech permission prompts):

```bash
cd macos
./build-app.sh
open dist/InterviewPracticeListener.app
```

A translucent floating window appears (centered). It has **no Dock icon** — it's
a menu-bar-style accessory utility.

> Quick dev alternative (no permission prompts, UI/testing only):
> `cd macos && swift run InterviewPracticeListener`

### Using it

1. Click the ⚙ gear → set **Model** (e.g. `gpt-4.1-mini`), fill **Role**,
   **Job Description**, upload/paste **Resume**, then **Done**.
2. Click **Start Listening** and grant **Microphone** + **Speech Recognition**
   on first use.
3. Speak a question, pause ~2s → the answer generates automatically. Or type a
   question under "Or type a question / transcript" and click **Generate**.

### Global shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧Space | Show / hide the window |
| ⌘⇧L | Start / stop listening |
| ⌘⇧C | Compact / expanded mode |

---

## Stop the application

### Stop the macOS app

- In the app: click the **–** (hide) only hides it. To fully quit, use the
  terminal command below (it has no Dock icon to right-click).

```bash
pkill -f InterviewPracticeListener
```

### Stop the backend

- If it's running in Terminal 1: press **Ctrl + C** there.
- If it's detached / you don't have the terminal:

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN -t | xargs kill
```

Verify the port is free:

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN || echo "backend stopped, port 8000 free"
```

### Stop both at once

```bash
cd macos
./stop-macos.sh
```

---

## Troubleshooting

- **"address already in use" on port 8000** — a previous backend is still
  running. Stop it: `lsof -nP -iTCP:8000 -sTCP:LISTEN -t | xargs kill`.
- **App window not visible** — press **⌘⇧Space**, or relaunch with
  `open dist/InterviewPracticeListener.app`.
- **Answers say "mock"** — no `OPENAI_API_KEY` in `backend/.env`, or the backend
  wasn't restarted after adding it. Restart Terminal 1.
- **`model_not_found` / 403** — the selected model isn't available to your
  OpenAI project. Choose `gpt-4.1-mini` in ⚙ Settings or set it as
  `DEFAULT_MODEL` in `backend/.env`.
- **No microphone/speech prompt** — run the `.app` bundle (`./build-app.sh` →
  `open ...`), not `swift run`. Permissions require the bundle's Info.plist.

- **Screenshot only shows the desktop wallpaper (no windows)** — Screen
  Recording permission isn't granted yet. macOS blanks out other apps' windows
  until you allow it. Fix: System Settings › Privacy & Security › Screen
  Recording → enable **InterviewPracticeListener**, then **fully quit and
  relaunch the app** (macOS applies this permission only on a fresh launch).
  Screenshots are saved to `~/Pictures/InterviewPracticeListener/`.

- **"Could not start microphone" / avfaudio error 1937010544 (`kAUStartIO`)** —
  this is a stuck macOS Core Audio driver, **not** an app or permission problem
  (the mic permission can be granted and the app still hit this). It commonly
  happens after using apps that install a virtual audio device — especially
  **Microsoft Teams** (`MSTeamsAudioDevice.driver`), Zoom, or when **Voice
  Control / Dictation** is holding the mic. Fix:

  1. Quit Teams/Zoom fully (⌘Q) and turn off Voice Control
     (System Settings › Accessibility › Voice Control) and Dictation
     (System Settings › Keyboard › Dictation).
  2. Restart the Core Audio daemon:

     ```bash
     sudo killall coreaudiod
     ```

     Audio blips for ~2 seconds and recovers. Then click Start Listening again.

  To confirm the mic itself works (independent of the app), a valid input device
  should show under `system_profiler SPAudioDataType` and any AVAudioEngine
  program should start after the `coreaudiod` restart.
