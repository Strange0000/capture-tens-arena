import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/audio_service.dart';
import 'src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.instance.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CaptureTensApp(),
    ),
  );
}
