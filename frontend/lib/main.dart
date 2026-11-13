import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/audio_service.dart';
import 'src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Paint first: awaiting audio init before runApp() delayed the first
  // frame for no reason (the web splash in index.html covers the wait
  // before that). Audio initialises in the background instead.
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CaptureTensApp(),
    ),
  );
  // Fire-and-forget: must not block the first frame or guest sign-in.
  AudioService.instance.init();
}
