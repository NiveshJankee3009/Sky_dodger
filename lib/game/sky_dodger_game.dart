import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'components/coin.dart';
import 'components/effects.dart';
import 'components/player.dart';
import 'components/rock.dart';
import 'components/space_background.dart';
import 'components/starfield.dart';
import 'components/touch_area.dart';
import 'audio_manager.dart';
import 'difficulty.dart';
import 'game_sprites.dart';
import 'high_score_store.dart';
import '../online/online_service.dart';

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
    required this.online,
    math.Random? random,
  }) : _rng = random ?? math.Random();

  final HighScoreStore highScores;
  final AudioManager audio;
  final OnlineService online;

  /// Leaderboard result for the last run, shown on the game-over screen.
  final ValueNotifier<String?> onlineStatus = ValueNotifier(null);
  final math.Random _rng;
  final Difficulty difficulty = const Difficulty();
  final ScoreKeeper scoreKeeper = ScoreKeeper();

  /// Live score for the Flutter HUD.
  final ValueNotifier<int> score = ValueNotifier(0);

  late final Player player;
  late final GameSprites sprites;
  GameState state = GameState.menu;
  bool lastRunWasRecord = false;

  double elapsed = 0;
  double _rockTimer = 0;
  double _coinTimer = 0;
  double _countdown = 0;

  // Screen shake.
  double _shakeTime = 0;
  double _shakeDuration = 1;
  double _shakeStrength = 0;
  Offset _shakeOffset = Offset.zero;

  /// Speed used by the starfield; idles slowly on menus.
  double get scrollSpeed =>
      state == GameState.playing ? difficulty.fallSpeed(elapsed) : 90;

  @override
  Color backgroundColor() => const Color(0xFF0B1026);

  @override
  Future<void> onLoad() async {
    sprites = await GameSprites.load(images);
    player = Player();
    await addAll([
      SpaceBackground(),
      Starfield(),
      ShipTrail(),
      player,
      TouchArea(),
    ]);
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
    onlineStatus.value = null;
    player.reset();
    state = GameState.playing;
    _countdown = CountdownText.total;
    add(CountdownText());
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
    final at = player.position.clone();
    _explode(at);
    shake(strength: 14, duration: 0.5);
    add(ScreenFlash());
    add(Shockwave(position: at, color: const Color(0xFFFF8A65)));

    lastRunWasRecord = await highScores.submit(scoreKeeper.score);
    unawaited(_submitOnline(scoreKeeper.score));

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

  Future<void> _submitOnline(int finalScore) async {
    if (!online.available) return;
    final p = online.player.value;
    if (p == null || p.nickname == null) {
      onlineStatus.value = 'signin';
      return;
    }
    onlineStatus.value = 'Sending to leaderboard…';
    final result = await online.submitScore(finalScore);
    if (result == null || result.weeklyRank == null) {
      onlineStatus.value = 'Could not reach the leaderboard';
      return;
    }
    final allTime =
        result.allTimeRank == null ? '' : '  •  #${result.allTimeRank} all time';
    onlineStatus.value = '#${result.weeklyRank} this week$allTime';
  }

  void collectCoin(Coin coin) {
    if (state != GameState.playing || coin.isRemoving) return;
    coin.removeFromParent();
    scoreKeeper.addCoin();
    score.value = scoreKeeper.score;
    HapticFeedback.selectionClick();
    audio.play(Sfx.coin);
    add(
      FloatingText(
        '+${ScoreKeeper.coinBonus}',
        position: coin.position.clone(),
      ),
    );
    _sparkle(coin.position.clone());
  }

  // ---------------------------------------------------------------- loop

  /// Shakes the whole scene for [duration] seconds.
  void shake({double strength = 10, double duration = 0.4}) {
    _shakeStrength = strength;
    _shakeDuration = duration;
    _shakeTime = duration;
  }

  @override
  void render(Canvas canvas) {
    if (_shakeOffset == Offset.zero) {
      super.render(canvas);
      return;
    }
    canvas.save();
    canvas.translate(_shakeOffset.dx, _shakeOffset.dy);
    super.render(canvas);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final k = (_shakeTime / _shakeDuration).clamp(0.0, 1.0) * _shakeStrength;
      _shakeOffset = Offset(
        (_rng.nextDouble() * 2 - 1) * k,
        (_rng.nextDouble() * 2 - 1) * k,
      );
    } else {
      _shakeOffset = Offset.zero;
    }

    if (state != GameState.playing) return;
    if (_countdown > 0) {
      _countdown -= dt; // "3, 2, 1, GO!" - no spawning or scoring yet
      return;
    }

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
    removeAll(
      children
          .where((c) => c is Rock || c is Coin || c is TransientEffect)
          .toList(),
    );
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

    // Ship debris: spinning shards in the ship's colours.
    const shardColors = [Color(0xFFFFFFFF), Color(0xFFB388FF), Color(0xFF4FC3F7)];
    add(
      ParticleSystemComponent(
        position: at,
        priority: 20,
        particle: Particle.generate(
          count: 14,
          lifespan: 1.2,
          generator: (i) {
            final a = _rng.nextDouble() * math.pi * 2;
            final speed = 60 + _rng.nextDouble() * 180;
            final w = 4 + _rng.nextDouble() * 7;
            final h = 2 + _rng.nextDouble() * 4;
            final paint = Paint()..color = shardColors[i % shardColors.length];
            return AcceleratedParticle(
              speed: Vector2(math.cos(a), math.sin(a)) * speed,
              acceleration: Vector2(0, 160),
              child: RotatingParticle(
                to: (_rng.nextDouble() - 0.5) * 16,
                child: ComputedParticle(
                  renderer: (canvas, particle) {
                    paint.color = paint.color.withValues(
                      alpha: (1 - particle.progress).clamp(0.0, 1.0),
                    );
                    canvas.drawRect(
                      Rect.fromCenter(center: Offset.zero, width: w, height: h),
                      paint,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    // Glowing embers that drift and fade.
    add(
      ParticleSystemComponent(
        position: at,
        priority: 19,
        particle: Particle.generate(
          count: 18,
          lifespan: 1.4,
          generator: (i) {
            final a = _rng.nextDouble() * math.pi * 2;
            final speed = 20 + _rng.nextDouble() * 90;
            final paint = Paint()
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
            final radius = 4 + _rng.nextDouble() * 6;
            return AcceleratedParticle(
              speed: Vector2(math.cos(a), math.sin(a)) * speed,
              acceleration: Vector2(0, -20),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final t = particle.progress;
                  paint.color = Color.lerp(
                    const Color(0xFFFFE082),
                    const Color(0xFFFF5252),
                    t,
                  )!
                      .withValues(alpha: (1 - t) * 0.8);
                  canvas.drawCircle(Offset.zero, radius * (1 - t * 0.5), paint);
                },
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
