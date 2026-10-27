# BLE Jarvis

**Your desk knows when you're there.** A presence-aware desk agent: your iPhone is a
Bluetooth LE beacon, your Mac notices you arrive — music swells, and an AI voice briefs
you on your calendar, your Jira board, and the news. Walk away and the agent keeps
working: triaging what piles up and drafting replies. Walk back and it tells you what
happened — and you answer with your voice.

Built solo for the **Meta Global AI Developer Hackathon** (Oct 27 – Nov 4, 2026),
Indie Developer track.

## Hackathon disclosure

- **Everything in this repository was built during the hackathon** (first commit
  Oct 27, 2026). No code was imported from prior projects.
- The author ships [LockZone](https://github.com/Majki1/lockzone-desk), a pre-existing
  app that blocks distracting iPhone apps near your Mac using BLE proximity. LockZone
  is the *origin story* for this idea — none of its code is used here. The BLE presence
  engine in this repo is a fresh implementation.

## Architecture

```
┌─────────────┐  BLE advertise   ┌──────────────────────────────┐
│  iPhone /    │ ───────────────▶ │  Mac menu-bar app (Swift)    │
│  Android     │                  │  • presence engine (arrive/  │
│  (React      │                  │    depart w/ grace window)   │
│  Native)     │ ◀──────────────  │  • agent runtime             │
│  beacon +    │   transcript /   │    Muse Spark Open (open     │
│  settings    │   config sync    │    weights) + tool calling   │
└─────────────┘                  │  • tools: Calendar, Jira,    │
                                  │    news                      │
                                  │  • audio: music + ElevenLabs │
                                  │    voice, Muse Voice         │
                                  │    Transcribe for replies    │
                                  └──────────────────────────────┘
```

**Meta models used:** Muse Spark Open (`muse-spark-open-1026`, via Baseten / local) as
the agent brain; Muse Voice Transcribe (Meta Model API) for spoken replies; Muse Spark
(Meta Model API) as a fallback brain.

## Repo layout

- `mobile/` — React Native (Expo) companion app: BLE beacon, pairing, connections
  (Google Calendar, Jira), voice & music settings, transcript history
- `mac/` — macOS menu-bar app (SwiftUI, XcodeGen): presence engine, agent runtime,
  audio engine

## Run it

### Mac
```bash
cd mac && xcodegen generate && open Jarvis.xcodeproj   # or: xcodebuild build -scheme Jarvis
```

### Mobile
```bash
cd mobile && npm install && npx expo run:ios   # or run:android
```

Configuration (API keys, OAuth setup) is documented as the features land — see the
issues/commits for day-by-day progress.
