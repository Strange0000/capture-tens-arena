import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/choose_username_form.dart';

/// Full-screen "Choose your username" page (PR-C).
///
/// Shown via the MaterialApp.builder whenever a username is required
/// (first game entry, before the held-back entry runs). The Navigator's
/// child is kept alive (Offstage) so Flutter web's focus scope and
/// text-input bridge stay connected — without it the TextField renders
/// visually but keystrokes never reach the controller.
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
