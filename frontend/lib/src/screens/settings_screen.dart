import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final audio = AudioService.instance;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      body: Stack(
        children: [
          // Subtle gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D1B2A), Color(0xFF070B13)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _SectionHeader(title: 'Audio', icon: Icons.volume_up_rounded),
                const SizedBox(height: 8),
                _GlassCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.music_note_rounded,
                      label: 'Sound Effects',
                      value: audio.soundEnabled,
                      onChanged: (v) {
                        setState(() => audio.setSoundEnabled(v));
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _SliderRow(
                      icon: Icons.speaker_rounded,
                      label: 'Volume',
                      value: audio.volume,
                      enabled: audio.soundEnabled,
                      onChanged: (v) {
                        setState(() => audio.setVolume(v));
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionHeader(title: 'Gameplay', icon: Icons.sports_esports_rounded),
                const SizedBox(height: 8),
                _GlassCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.vibration_rounded,
                      label: 'Haptic Feedback',
                      value: audio.hapticsEnabled,
                      onChanged: (v) {
                        setState(() => audio.setHapticsEnabled(v));
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionHeader(title: 'Account', icon: Icons.person_rounded),
                const SizedBox(height: 8),
                _GlassCard(
                  children: [
                    _InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Username',
                      value: app.username ?? 'Unknown',
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'User ID',
                      value: app.userId?.substring(0, 12) ?? '—',
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _ActionRow(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      color: Colors.redAccent,
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF101826),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Logout?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            content: const Text(
                              'You will be returned to the login screen.',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Capture Tens Arena v1.0.0',
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
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

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF48E5C2), size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF48E5C2),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF48E5C2),
            activeTrackColor: const Color(0xFF48E5C2).withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.icon, required this.label, required this.value, required this.enabled, required this.onChanged});
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: enabled ? Colors.white54 : Colors.white24, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF48E5C2),
                inactiveTrackColor: Colors.white10,
                thumbColor: const Color(0xFF48E5C2),
                overlayColor: const Color(0xFF48E5C2).withOpacity(0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(color: enabled ? Colors.white54 : Colors.white24, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
