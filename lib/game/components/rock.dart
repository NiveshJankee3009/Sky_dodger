import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../sky_dodger_game.dart';

/// A falling asteroid drawn from one of several sprites.
class Rock extends PositionComponent with HasGameReference<SkyDodgerGame> {
  Rock({
    required this.radius,
    required Vector2 position,
    required this.speed,
    required math.Random rng,
  })  : _spin = (rng.nextDouble() - 0.5) * 3,
        _drift = (rng.nextDouble() - 0.5) * 40,
        _variant = rng.nextInt(3),
        super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          angle: rng.nextDouble() * math.pi * 2,
        );

  final double radius;
  final double speed;
  final double _spin;
  final double _drift;
  final int _variant;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Average colour of this rock, used for debris when it explodes.
  Color get debrisColor => const [
        Color(0xFF8D6E63),
        Color(0xFF78909C),
        Color(0xFFA1887F),
      ][_variant];

  @override
  Future<void> onLoad() async {
    add(
      CircleHitbox(
        radius: radius * 0.75,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;
    position.x += _drift * dt;
    angle += _spin * dt;
    if (position.y - radius > game.size.y) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    game.sprites.rocks[_variant].render(canvas, size: size, overridePaint: _paint);
  }
}
