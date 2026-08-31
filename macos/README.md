# InterviewPracticeListener — macOS App

A native macOS floating assistant that reuses the **existing FastAPI backend**
and its **existing answer pipeline** unchanged. This is a presentation/
integration layer only — no prompts, model calls, or answer-generation logic
were modified.

```
Native macOS app (SwiftUI + AppKit NSPanel)
        │  HTTP / SSE  (same endpoints the browser uses)
        ▼
Existing FastAPI backend  →  existing prompts / LLM / answer pipeline
```

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ toolchain (Xcode 15+ recommended for the native window/permissions)
- The existing Python backend running locally

## Run (development)

Terminal 1 — start the existing backend (same command as the repo README):

```bash
cd backend
python -m venv venv && source venv/bin/activate   # first time only
pip install -r requirements.txt                    # first time only
cp .env.example .env                                # first time only
uvicorn app.main:app --reload --port 8000
```

Terminal 2 — build and run the macOS app:

```bash
cd macos
swift run InterviewPracticeListener
# or use the helper:
./dev-macos.sh
```

> Running via `swift run` launches the raw executable. macOS permission prompts
> (microphone / speech) show their usage strings reliably from a proper `.app`
> bundle — build one with `./build-app.sh` (below) for the full experience.

## Build a distributable `.app`

```bash
cd macos
./build-app.sh
open dist/InterviewPracticeListener.app
```

Output: `macos/dist/InterviewPracticeListener.app` (ad-hoc signed for local use).

## Open in Xcode

```bash
cd macos
open Package.swift        # opens the Swift package in Xcode
```

Select the `InterviewPracticeListener` scheme and Run. For permissions to work
from Xcode, set the target's Info.plist to `macos/Support/Info.plist` (or copy
the two `NS…UsageDescription` keys into the target's Info settings).

## Permissions (why each is needed)

| Permission | Info.plist key | Reason |
|-----------|----------------|--------|
| Microphone | `NSMicrophoneUsageDescription` | Capture interview-question audio via `AVAudioEngine`. |
| Speech Recognition | `NSSpeechRecognitionUsageDescription` | Convert audio to a transcript via `SFSpeechRecognizer` (replaces the browser's `webkitSpeechRecognition`, which does not exist natively). |

No other permissions are requested. The app does **not** implement any
screen-capture exclusion or stealth behavior.

## Global shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧Space | Show / hide the assistant |
| ⌘⇧L | Start / stop listening |
| ⌘⇧C | Toggle compact / expanded |

## What talks to the backend (unchanged endpoints)

| App action | Endpoint | Notes |
|-----------|----------|-------|
| Quick Answer ("Say This Now") | `POST /coach/quick-short` (SSE) | Phase 1 |
| Full sections (30s / Example / Strong / follow-ups) | `POST /coach/quick-answer` (SSE) | Phase 2, sends `quick_answer` exactly like the browser |
| Analyze Resume + JD | `POST /coach/profile` | |
| Resume / context upload | `POST /upload/resume`, `/upload/context` | |
| Test model | `POST /coach/test-llm` | |

## App signing (for distribution)

The dev bundle is ad-hoc signed (`codesign --sign -`), which is fine on your own
machine. To share the app, sign with a Developer ID certificate and notarize:

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/InterviewPracticeListener.app
xcrun notarytool submit ... && xcrun stapler staple dist/InterviewPracticeListener.app
```

## Not changed

The browser frontend (`frontend/`) and the backend (`backend/`) are untouched
and remain the behavioral reference. Answer synchronization, prompts, silence
thresholds, question detection, and model calls are all preserved as-is.
```
