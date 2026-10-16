import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton audio manager for the game.
/// Handles sound effects, background music (BGM), and haptic feedback preferences.
class AudioService {
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;
  AudioService._();

  bool _initialized = false;
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool hapticsEnabled = true;
  double volume = 0.8;
  double musicVolume = 0.4;

  final Map<String, AudioPlayer> _players = {};
  AudioPlayer? _bgmPlayer;
  String? _currentBgm;

  static const _sfxFiles = {
    'card_play': 'assets/audio/card_play.mp3',
    'card_deal': 'assets/audio/card_deal.mp3',
    'card_click': 'assets/audio/card_click.mp3',
    'card_shuffle': 'assets/audio/card_shuffle.mp3',
    'trick_win': 'assets/audio/trick_win.mp3',
    'match_win': 'assets/audio/match_win.mp3',
    'match_lose': 'assets/audio/match_lose.mp3',
    'power_suit': 'assets/audio/power_suit.mp3',
    'button_tap': 'assets/audio/button_tap.mp3',
    'countdown': 'assets/audio/countdown.mp3',
    'achievement': 'assets/audio/achievement.mp3',
    'emote': 'assets/audio/emote.mp3',
  };

  static const _bgmFiles = {
    'lobby': 'assets/audio/lobby_bgm.mp3',
    'game': 'assets/audio/game_bgm.mp3',
  };

  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    soundEnabled = _prefs?.getBool('sound_enabled') ?? true;
    musicEnabled = _prefs?.getBool('music_enabled') ?? true;
    hapticsEnabled = _prefs?.getBool('haptics_enabled') ?? true;
    volume = _prefs?.getDouble('sound_volume') ?? 0.8;
    musicVolume = _prefs?.getDouble('music_volume') ?? 0.4;
    _bgmPlayer = AudioPlayer();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool('sound_enabled', enabled);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool('music_enabled', enabled);
    if (!enabled) {
      await _bgmPlayer?.pause();
    } else if (_currentBgm != null) {
      await playBgm(_currentBgm!);
    }
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool('haptics_enabled', enabled);
  }

  Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble('sound_volume', volume);
  }

  Future<void> setMusicVolume(double vol) async {
    musicVolume = vol.clamp(0.0, 1.0);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble('music_volume', musicVolume);
    await _bgmPlayer?.setVolume(musicVolume);
  }

  Future<void> resetToDefaults() async {
    await setSoundEnabled(true);
    await setMusicEnabled(true);
    await setHapticsEnabled(true);
    await setVolume(0.8);
    await setMusicVolume(0.4);
  }

  bool get isBgmPlaying => _bgmPlayer?.playing ?? false;

  // ── Background Music (BGM) ──────────────────────────────────────────────

  Future<void> playBgm(String trackName) async {
    _currentBgm = trackName;
    if (!musicEnabled) return;

    final path = _bgmFiles[trackName];
    if (path == null) return;

    try {
      _bgmPlayer ??= AudioPlayer();
      await _bgmPlayer!.setLoopMode(LoopMode.all);
      await _bgmPlayer!.setVolume(musicVolume);
      await _bgmPlayer!.setAsset(path);
      await _bgmPlayer!.play();
    } catch (_) {
      // Audio playback failed (e.g. browser autoplay restriction before first gesture)
    }
  }

  Future<void> playLobbyBgm() => playBgm('lobby');
  Future<void> playGameBgm() => playBgm('game');

  Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer?.stop();
  }

  Future<void> pauseBgm() async {
    await _bgmPlayer?.pause();
  }

  Future<void> resumeBgm() async {
    if (musicEnabled && _currentBgm != null) {
      await _bgmPlayer?.play();
    }
  }

  // ── Sound Effects (SFX) ──────────────────────────────────────────────────

  /// Play a named sound effect. Gracefully handles missing files or browser locks.
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
      if (player.playing) {
        await player.stop();
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Audio file playback error — fail silently
    }
  }

  // ── Convenience methods ────────────────────────────────────────────────

  Future<void> playCardPlace() => play('card_play');
  Future<void> playCardPlay() => play('card_play');
  Future<void> playCardClick() => play('card_click');
  Future<void> playCardDeal() => play('card_deal');
  Future<void> playCardShuffle() => play('card_shuffle');
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
    _bgmPlayer?.dispose();
    _bgmPlayer = null;
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
    _initialized = false;
  }
}
