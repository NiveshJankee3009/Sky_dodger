import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../sky_dodger_game.dart';

/// A falling asteroid. Drawn as a jagged polygon so each one looks different.
class Rock extends PositionComponent with HasGameReference<SkyDodgerGame> {
  Rock({
    required this.radius,
    required Vector2 position,
    required this.speed,
    required math.Random rng,
  })  : _spin = (rng.nextDouble() - 0.5) * 3,
        _drift = (rng.nextDouble() - 0.5) * 40,
        _path = _buildPath(radius, rng),
        super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  final double radius;
  final double speed;
  final double _spin;
  final double _drift;
  final Path _path;

  static final _fill = Paint()..color = const Color(0xFF8D6E63);
  static final _edge = Paint()
    ..color = const Color(0xFF5D4037)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _crater = Paint()..color = const Color(0xFF6D4C41);

  static Path _buildPath(double r, math.Random rng) {
    const points = 10;
    final path = Path();
    for (var i = 0; i < points; i++) {
      final a = i / points * math.pi * 2;
      final rr = r * (0.78 + rng.nextDouble() * 0.22);
      final p = Offset(r + math.cos(a) * rr, r + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

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
    canvas.drawPath(_path, _fill);
    canvas.drawPath(_path, _edge);
    canvas.drawCircle(Offset(radius * 0.7, radius * 0.8), radius * 0.18, _crater);
    canvas.drawCircle(Offset(radius * 1.3, radius * 1.2), radius * 0.12, _crater);
  }
}
