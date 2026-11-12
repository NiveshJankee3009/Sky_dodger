import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'components/coin.dart';
import 'components/player.dart';
import 'components/rock.dart';
import 'components/starfield.dart';
import 'components/touch_area.dart';
import 'audio_manager.dart';
import 'difficulty.dart';
import 'high_score_store.dart';

enum GameState { menu, playing, paused, gameOver }

/// Overlay names, shared with the widget layer in main.dart.
abstract final class Overlays {
  static const menu = 'menu';
  static const hud = 'hud';
  static const pause = 'pause';
  static const gameOver = 'gameOver';
}

class SkyDodgerGame extends FlameGame with HasCollisionDetection {
  SkyDodgerGame({
    required this.highScores,
    required this.audio,
    math.Random? random,
  }) : _rng = random ?? math.Random();

  final HighScoreStore highScores;
  final AudioManager audio;
  final math.Random _rng;
  final Difficulty difficulty = const Difficulty();
  final ScoreKeeper scoreKeeper = ScoreKeeper();

  /// Live score for the Flutter HUD.
  final ValueNotifier<int> score = ValueNotifier(0);

  late final Player player;
  GameState state = GameState.menu;
  bool lastRunWasRecord = false;

  double elapsed = 0;
  double _rockTimer = 0;
  double _coinTimer = 0;

  /// Speed used by the starfield; idles slowly on menus.
  double get scrollSpeed =>
      state == GameState.playing ? difficulty.fallSpeed(elapsed) : 90;

  @override
  Color backgroundColor() => const Color(0xFF0B1026);

  @override
  Future<void> onLoad() async {
    player = Player();
    await addAll([Starfield(), player, TouchArea()]);
    overlays.add(Overlays.menu);
  }

  // ---------------------------------------------------------------- flow

  void start() {
    _clearHazards();
    scoreKeeper.reset();
    score.value = 0;
    elapsed = 0;
    _rockTimer = 0;
    _coinTimer = 1.5;
    lastRunWasRecord = false;
    player.reset();
    state = GameState.playing;
    audio.play(Sfx.start);
    overlays
      ..remove(Overlays.menu)
      ..remove(Overlays.gameOver)
      ..add(Overlays.hud);
    resumeEngine();
  }

  void pause() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    pauseEngine();
    overlays.add(Overlays.pause);
  }

  void resume() {
    if (state != GameState.paused) return;
    overlays.remove(Overlays.pause);
    state = GameState.playing;
    resumeEngine();
  }

  void goToMenu() {
    _clearHazards();
    state = GameState.menu;
    player.reset();
    overlays
      ..remove(Overlays.pause)
      ..remove(Overlays.gameOver)
      ..remove(Overlays.hud)
      ..add(Overlays.menu);
    resumeEngine();
  }

  Future<void> crash() async {
    if (state != GameState.playing) return;
    state = GameState.gameOver;
    HapticFeedback.heavyImpact();
    audio.play(Sfx.crash);
    player.visible = false;
    _explode(player.position.clone());

    lastRunWasRecord = await highScores.submit(scoreKeeper.score);

    // Let the explosion play before showing the results screen.
    add(
      TimerComponent(
        period: 0.9,
        removeOnFinish: true,
        onTick: () {
          overlays
            ..remove(Overlays.hud)
            ..add(Overlays.gameOver);
          if (lastRunWasRecord) audio.play(Sfx.newBest);
        },
      ),
    );
  }

  void collectCoin(Coin coin) {
    if (state != GameState.playing || coin.isRemoving) return;
    coin.removeFromParent();
    scoreKeeper.addCoin();
    score.value = scoreKeeper.score;
    HapticFeedback.selectionClick();
    audio.play(Sfx.coin);
    _sparkle(coin.position.clone());
  }

  // ---------------------------------------------------------------- loop

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    elapsed += dt;
    scoreKeeper.tick(dt);
    score.value = scoreKeeper.score;

    _rockTimer -= dt;
    if (_rockTimer <= 0) {
      _spawnRock();
      _rockTimer = difficulty.spawnInterval(elapsed) * (0.7 + _rng.nextDouble() * 0.6);
    }

    _coinTimer -= dt;
    if (_coinTimer <= 0) {
      _spawnCoin();
      _coinTimer = difficulty.coinInterval(elapsed) * (0.7 + _rng.nextDouble() * 0.6);
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState appState) {
    super.lifecycleStateChange(appState);
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      pause(); // show the pause menu when the player comes back
    }
  }

  // ---------------------------------------------------------------- spawning

  void _spawnRock() {
    final r = 14 + _rng.nextDouble() * 22;
    final x = r + _rng.nextDouble() * (size.x - 2 * r);
    add(
      Rock(
        radius: r,
        position: Vector2(x, -r),
        speed: scrollSpeed * (0.85 + _rng.nextDouble() * 0.4),
        rng: _rng,
      ),
    );
  }

  void _spawnCoin() {
    const r = Coin.radius;
    final x = r + 10 + _rng.nextDouble() * (size.x - 2 * (r + 10));
    add(Coin(position: Vector2(x, -r), speed: scrollSpeed * 0.9));
  }

  void _clearHazards() {
    removeAll(children.where((c) => c is Rock || c is Coin).toList());
  }

  // ---------------------------------------------------------------- effects

  void _explode(Vector2 at) {
    const colors = [Color(0xFFFF7043), Color(0xFFFFCA28), Color(0xFF4FC3F7)];
    add(
      ParticleSystemComponent(
        position: at,
        priority: 20,
        particle: Particle.generate(
          count: 40,
          lifespan: 0.9,
          generator: (i) {
            final a = _rng.nextDouble() * math.pi * 2;
            final s = 80 + _rng.nextDouble() * 260;
            return AcceleratedParticle(
              speed: Vector2(math.cos(a), math.sin(a)) * s,
              acceleration: Vector2(0, 220),
              child: CircleParticle(
                radius: 1.5 + _rng.nextDouble() * 3,
                paint: Paint()..color = colors[i % colors.length],
              ),
            );
          },
        ),
      ),
    );
  }

  void _sparkle(Vector2 at) {
    add(
      ParticleSystemComponent(
        position: at,
        priority: 20,
        particle: Particle.generate(
          count: 12,
          lifespan: 0.4,
          generator: (i) {
            final a = i / 12 * math.pi * 2;
            return AcceleratedParticle(
              speed: Vector2(math.cos(a), math.sin(a)) * 140,
              child: CircleParticle(
                radius: 2,
                paint: Paint()..color = const Color(0xFFFFE082),
              ),
            );
          },
        ),
      ),
    );
  }
}
