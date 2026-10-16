import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final audio = AudioService.instance;

  // Local state for gameplay toggles
  bool _highlightLegal = true;
  bool _autoSortHand = true;
  bool _tableTilt3d = true;
  bool _confirmCardPlay = false;
  bool _isTestingBgm = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highlightLegal = prefs.getBool('pref_highlight_legal') ?? true;
      _autoSortHand = prefs.getBool('pref_auto_sort_hand') ?? true;
      _tableTilt3d = prefs.getBool('pref_table_tilt_3d') ?? true;
      _confirmCardPlay = prefs.getBool('pref_confirm_card_play') ?? false;
      _isTestingBgm = audio.isBgmPlaying;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showCopiedSnackbar(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF48E5C2), size: 18),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF16233B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rank = app.rankInfo;
    final userId = app.userId ?? 'Guest';
    final safeShortId = userId.length > 16 ? '${userId.substring(0, 16)}…' : userId;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.white.withOpacity(0.06),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              onPressed: () {
                audio.playButtonTap();
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SETTINGS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            Text(
              'AUDIO, GRAPHICS & ACCOUNT',
              style: TextStyle(
                color: const Color(0xFF48E5C2).withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              audio.playButtonTap();
              await audio.resetToDefaults();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pref_highlight_legal', true);
              await prefs.setBool('pref_auto_sort_hand', true);
              await prefs.setBool('pref_table_tilt_3d', true);
              await prefs.setBool('pref_confirm_card_play', false);
              if (mounted) {
                setState(() {
                  _highlightLegal = true;
                  _autoSortHand = true;
                  _tableTilt3d = true;
                  _confirmCardPlay = false;
                });
                _showCopiedSnackbar('Settings reset to defaults');
              }
            },
            icon: const Icon(Icons.restart_alt_rounded, color: Colors.white54, size: 18),
            label: const Text(
              'Reset Defaults',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF132238),
                    Color(0xFF0A111E),
                    Color(0xFF060911),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    // Profile Card
                    _ProfileHeroCard(
                      username: app.username ?? 'Commander',
                      userId: userId,
                      safeShortId: safeShortId,
                      rank: rank,
                      backendUrl: app.backendUrl,
                      onCopyId: () {
                        Clipboard.setData(ClipboardData(text: userId));
                        audio.playButtonTap();
                        _showCopiedSnackbar('User ID copied to clipboard!');
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section 1: Audio & Sound
                    _SectionHeader(
                      title: 'Audio & Acoustics',
                      subtitle: 'Master volume, soundtrack, and combat sound effects',
                      icon: Icons.volume_up_rounded,
                      accentColor: const Color(0xFF48E5C2),
                    ),
                    const SizedBox(height: 10),
                    _LuxurySettingsCard(
                      children: [
                        // BGM Switch
                        _LuxuryToggleRow(
                          icon: Icons.music_note_rounded,
                          accentColor: const Color(0xFF48E5C2),
                          title: 'Background Music',
                          subtitle: 'Original ambient soundtrack for lobby and battle tables',
                          value: audio.musicEnabled,
                          onChanged: (v) {
                            setState(() => audio.setMusicEnabled(v));
                          },
                          trailingAction: audio.musicEnabled
                              ? _MiniPillButton(
                                  icon: _isTestingBgm ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  label: _isTestingBgm ? 'Stop BGM' : 'Preview BGM',
                                  color: const Color(0xFF48E5C2),
                                  onTap: () async {
                                    audio.playButtonTap();
                                    if (_isTestingBgm) {
                                      await audio.pauseBgm();
                                      setState(() => _isTestingBgm = false);
                                    } else {
                                      await audio.playLobbyBgm();
                                      setState(() => _isTestingBgm = true);
                                    }
                                  },
                                )
                              : null,
                        ),
                        _LuxurySliderRow(
                          icon: Icons.graphic_eq_rounded,
                          title: 'Music Volume',
                          value: audio.musicVolume,
                          enabled: audio.musicEnabled,
                          accentColor: const Color(0xFF48E5C2),
                          onChanged: (v) {
                            setState(() => audio.setMusicVolume(v));
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        // SFX Switch
                        _LuxuryToggleRow(
                          icon: Icons.surround_sound_rounded,
                          accentColor: const Color(0xFFF5A623),
                          title: 'Sound Effects (SFX)',
                          subtitle: 'Card deals, suit slams, trick captures, and UI interactions',
                          value: audio.soundEnabled,
                          onChanged: (v) {
                            setState(() => audio.setSoundEnabled(v));
                          },
                          trailingAction: audio.soundEnabled
                              ? _MiniPillButton(
                                  icon: Icons.volume_up_rounded,
                                  label: 'Test SFX',
                                  color: const Color(0xFFF5A623),
                                  onTap: () {
                                    audio.playCardPlace();
                                    audio.hapticLight();
                                  },
                                )
                              : null,
                        ),
                        _LuxurySliderRow(
                          icon: Icons.speaker_rounded,
                          title: 'SFX Volume',
                          value: audio.volume,
                          enabled: audio.soundEnabled,
                          accentColor: const Color(0xFFF5A623),
                          onChanged: (v) {
                            setState(() => audio.setVolume(v));
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        // Haptics Switch
                        _LuxuryToggleRow(
                          icon: Icons.vibration_rounded,
                          accentColor: const Color(0xFFA78BFA),
                          title: 'Haptic Feedback',
                          subtitle: 'Physical vibration tactile feedback on card play & captures',
                          value: audio.hapticsEnabled,
                          onChanged: (v) {
                            setState(() => audio.setHapticsEnabled(v));
                          },
                          trailingAction: audio.hapticsEnabled
                              ? _MiniPillButton(
                                  icon: Icons.vibration_rounded,
                                  label: 'Test Haptic',
                                  color: const Color(0xFFA78BFA),
                                  onTap: () {
                                    audio.hapticHeavy();
                                  },
                                )
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Gameplay & Visuals
                    _SectionHeader(
                      title: 'Gameplay & Visuals',
                      subtitle: 'Table camera perspectives, assist guides, and move verification',
                      icon: Icons.sports_esports_rounded,
                      accentColor: const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(height: 10),
                    _LuxurySettingsCard(
                      children: [
                        _LuxuryToggleRow(
                          icon: Icons.lightbulb_outline_rounded,
                          accentColor: const Color(0xFFFFD166),
                          title: 'Highlight Legal Moves',
                          subtitle: 'Display golden neon glow around playable cards following lead suit',
                          value: _highlightLegal,
                          onChanged: (v) {
                            setState(() => _highlightLegal = v);
                            _saveBool('pref_highlight_legal', v);
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        _LuxuryToggleRow(
                          icon: Icons.sort_rounded,
                          accentColor: const Color(0xFF06D6A0),
                          title: 'Auto-Sort Hand by Suit',
                          subtitle: 'Automatically organize cards by Diamonds, Hearts, Spades, and Clubs',
                          value: _autoSortHand,
                          onChanged: (v) {
                            setState(() => _autoSortHand = v);
                            _saveBool('pref_auto_sort_hand', v);
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        _LuxuryToggleRow(
                          icon: Icons.threed_rotation_rounded,
                          accentColor: const Color(0xFF118AB2),
                          title: '3D Table Tilt Perspective',
                          subtitle: 'Cinematic 3D isometric pitch on the felt arena table',
                          value: _tableTilt3d,
                          onChanged: (v) {
                            setState(() => _tableTilt3d = v);
                            _saveBool('pref_table_tilt_3d', v);
                          },
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        _LuxuryToggleRow(
                          icon: Icons.touch_app_rounded,
                          accentColor: const Color(0xFFEF476F),
                          title: 'Confirm Card Play',
                          subtitle: 'Require double-tap or drag release to prevent accidental moves',
                          value: _confirmCardPlay,
                          onChanged: (v) {
                            setState(() => _confirmCardPlay = v);
                            _saveBool('pref_confirm_card_play', v);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Network & Security
                    _SectionHeader(
                      title: 'System & Account',
                      subtitle: 'Active backend server, credentials, and session controls',
                      icon: Icons.shield_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 10),
                    _LuxurySettingsCard(
                      children: [
                        // Server endpoint info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF38BDF8), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Arena Server Gateway', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      app.backendUrl,
                                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontFamily: 'monospace'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('ONLINE', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        // Logout row
                        InkWell(
                          onTap: () async {
                            audio.playButtonTap();
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF10192A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                                ),
                                title: Row(
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                                    SizedBox(width: 10),
                                    Text('Sign Out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                content: const Text(
                                  'You will end your active session and return to the main gate. Your rank rating and stats remain safely saved in the arena.',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && context.mounted) {
                              await app.logout();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                              }
                            }
                          },
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sign Out of Arena',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Return to sign in or switch commander credentials',
                                        style: TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.redAccent, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Version & Credits
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: const Text(
                              'CAPTURE TENS ARENA · v1.0.0 (RELEASE)',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tactical 2v2 Trick-Taking Card Combat Arena',
                            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Hero Card ──────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.username,
    required this.userId,
    required this.safeShortId,
    required this.rank,
    required this.backendUrl,
    required this.onCopyId,
  });

  final String username;
  final String userId;
  final String safeShortId;
  final dynamic rank;
  final String backendUrl;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank?.color ?? const Color(0xFFF5A623);
    final rankTitle = rank?.displayName ?? 'Novice Recruit';
    final mmr = rank?.mmr ?? 1000;
    final wins = rank?.wins ?? 0;
    final losses = rank?.losses ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF172844).withOpacity(0.9),
            const Color(0xFF0F1A2E).withOpacity(0.9),
          ],
        ),
        border: Border.all(color: rankColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  rankColor.withOpacity(0.4),
                  const Color(0xFF0C1424),
                ],
              ),
              border: Border.all(color: rankColor, width: 2),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'C',
                style: TextStyle(
                  color: rankColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: rankColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        rankTitle.toUpperCase(),
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$mmr MMR',
                      style: const TextStyle(
                        color: Color(0xFF48E5C2),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  $wins W / $losses L',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Safe User ID row with copy button
                InkWell(
                  onTap: onCopyId,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag_rounded, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          safeShortId,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, color: Color(0xFF48E5C2), size: 13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Luxury Settings Card ──────────────────────────────────────────────────

class _LuxurySettingsCard extends StatelessWidget {
  const _LuxurySettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101A2C).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ── Luxury Toggle Row ──────────────────────────────────────────────────────

class _LuxuryToggleRow extends StatelessWidget {
  const _LuxuryToggleRow({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.trailingAction,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailingAction != null) ...[
            trailingAction!,
            const SizedBox(width: 8),
          ],
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
            activeTrackColor: accentColor.withOpacity(0.35),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }
}

// ── Luxury Slider Row ──────────────────────────────────────────────────────

class _LuxurySliderRow extends StatelessWidget {
  const _LuxurySliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.accentColor,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final bool enabled;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final displayPercent = (value * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Row(
        children: [
          const SizedBox(width: 42), // Align under toggle title
          Icon(
            icon,
            color: enabled ? Colors.white60 : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: Colors.white10,
                thumbColor: accentColor,
                overlayColor: accentColor.withOpacity(0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: enabled ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: enabled ? accentColor.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Text(
              '$displayPercent%',
              style: TextStyle(
                color: enabled ? accentColor : Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini Pill Button ────────────────────────────────────────────────────────

class _MiniPillButton extends StatelessWidget {
  const _MiniPillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
