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

The game features a complete, production-polished user flow:
1. **Login Screen (`/`)**: Premium dark UI featuring animated floating card suits. Supports Guest Login (with caching via `SharedPreferences`), official Google Sign-In button with 15s watchdog protection, and mandatory unique username registration.
2. **Lobby Screen (`/lobby`)**: Features action cards for Ranked Match (solo or party duo queue with 10s bot fallback), Bot Combat (Practice), and Custom Match Salon. Includes real-time Friends panel, presence badges, incoming toasts, and seasonal Leaderboards.
3. **Custom Match Salon**: 4-player room topology with dynamic seat role indicators: **Teammate** (Seat 3, opposite you, emerald highlight) and **Opponents** (Seats 2 and 4). Supports direct code join and VIP in-room friend invitations.
4. **Rules & Tutorial**: Interactive How-to-Play tutorial and scrollable bottom sheet detailing trick rules, 10s protection, and power suit selection.
5. **Game Screen (`/game`)**: Royal Casino green felt oval table with score pill on top (`Tens / Cards / Aces`), fanned cards along the bottom, first-tap play guarantee, power-select timeout auto-pick watchdog (CR-1), and browser back button quit-proofing via `PopScope` (CR-4).
6. **Win Screen**: Enhanced `MatchResultOverlay` with pulsing gold glow, animated score counters, confetti for winners, empathetic defeat messaging, and post-match "Add Friend" buttons.

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
