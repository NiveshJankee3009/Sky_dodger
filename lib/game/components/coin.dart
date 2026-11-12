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

  static const double radius = 14;
  final double speed;
  double _time = 0;

  static final _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  static final _spritePaint = Paint()..filterQuality = FilterQuality.medium;
  static final _spriteSize = Vector2.all(radius * 2);
  static final _spritePos = Vector2.all(-radius);

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
    // Pulsing golden halo.
    final pulse = 0.35 + 0.2 * math.sin(_time * 6);
    _glow.color = Color.fromRGBO(255, 202, 40, pulse);
    canvas.drawCircle(const Offset(radius, radius), radius * 1.3, _glow);

    // Fake a spinning coin by squashing it horizontally.
    final squash = 0.3 + 0.7 * math.cos(_time * 4.5).abs();
    canvas.save();
    canvas.translate(radius, radius);
    canvas.scale(squash, 1);
    game.sprites.coin.render(
      canvas,
      position: _spritePos,
      size: _spriteSize,
      overridePaint: _spritePaint,
    );
    canvas.restore();
  }
}
