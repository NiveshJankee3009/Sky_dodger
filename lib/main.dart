import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/audio_manager.dart';
import 'game/high_score_store.dart';
import 'game/sky_dodger_game.dart';
import 'ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final highScores = await HighScoreStore.load();
  final audio = await AudioManager.load();
  unawaited(audio.init()); // load sounds in the background, start music

  runApp(
    SkyDodgerApp(game: SkyDodgerGame(highScores: highScores, audio: audio)),
  );
}

class SkyDodgerApp extends StatelessWidget {
  const SkyDodgerApp({super.key, required this.game});

  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sky Dodger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4FC3F7),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: GameWidget<SkyDodgerGame>(
          game: game,
          overlayBuilderMap: {
            Overlays.menu: (context, game) => MenuOverlay(game: game),
            Overlays.hud: (context, game) => HudOverlay(game: game),
            Overlays.pause: (context, game) => PauseOverlay(game: game),
            Overlays.gameOver: (context, game) => GameOverOverlay(game: game),
          },
        ),
      ),
    );
  }
}
