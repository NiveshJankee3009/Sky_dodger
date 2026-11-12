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
    for (final s in _stars) {
      canvas.drawCircle(Offset(s.x, s.y), _radii[s.layer], _paints[s.layer]);
    }
  }
}
