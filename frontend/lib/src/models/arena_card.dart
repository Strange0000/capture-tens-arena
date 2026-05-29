class ArenaCard {
  const ArenaCard({required this.id, required this.rank, required this.suit});

  final String id;
  final String rank;
  final String suit;

  factory ArenaCard.fromJson(Map<String, dynamic> json) {
    return ArenaCard(
      id: json['id'] as String,
      rank: json['rank'] as String,
      suit: json['suit'] as String,
    );
  }
}
