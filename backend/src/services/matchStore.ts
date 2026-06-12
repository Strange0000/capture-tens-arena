import { MatchState } from "../game/types.js";

export class MatchStore {
  private matches = new Map<string, MatchState>();
  private userToMatch = new Map<string, string>();

  set(state: MatchState) {
    this.matches.set(state.id, state);
    for (const player of state.players) {
      if (!player.isBot) this.userToMatch.set(player.userId, state.id);
    }
  }

  get(id: string) {
    return this.matches.get(id);
  }

  findByUser(userId: string) {
    const matchId = this.userToMatch.get(userId);
    return matchId ? this.matches.get(matchId) : undefined;
  }

  delete(id: string) {
    const state = this.matches.get(id);
    if (state) for (const player of state.players) this.userToMatch.delete(player.userId);
    this.matches.delete(id);
  }
}

export const matchStore = new MatchStore();
