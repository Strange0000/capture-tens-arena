import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';

import 'screens/game_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/login_screen.dart';
import 'screens/matchmaking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/replay_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/tutorial_screen.dart';
import 'theme.dart';

class CaptureTensApp extends StatelessWidget {
  const CaptureTensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Capture Tens Arena',
      theme: buildArenaTheme(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const _AchievementToaster(),
          ],
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/': (_) => const LoginScreen(),
          '/lobby': (_) => const LobbyScreen(),
          '/game': (_) => const GameScreen(),
          '/matchmaking': (_) => const MatchmakingScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/replay': (_) => const ReplayScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/achievements': (_) => const AchievementsScreen(),
          '/tutorial': (_) => const TutorialScreen(),
        };

        final builder = routes[settings.name];
        if (builder == null) {
          return MaterialPageRoute(
            builder: (_) => const LoginScreen(),
            settings: settings,
          );
        }

        // Game screen gets a slide-up transition
        if (settings.name == '/game') {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: child,
                ),
              );
            },
          );
        }

        // Default transitions with fade
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        );
      },
    );
  }
}

class _AchievementToaster extends StatefulWidget {
  const _AchievementToaster();
  @override
  State<_AchievementToaster> createState() => _AchievementToasterState();
}

class _AchievementToasterState extends State<_AchievementToaster> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  Map<String, dynamic>? _currentAchievement;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    
    if (app.pendingAchievements.isNotEmpty && !_isShowing) {
      _isShowing = true;
      _currentAchievement = app.pendingAchievements.first;
      _ctrl.forward();
      
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        _ctrl.reverse().then((_) {
          if (!mounted) return;
          app.dismissAchievement();
          _isShowing = false;
        });
      });
    }

    if (_currentAchievement == null) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.5),
              end: Offset.zero,
            ).animate(_slideAnim),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      _currentAchievement!['icon'] as String? ?? '🏆',
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ACHIEVEMENT UNLOCKED',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentAchievement!['name'] as String? ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentAchievement!['description'] as String? ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
