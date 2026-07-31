import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Map<String, dynamic>> _achievements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final app = context.read<AppState>();
    try {
      final data = await app.auth.fetchAchievements(app.token!);
      if (mounted) setState(() { _achievements = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _achievements.where((a) => a['unlocked'] == true).length;
    final total = _achievements.length;

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Achievements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      body: Stack(
        children: [
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF48E5C2)))
                : Column(
                    children: [
                      // Progress header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF48E5C2).withOpacity(0.1),
                                const Color(0xFFFFC857).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF48E5C2).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC857).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('🏆', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$unlocked / $total Unlocked',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: total > 0 ? unlocked / total : 0,
                                        backgroundColor: Colors.white10,
                                        valueColor: const AlwaysStoppedAnimation(Color(0xFF48E5C2)),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Achievement grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _achievements.length,
                          itemBuilder: (context, index) {
                            final a = _achievements[index];
                            final isUnlocked = a['unlocked'] == true;
                            return _AchievementTile(
                              icon: a['icon'] ?? '🏅',
                              name: a['name'] ?? 'Unknown',
                              description: a['description'] ?? '',
                              unlocked: isUnlocked,
                            );
                          },
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

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.icon,
    required this.name,
    required this.description,
    required this.unlocked,
  });

  final String icon;
  final String name;
  final String description;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF101826),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: TextStyle(fontSize: 48, color: unlocked ? null : Colors.white24)),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(
                    color: unlocked ? const Color(0xFFFFC857) : Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🔒 Locked', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFFFFC857).withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? const Color(0xFFFFC857).withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: unlocked
              ? [BoxShadow(color: const Color(0xFFFFC857).withOpacity(0.1), blurRadius: 12)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 32,
                color: unlocked ? null : Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!unlocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.lock_outline, size: 14, color: Colors.white.withOpacity(0.15)),
              ),
          ],
        ),
      ),
    );
  }
}
