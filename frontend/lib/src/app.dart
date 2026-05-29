import 'package:flutter/material.dart';

import 'screens/game_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/replay_screen.dart';
import 'theme.dart';

class CaptureTensApp extends StatelessWidget {
  const CaptureTensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Capture Tens Arena',
      theme: buildArenaTheme(),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final routes = <String, WidgetBuilder>{
          '/': (_) => const LoginScreen(),
          '/lobby': (_) => const LobbyScreen(),
          '/game': (_) => const GameScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/replay': (_) => const ReplayScreen(),
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
