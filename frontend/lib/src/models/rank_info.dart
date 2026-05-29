import 'package:flutter/material.dart';

class TierDef {
  final String name;
  final int min;
  final int max;
  final String icon;
  final Color color;

  const TierDef({required this.name, required this.min, required this.max, required this.icon, required this.color});
}

class RankInfo {
  final String tier;
  final int division; // 0 = no division (Grandmaster), 1-3
  final String icon;
  final Color color;
  final String displayName;
  final int mmr;
  final int peakMmr;
  final int wins;
  final int losses;
  final int nextTierMmr;
  final double progressInTier;

  const RankInfo({
    required this.tier,
    required this.division,
    required this.icon,
    required this.color,
    required this.displayName,
    required this.mmr,
    this.peakMmr = 0,
    this.wins = 0,
    this.losses = 0,
    this.nextTierMmr = 9999,
    this.progressInTier = 0.0,
  });

  static const List<TierDef> tiers = [
    TierDef(name: "Iron",         min: 0,    max: 99,   icon: "assets/images/rank_iron.png",        color: Color(0xFF6B7280)),
    TierDef(name: "Bronze",       min: 100,  max: 199,  icon: "assets/images/rank_bronze.png",      color: Color(0xFFCD7F32)),
    TierDef(name: "Silver",       min: 200,  max: 299,  icon: "assets/images/rank_silver.png",      color: Color(0xFFC0C0C0)),
    TierDef(name: "Gold",         min: 300,  max: 399,  icon: "assets/images/rank_gold.png",        color: Color(0xFFFFD700)),
    TierDef(name: "Platinum",     min: 400,  max: 599,  icon: "assets/images/rank_platinum.png",    color: Color(0xFF48E5C2)),
    TierDef(name: "Diamond",      min: 600,  max: 799,  icon: "assets/images/rank_diamond.png",     color: Color(0xFFB9F2FF)),
    TierDef(name: "Master",       min: 800,  max: 999,  icon: "assets/images/rank_master.png",      color: Color(0xFFFF6B6B)),
    TierDef(name: "Grandmaster",  min: 1000, max: 9999, icon: "assets/images/rank_grandmaster.png", color: Color(0xFFFFC857)),
  ];

  static const _divNames = {1: "I", 2: "II", 3: "III"};

  factory RankInfo.fromMmr(int mmr, {int peakMmr = 0, int wins = 0, int losses = 0}) {
    final clamped = mmr.clamp(0, 99999);
    final tierDef = tiers.lastWhere((t) => clamped >= t.min, orElse: () => tiers.first);
    final tierIndex = tiers.indexOf(tierDef);
    final nextTier = tierIndex < tiers.length - 1 ? tiers[tierIndex + 1] : null;

    if (tierDef.name == "Grandmaster") {
      return RankInfo(
        tier: tierDef.name,
        division: 0,
        icon: tierDef.icon,
        color: tierDef.color,
        displayName: "Grandmaster",
        mmr: clamped,
        peakMmr: peakMmr,
        wins: wins,
        losses: losses,
        nextTierMmr: 9999,
        progressInTier: 1.0,
      );
    }

    final range = tierDef.max - tierDef.min + 1;
    final inTier = clamped - tierDef.min;
    final third = range / 3;

    int division;
    if (inTier >= third * 2) {
      division = 1;
    } else if (inTier >= third) {
      division = 2;
    } else {
      division = 3;
    }

    return RankInfo(
      tier: tierDef.name,
      division: division,
      icon: tierDef.icon,
      color: tierDef.color,
      displayName: "${tierDef.name} ${_divNames[division]}",
      mmr: clamped,
      peakMmr: peakMmr,
      wins: wins,
      losses: losses,
      nextTierMmr: nextTier?.min ?? 9999,
      progressInTier: inTier / range,
    );
  }

  factory RankInfo.fromJson(Map<String, dynamic> json) {
    final mmr = json['mmr'] as int? ?? 0;
    return RankInfo.fromMmr(
      mmr,
      peakMmr: json['peakMmr'] as int? ?? mmr,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
    );
  }

  String get winRate {
    final total = wins + losses;
    if (total == 0) return '0%';
    return '${(wins / total * 100).round()}%';
  }

  String get seasonDisplay {
    final now = DateTime.now().toUtc();
    return '${now.year}-Q${(now.month / 3).ceil()}';
  }
}
