import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sky_dodger_game.dart';

class _Star {
  _Star(this.x, this.y, this.layer);
  double x;
  double y;
  final int layer; // 0 = far, 2 = near
}

/// Three-layer parallax starfield whose speed follows the game's pace.
class Starfield extends Component with HasGameReference<SkyDodgerGame> {
  Starfield() : super(priority: -10);

  static const int starCount = 90;
  final _rng = math.Random();
  final _stars = <_Star>[];

  static final _paints = [
    Paint()..color = const Color(0x66FFFFFF),
    Paint()..color = const Color(0x99FFFFFF),
    Paint()..color = const Color(0xFFFFFFFF),
  ];
  static const _radii = [0.8, 1.3, 2.0];
  static const _speedFactor = [0.15, 0.35, 0.7];

  // Soft nebula clouds behind the stars: (x, y, radius) as fractions of the
  // screen width/height, plus colour.
  static const _nebulae = [
    (0.15, 0.22, 0.85, Color(0x405E35B1)),
    (0.90, 0.50, 0.75, Color(0x30008C9E)),
    (0.35, 0.92, 0.80, Color(0x28AD1457)),
  ];
  final List<(Offset, double, Paint)> _nebulaPaints = [];

  void _buildNebulae(Vector2 size) {
    _nebulaPaints.clear();
    for (final (x, y, r, color) in _nebulae) {
      final c = Offset(size.x * x, size.y * y);
      final radius = size.x * r;
      _nebulaPaints.add((
        c,
        radius,
        Paint()
          ..shader = Gradient.radial(c, radius, [color, color.withAlpha(0)]),
      ));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _buildNebulae(size);
  }

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < starCount; i++) {
      _stars.add(
        _Star(
          _rng.nextDouble() * game.size.x,
          _rng.nextDouble() * game.size.y,
          _rng.nextInt(3),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    final base = game.scrollSpeed;
    for (final s in _stars) {
      s.y += base * _speedFactor[s.layer] * dt;
      if (s.y > game.size.y) {
        s.y -= game.size.y;
        s.x = _rng.nextDouble() * game.size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final (c, r, paint) in _nebulaPaints) {
      canvas.drawCircle(c, r, paint);
    }
    for (final s in _stars) {
      canvas.drawCircle(Offset(s.x, s.y), _radii[s.layer], _paints[s.layer]);
    }
  }
}
