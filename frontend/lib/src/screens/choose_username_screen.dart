import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/choose_username_form.dart';

/// Full-screen "Choose your username" page (PR-C).
///
/// Shown instead of the current screen whenever a username is required
/// (first game entry, before the held-back entry runs). It is a normal
/// screen, NOT a floating dialog overlay: in the overlay the web
/// text-input bridge never delivered keystrokes to the field's controller
/// (the live debug readout stayed txt="" while the box showed the typed
/// name), so no name could ever be typed. Normal screens work — the lobby
/// search proves it — so the chooser lives here now.
class ChooseUsernameScreen extends StatelessWidget {
  const ChooseUsernameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: ArenaColors.ink,
      body: SafeArea(
        child: ChooseUsernameForm(
          currentUsername: app.username,
          isGuest: app.isGuest,
          onCheckAvailability: app.checkUsernameAvailability,
          onClaim: app.claimUsername,
        ),
      ),
    );
  }
}
