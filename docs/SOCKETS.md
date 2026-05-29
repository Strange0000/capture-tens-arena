# Socket.IO Events

All socket connections require auth:

```js
io("http://localhost:8080", { auth: { token } });
```

## Client To Server

`queue:ranked`

```json
{ "mmr": 1000 }
```

Adds the user to ranked matchmaking.

`room:create`

Creates a private room code.

`room:join`

```json
{ "code": "ABC123" }
```

Joins a private room. Match starts when 4 players are present.

`bot:offline`

```json
{ "difficulty": "hard" }
```

Starts an offline game with three bots.

`power:select`

```json
{ "matchId": "match", "suit": "spades" }
```

Only the first player can select power suit after the first five cards.

`card:play`

```json
{ "matchId": "match", "cardId": "10-spades" }
```

Server validates hand ownership, turn order, follow-suit rules, first-trick restrictions, and trick winner.

`spectate:join`

```json
{ "matchId": "match" }
```

Joins public spectator state without hidden hands.

## Server To Client

`queue:joined`

`room:created`

`room:joined`

`match:created`

`match:state`

Private state for a seated player. Includes only that player's hand.

`match:spectatorState`

Public state for spectators. Includes no hidden hand data.
