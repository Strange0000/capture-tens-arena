# Capture Tens Arena

Production-oriented real-time multiplayer mobile card game inspired by Call Break, Bridge, and Spades, with a unique "Capture the Tens" objective.

## Stack

- **Mobile client:** Flutter (v3.32.1 stable)
- **Backend:** Node.js, Express, Socket.IO, TypeScript
- **Database:** MongoDB
- **Cache and presence:** Redis
- **Auth:** JWT, Google login hook, guest login
- **Infra:** Docker Compose plus Kubernetes manifests

## Monorepo Layout

```text
capture-tens-arena/
  backend/          Server-authoritative API, sockets, game engine, bots
  frontend/         Flutter mobile app
  docs/             API, socket, deployment, gameplay docs
  k8s/              Kubernetes-ready manifests
  docker-compose.yml
  .env.example
```

## Quick Start

### Backend

```bash
cd capture-tens-arena
cp .env.example .env
docker compose up --build
```
Backend runs on `http://localhost:8080`.

### Flutter Client

```bash
cd capture-tens-arena/frontend
flutter pub get
flutter run -d chrome
```

## Features Implemented

### Game Flow

The game now features a complete, polished user flow:
1. **Login Screen (`/`)**: A premium dark UI featuring an animated floating card suit background and a pulsing gradient logo. Supports Guest Login (with caching via `SharedPreferences`) and a placeholder for Google Sign-In.
2. **Lobby Screen (`/lobby`)**: A dedicated screen replacing the old home screen. Features premium action cards for Ranked Match, Bot Match, and a Private Room expandable panel. Includes Queue/Room status banners and player Rank panel.
3. **Rules Overlay**: A scrollable bottom sheet accessible from the Lobby and Game screens, detailing all game rules with icons and clear sections.
4. **Game Screen (`/game`)**: The main gameplay area. Features a custom slide-up and fade entry transition. The player's hand enters with a staggered slide-up animation. 
5. **Win Screen**: Enhanced `MatchResultOverlay` with a pulsing gold glow behind a trophy, animated score counters (counting up from zero), extended 6-second confetti for winners, and empathetic messages for defeat.

### UI & Animations

- **Game Table**: Trick area transitions and player badges have been slowed down (500ms and 400ms respectively) using `easeInOutCubic` curves for a much smoother, polished feel.
- **Trick Area**: Cards played to the trick now smoothly slide in from the respective player's seat direction (top, bottom, left, right) with scale and fade animations using an `easeOutBack` curve.
- **Card Widget (`ArenaCardWidget`)**: Added a tactile tap-to-shrink animation (press to scale down to 92%, release to bounce back).

## Game Rules Summary

- **Objective**: Capture the most 10s. Tiebreakers: captured card count, then captured aces.
- **Teams**: Four players only, fixed teams: seats `0 + 2` versus `1 + 3`.
- **Deck**: Standard 52-card deck.
- **Power Suit (Trump)**: Highest lead suit wins unless power cards are played, then highest power suit wins.
- **Must Follow**: Players must follow the lead suit when possible.
- **Must Play Higher**: If following the lead suit, you must play a higher card than the current highest, unless your teammate is currently winning the trick.
- **10s Protection**: You cannot discard an off-suit 10 unless you have 3 or fewer cards remaining in your hand.
- **First Trick Restriction**: No power suit and no 10s on the first trick unless the player has no other legal card.

## Included Systems

- Server-authoritative rules engine
- Socket.IO room lifecycle
- Matchmaking queue and private room codes
- Reconnect and idle timeout handling
- Replay recording and deterministic playback events
- AI bots with easy, medium, and hard strategy layers
- Ranked MMR and seasonal leaderboard services
- Mongo schemas for users, matches, rankings, friends, achievements, replays, and statistics
- Flutter screens with complete navigation (login, lobby, table play, profile, replay)
- Docker Compose and Kubernetes deployment baseline
- Unit tests for rule validation and match resolution

## Production Notes

This repository is a full implementation scaffold designed to be extended with store-specific login setup, production payment or rewards systems, and real audio/art asset packs. Server gameplay is authoritative and the client never decides legal moves, scoring, or hidden information.
