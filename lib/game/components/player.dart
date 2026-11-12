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
  Player() : super(size: Vector2(44, 54), anchor: Anchor.center, priority: 5);

  /// How far above the bottom edge the ship flies.
  static const double bottomMargin = 120;

  /// How quickly the ship catches up with the finger (higher = snappier).
  static const double followSharpness = 18;

  double _targetX = 0;
  double _time = 0;
  bool visible = true;

  final _hullPaint = Paint()..color = const Color(0xFF4FC3F7);
  final _wingPaint = Paint()..color = const Color(0xFF0288D1);
  final _cockpitPaint = Paint()..color = const Color(0xFFE1F5FE);
  final _flamePaint = Paint()..color = const Color(0xFFFFA726);
  final _flameCorePaint = Paint()..color = const Color(0xFFFFF59D);

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

    // Engine flame (flickers).
    final flicker = 8 + 5 * math.sin(_time * 40).abs();
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.36, h * 0.86)
        ..lineTo(w * 0.5, h * 0.86 + flicker + 6)
        ..lineTo(w * 0.64, h * 0.86)
        ..close(),
      _flamePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.43, h * 0.86)
        ..lineTo(w * 0.5, h * 0.86 + flicker * 0.6)
        ..lineTo(w * 0.57, h * 0.86)
        ..close(),
      _flameCorePaint,
    );

    // Wings.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.35)
        ..lineTo(w, h * 0.82)
        ..lineTo(w * 0.62, h * 0.78)
        ..lineTo(w * 0.38, h * 0.78)
        ..lineTo(0, h * 0.82)
        ..close(),
      _wingPaint,
    );

    // Hull.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, 0)
        ..quadraticBezierTo(w * 0.72, h * 0.45, w * 0.64, h * 0.88)
        ..lineTo(w * 0.36, h * 0.88)
        ..quadraticBezierTo(w * 0.28, h * 0.45, w * 0.5, 0)
        ..close(),
      _hullPaint,
    );

    // Cockpit.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: 10, height: 16),
      _cockpitPaint,
    );
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
