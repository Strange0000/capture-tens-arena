import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/choose_username_form.dart';

/// Full-screen "Choose your username" page, pushed as a Navigator route
/// (/choose-username) from AppState._startGame.
///
/// It MUST be a Navigator route — not a widget in MaterialApp.builder —
/// because on Flutter web a TextField must live inside the Navigator's
/// subtree to receive keystrokes. Widgets placed outside the Navigator
/// (in the builder) render visually but their text-input bridge never
/// connects to the TextEditingController (txt="" while the box shows
/// typed text).
///
/// PopScope prevents the browser Back button from skipping the chooser.
/// The player must pick a name; on success AppState.claimUsername pops
/// this route and runs the held-back game entry.
class ChooseUsernameScreen extends StatelessWidget {
  const ChooseUsernameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PopScope(
      canPop: false, // cannot skip — must pick a username
      child: Scaffold(
        backgroundColor: ArenaColors.ink,
        body: SafeArea(
          child: ChooseUsernameForm(
            currentUsername: app.username,
            isGuest: app.isGuest,
            onCheckAvailability: app.checkUsernameAvailability,
            onClaim: app.claimUsername,
          ),
        ),
      ),
    );
  }
}
