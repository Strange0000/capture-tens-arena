import 'arena_card.dart';

class TrickPlay {
  const TrickPlay({required this.seat, required this.card});

  final int seat;
  final ArenaCard card;

  factory TrickPlay.fromJson(Map<String, dynamic> json) => TrickPlay(
        seat: json['seat'] as int,
        card: ArenaCard.fromJson(json['card'] as Map<String, dynamic>),
      );
}

class CurrentTrick {
  const CurrentTrick({
    required this.index,
    required this.leaderSeat,
    required this.plays,
    this.winnerSeat,
  });

  final int index;
  final int leaderSeat;
  final List<TrickPlay> plays;
  final int? winnerSeat;

  factory CurrentTrick.fromJson(Map<String, dynamic> json) => CurrentTrick(
        index: json['index'] as int,
        leaderSeat: json['leaderSeat'] as int,
        plays: (json['plays'] as List<dynamic>)
            .map((p) => TrickPlay.fromJson(p as Map<String, dynamic>))
            .toList(),
        winnerSeat: json['winnerSeat'] as int?,
      );
}

class TeamCaptures {
  const TeamCaptures({
    required this.tens,
    required this.cards,
    required this.aces,
  });

  final int tens;
  final int cards;
  final int aces;

  factory TeamCaptures.fromJson(Map<String, dynamic> json) => TeamCaptures(
        tens: json['tens'] as int,
        cards: json['cards'] as int,
        aces: json['aces'] as int,
      );

  static const empty = TeamCaptures(tens: 0, cards: 0, aces: 0);
}

class MatchCaptures {
  const MatchCaptures({required this.a, required this.b});

  final TeamCaptures a;
  final TeamCaptures b;

  factory MatchCaptures.fromJson(Map<String, dynamic> json) => MatchCaptures(
        a: TeamCaptures.fromJson(json['A'] as Map<String, dynamic>),
        b: TeamCaptures.fromJson(json['B'] as Map<String, dynamic>),
      );

  static const empty = MatchCaptures(a: TeamCaptures.empty, b: TeamCaptures.empty);
}

class MatchPlayer {
  const MatchPlayer({
    required this.seat,
    required this.username,
    required this.team,
    required this.cardCount,
    required this.connected,
    required this.isBot,
  });

  final int seat;
  final String username;
  final String team;
  final int cardCount;
  final bool connected;
  final bool isBot;

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    return MatchPlayer(
      seat: json['seat'] as int,
      username: json['username'] as String,
      team: json['team'] as String,
      cardCount: json['cardCount'] as int,
      connected: json['connected'] as bool,
      isBot: json['isBot'] as bool,
    );
  }
}

class MatchState {
  const MatchState({
    required this.id,
    required this.phase,
    required this.players,
    required this.hand,
    required this.currentTurnSeat,
    required this.captures,
    required this.completedTricksCount,
    this.powerSuit,
    this.winnerTeam,
    this.currentTrick,
    this.turnDeadline,
    this.lastTrickWinner,
    required this.mode,
  });

  final String id;
  final String mode;
  final String phase;
  final List<MatchPlayer> players;
  final List<ArenaCard> hand;
  final int currentTurnSeat;
  final String? powerSuit;
  final String? winnerTeam;
  final CurrentTrick? currentTrick;
  final MatchCaptures captures;
  final int completedTricksCount;
  final int? turnDeadline;
  final String? lastTrickWinner;

  factory MatchState.fromJson(Map<String, dynamic> json) {
    final tricks = json['completedTricks'] as List<dynamic>? ?? [];
    final players = (json['players'] as List<dynamic>)
        .map((item) => MatchPlayer.fromJson(item as Map<String, dynamic>))
        .toList();

    // Extract last trick winner name
    String? lastWinner;
    if (tricks.isNotEmpty) {
      final lastTrick = tricks.last as Map<String, dynamic>;
      final winnerSeat = lastTrick['winnerSeat'] as int?;
      if (winnerSeat != null) {
        lastWinner = players.where((p) => p.seat == winnerSeat).firstOrNull?.username;
      }
    }

    final powerSuit = json['powerSuit'] as String?;
    final parsedHand = (json['hand'] as List<dynamic>? ?? [])
        .map((item) => ArenaCard.fromJson(item as Map<String, dynamic>))
        .toList();

    parsedHand.sort((a, b) {
      int suitValue(String suit) {
        if (suit == powerSuit) return 0;
        switch (suit) {
          case 'hearts': return 1;
          case 'diamonds': return 2;
          case 'clubs': return 3;
          case 'spades': return 4;
          default: return 5;
        }
      }

      int rankValue(String rank) {
        switch (rank) {
          case '2': return 2;
          case '3': return 3;
          case '4': return 4;
          case '5': return 5;
          case '6': return 6;
          case '7': return 7;
          case '8': return 8;
          case '9': return 9;
          case '10': return 10;
          case 'J': return 11;
          case 'Q': return 12;
          case 'K': return 13;
          case 'A': return 14;
          default: return 0;
        }
      }

      final suitA = suitValue(a.suit);
      final suitB = suitValue(b.suit);
      if (suitA != suitB) return suitA.compareTo(suitB);
      // Sort in descending order of rank so A comes first?
      // Wait, standard hand sorting is usually ascending or descending. Let's do ascending for ranks.
      return rankValue(a.rank).compareTo(rankValue(b.rank));
    });

    return MatchState(
      id: json['id'] as String,
      mode: json['mode'] as String? ?? 'offline',
      phase: json['phase'] as String,
      players: players,
      hand: parsedHand,
      currentTurnSeat: json['currentTurnSeat'] as int,
      powerSuit: json['powerSuit'] as String?,
      winnerTeam: json['winnerTeam'] as String?,
      currentTrick: json['currentTrick'] != null
          ? CurrentTrick.fromJson(json['currentTrick'] as Map<String, dynamic>)
          : null,
      captures: json['captures'] != null
          ? MatchCaptures.fromJson(json['captures'] as Map<String, dynamic>)
          : MatchCaptures.empty,
      completedTricksCount: tricks.length,
      turnDeadline: json['turnDeadline'] as int?,
      lastTrickWinner: lastWinner,
    );
  }
}

