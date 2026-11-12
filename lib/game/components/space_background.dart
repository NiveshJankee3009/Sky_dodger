import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sky_dodger_game.dart';

class _Drifter {
  _Drifter(this.sprite, this.x, this.y, this.size, this.speedFactor, this.opacity);
  final Sprite sprite;
  double x;
  double y;
  double size;
  final double speedFactor;
  final double opacity;
}

/// Deep-space backdrop behind the stars: slow nebula clouds and the odd
/// planet drifting past, all moving with the game's pace for parallax.
class SpaceBackground extends Component with HasGameReference<SkyDodgerGame> {
  SpaceBackground() : super(priority: -20);

  final _rng = math.Random();
  final _nebulae = <_Drifter>[];
  _Drifter? _planet;
  double _planetTimer = 2;
  final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  Future<void> onLoad() async {
    final w = game.size.x;
    final h = game.size.y;
    final sprites = game.sprites.nebulae;
    for (var i = 0; i < 3; i++) {
      final size = w * (1.1 + _rng.nextDouble() * 0.6);
      _nebulae.add(
        _Drifter(
          sprites[i % sprites.length],
          _rng.nextDouble() * w,
          h * (i / 3) + _rng.nextDouble() * h * 0.3,
          size,
          0.04 + _rng.nextDouble() * 0.03,
          0.55 + _rng.nextDouble() * 0.3,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    final h = game.size.y;
    final w = game.size.x;
    final speed = game.scrollSpeed;

    for (final n in _nebulae) {
      n.y += speed * n.speedFactor * dt;
      if (n.y - n.size / 2 > h) {
        n.size = w * (1.1 + _rng.nextDouble() * 0.6);
        n.y = -n.size / 2 - _rng.nextDouble() * h * 0.5;
        n.x = _rng.nextDouble() * w;
      }
    }

    final p = _planet;
    if (p != null) {
      p.y += speed * p.speedFactor * dt;
      if (p.y - p.size / 2 > h) _planet = null;
    } else {
      _planetTimer -= dt;
      if (_planetTimer <= 0) {
        _planetTimer = 8 + _rng.nextDouble() * 10;
        final planets = game.sprites.planets;
        final size = w * (0.22 + _rng.nextDouble() * 0.25);
        _planet = _Drifter(
          planets[_rng.nextInt(planets.length)],
          size * 0.3 + _rng.nextDouble() * (w - size * 0.6),
          -size / 2,
          size,
          0.10 + _rng.nextDouble() * 0.06,
          0.85,
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final n in _nebulae) {
      _draw(canvas, n);
    }
    final p = _planet;
    if (p != null) _draw(canvas, p);
  }

  void _draw(Canvas canvas, _Drifter d) {
    _paint.color = Color.fromRGBO(255, 255, 255, d.opacity);
    d.sprite.render(
      canvas,
      position: Vector2(d.x, d.y),
      size: Vector2.all(d.size),
      anchor: Anchor.center,
      overridePaint: _paint,
    );
  }
}
