import { MatchState } from "../game/types.js";

export class MatchStore {
  private matches = new Map<string, MatchState>();
  private userToMatch = new Map<string, string>();

  set(state: MatchState) {
    this.matches.set(state.id, state);
    for (const player of state.players) {
      if (player.isBot) {
        // When an abandoning or disconnected player is replaced by a bot,
        // they must no longer reconnect into this match.
        if (this.userToMatch.get(player.userId) === state.id) {
          this.userToMatch.delete(player.userId);
        }
      } else {
        this.userToMatch.set(player.userId, state.id);
      }
    }
  }

  get(id: string) {
    return this.matches.get(id);
  }

  findByUser(userId: string) {
    const matchId = this.userToMatch.get(userId);
    if (!matchId) return undefined;

    const state = this.matches.get(matchId);
    const isActivePlayer = state?.players.some(
      (player) => player.userId === userId && !player.isBot,
    );
    if (!state || !isActivePlayer) {
      // Defend against stale mappings left by an older match or bot takeover.
      if (this.userToMatch.get(userId) === matchId) {
        this.userToMatch.delete(userId);
      }
      return undefined;
    }

    return state;
  }

  delete(id: string) {
    const state = this.matches.get(id);
    if (state) {
      for (const player of state.players) {
        // A user may already have entered another match; deleting an older
        // match must not clear that newer mapping.
        if (this.userToMatch.get(player.userId) === id) {
          this.userToMatch.delete(player.userId);
        }
      }
    }
    this.matches.delete(id);
  }
}

export const matchStore = new MatchStore();
