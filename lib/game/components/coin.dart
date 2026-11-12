import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../sky_dodger_game.dart';

/// A collectible coin that falls with the rocks.
class Coin extends PositionComponent with HasGameReference<SkyDodgerGame> {
  Coin({required Vector2 position, required this.speed})
      : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 2,
        );

  static const double radius = 13;
  final double speed;
  double _time = 0;

  static final _outer = Paint()..color = const Color(0xFFFFC107);
  static final _inner = Paint()..color = const Color(0xFFFFE082);
  static final _shine = Paint()..color = const Color(0xFFFFFFFF);

  @override
  Future<void> onLoad() async {
    add(
      CircleHitbox(
        radius: radius + 4, // generous pickup area
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    position.y += speed * dt;
    if (position.y - radius > game.size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Fake a spinning coin by squashing it horizontally.
    final squash = 0.35 + 0.65 * math.cos(_time * 5).abs();
    canvas.save();
    canvas.translate(radius, radius);
    canvas.scale(squash, 1);
    canvas.drawCircle(Offset.zero, radius, _outer);
    canvas.drawCircle(Offset.zero, radius * 0.66, _inner);
    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.35), radius * 0.18, _shine);
    canvas.restore();
  }
}
