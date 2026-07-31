import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton audio manager for the game.
/// Handles sound effects and haptic feedback preferences.
class AudioService {
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;
  AudioService._();

  bool _initialized = false;
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  double volume = 0.8;

  final Map<String, AudioPlayer> _players = {};

  static const _sfxFiles = {
    'card_play': 'assets/audio/card_play.mp3',
    'card_deal': 'assets/audio/card_deal.mp3',
    'trick_win': 'assets/audio/trick_win.mp3',
    'match_win': 'assets/audio/match_win.mp3',
    'match_lose': 'assets/audio/match_lose.mp3',
    'power_suit': 'assets/audio/power_suit.mp3',
    'button_tap': 'assets/audio/button_tap.mp3',
    'countdown': 'assets/audio/countdown.mp3',
    'achievement': 'assets/audio/achievement.mp3',
    'emote': 'assets/audio/emote.mp3',
  };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    soundEnabled = prefs.getBool('sound_enabled') ?? true;
    hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
    volume = prefs.getDouble('sound_volume') ?? 0.8;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics_enabled', enabled);
  }

  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', volume);
  }

  /// Play a named sound effect. Gracefully handles missing files.
  Future<void> play(String name) async {
    if (!soundEnabled) return;
    final path = _sfxFiles[name];
    if (path == null) return;

    try {
      var player = _players[name];
      if (player == null) {
        player = AudioPlayer();
        await player.setAsset(path);
        _players[name] = player;
      }
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Audio file may not exist yet — fail silently
    }
  }

  // ── Convenience methods ────────────────────────────────────────────────

  Future<void> playCardPlace() => play('card_play');
  Future<void> playCardDeal() => play('card_deal');
  Future<void> playTrickWin() => play('trick_win');
  Future<void> playMatchWin() => play('match_win');
  Future<void> playMatchLose() => play('match_lose');
  Future<void> playPowerSuit() => play('power_suit');
  Future<void> playButtonTap() => play('button_tap');
  Future<void> playCountdown() => play('countdown');
  Future<void> playAchievement() => play('achievement');
  Future<void> playEmote() => play('emote');

  // ── Haptics ────────────────────────────────────────────────────────────

  void hapticLight() {
    if (!hapticsEnabled) return;
    HapticFeedback.lightImpact();
  }

  void hapticMedium() {
    if (!hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  void hapticHeavy() {
    if (!hapticsEnabled) return;
    HapticFeedback.heavyImpact();
  }

  void hapticSelection() {
    if (!hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Dispose all audio players.
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
    _initialized = false;
  }
}
