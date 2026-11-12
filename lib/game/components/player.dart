import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../sky_dodger_game.dart';
import 'coin.dart';
import 'rock.dart';

/// The player's ship. Follows horizontal drags and collides with rocks/coins.
class Player extends PositionComponent
    with CollisionCallbacks, HasGameReference<SkyDodgerGame> {
  Player() : super(size: Vector2(50, 61), anchor: Anchor.center, priority: 5);

  /// How far above the bottom edge the ship flies.
  static const double bottomMargin = 120;

  /// How quickly the ship catches up with the finger (higher = snappier).
  static const double followSharpness = 18;

  double _targetX = 0;
  double _time = 0;
  bool visible = true;

  final _flamePaint = Paint()..color = const Color(0xFFFFA726);
  final _flameCorePaint = Paint()..color = const Color(0xFFFFF59D);
  final _glowPaint = Paint()
    ..color = const Color(0x664FC3F7)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
  final _flameGlowPaint = Paint()
    ..color = const Color(0x99FF7043)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  Future<void> onLoad() async {
    // Hitbox is a bit smaller than the drawing so near-misses feel fair.
    add(
      CircleHitbox(
        radius: 14,
        position: Vector2(size.x / 2, size.y / 2 + 4),
        anchor: Anchor.center,
      ),
    );
    reset();
  }

  void reset() {
    visible = true;
    position = Vector2(game.size.x / 2, game.size.y - bottomMargin);
    _targetX = position.x;
    angle = 0;
  }

  /// Move the ship's target horizontally by [dx] pixels.
  void nudge(double dx) {
    _targetX = (_targetX + dx).clamp(size.x / 2, game.size.x - size.x / 2);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    position.y = size.y - bottomMargin;
    _targetX = _targetX.clamp(this.size.x / 2, size.x - this.size.x / 2);
    position.x = position.x.clamp(this.size.x / 2, size.x - this.size.x / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final dx = _targetX - position.x;
    final t = 1 - math.exp(-followSharpness * dt);
    position.x += dx * t;
    // Bank slightly in the direction of travel.
    angle = (dx / 220).clamp(-0.35, 0.35);
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final w = size.x;
    final h = size.y;

    // Soft glow around the ship.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.55), width: w * 1.1, height: h),
      _glowPaint,
    );

    // Engine flame (flickers), drawn behind the sprite.
    final flicker = 9 + 6 * math.sin(_time * 40).abs();
    final top = h * 0.84;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, top + flicker * 0.6),
        width: w * 0.3,
        height: flicker * 1.6,
      ),
      _flameGlowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.39, top)
        ..lineTo(w * 0.5, top + flicker + 8)
        ..lineTo(w * 0.61, top)
        ..close(),
      _flamePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.44, top)
        ..lineTo(w * 0.5, top + flicker * 0.6)
        ..lineTo(w * 0.56, top)
        ..close(),
      _flameCorePaint,
    );

    game.sprites.ship.render(canvas, size: size, overridePaint: _spritePaint);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (!visible) return;
    if (other is Rock) {
      game.crash();
    } else if (other is Coin) {
      game.collectCoin(other);
    }
  }
}
