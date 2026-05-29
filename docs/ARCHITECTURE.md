# Architecture

## Server Authority

The backend owns all important game state:

- Deck order
- Player hands
- Power suit
- Turn order
- Legal move validation
- Trick winners
- Captured tens, cards, and aces
- Match completion
- Replay timeline

Clients render public state and submit intents only.

## Match State

Active matches are kept in `MatchStore` for low-latency play. Completed matches and replay events are written to MongoDB. Redis powers Socket.IO fanout across multiple backend pods and can be extended for resumable match snapshots.

## Teams

Seats are stable:

- Team A: seats 0 and 2
- Team B: seats 1 and 3

## AI

Bots share the same legal move API as humans. Hard bots inspect played cards, visible trick state, partner position, power cards, and unseen tens before choosing a move.

## Scaling

- Add backend replicas behind a load balancer.
- Use Redis adapter for socket broadcasts.
- Persist match snapshots periodically if matches need recovery after pod loss.
- Shard matchmaking queues by mode, region, and MMR band.
- Use Mongo indexes on ranking season and replay match id.
