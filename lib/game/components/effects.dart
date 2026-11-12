import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import '../sky_dodger_game.dart';

/// Marker for short-lived visual effects that should be cleared when a new
/// round starts or the player returns to the menu.
mixin TransientEffect on Component {}

/// Full-screen flash that fades out (used on crash).
class ScreenFlash extends Component
    with HasGameReference<SkyDodgerGame>, TransientEffect {
  ScreenFlash({this.color = const Color(0xFFFFFFFF), this.duration = 0.35})
      : super(priority: 60);

  final Color color;
  final double duration;
  double _t = 0;
  final _paint = Paint();

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = (1 - _t / duration).clamp(0.0, 1.0) * 0.55;
    _paint.color = color.withValues(alpha: a);
    canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), _paint);
  }
}

/// Expanding ring (shockwave) at a point.
class Shockwave extends PositionComponent with TransientEffect {
  Shockwave({
    required Vector2 position,
    this.maxRadius = 170,
    this.duration = 0.55,
    this.color = const Color(0xFF4FC3F7),
  }) : super(position: position, priority: 21);

  final double maxRadius;
  final double duration;
  final Color color;
  double _t = 0;
  final _paint = Paint()..style = PaintingStyle.stroke;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - p, 3).toDouble();
    _paint
      ..strokeWidth = 10 * (1 - p) + 1
      ..color = color.withValues(alpha: (1 - p) * 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset.zero, maxRadius * eased, _paint);
  }
}

/// "+50" style text that floats up and fades.
class FloatingText extends PositionComponent with TransientEffect {
  FloatingText(
    String text, {
    required Vector2 position,
    Color color = const Color(0xFFFFD54F),
    double fontSize = 22,
  })  : _painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
        super(position: position, priority: 30);

  final TextPainter _painter;
  static const double duration = 0.8;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    position.y -= 70 * dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final alpha = p < 0.6 ? 1.0 : (1 - (p - 0.6) / 0.4);
    final scale = 0.8 + 0.4 * math.min(1, p * 5);
    canvas.save();
    canvas.scale(scale);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
    canvas.restore();
    canvas.restore();
  }
}

/// "3, 2, 1, GO!" before each round.
class CountdownText extends Component
    with HasGameReference<SkyDodgerGame>, TransientEffect {
  CountdownText() : super(priority: 40);

  static const double step = 0.6;
  static const labels = ['3', '2', '1', 'GO!'];
  static const double total = step * 4;

  double _t = 0;
  final _painters = <TextPainter>[
    for (final l in labels)
      TextPainter(
        text: TextSpan(
          text: l,
          style: TextStyle(
            color: l == 'GO!' ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF),
            fontSize: 96,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Color(0xFFB388FF), blurRadius: 24),
              Shadow(color: Color(0xFF4FC3F7), blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
  ];

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= total) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final i = (_t / step).floor().clamp(0, labels.length - 1);
    final local = (_t - i * step) / step; // 0..1 within this number
    final scale = 1.6 - 0.6 * math.min(1, local * 3);
    final alpha = local < 0.7 ? 1.0 : (1 - (local - 0.7) / 0.3);
    final painter = _painters[i];
    canvas.save();
    canvas.translate(game.size.x / 2, game.size.y * 0.4);
    canvas.scale(scale);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    canvas.restore();
  }
}

/// Glowing exhaust trail behind the ship.
class ShipTrail extends Component with HasGameReference<SkyDodgerGame> {
  ShipTrail() : super(priority: 4);

  static const int maxPoints = 22;
  final _points = <Offset>[];
  final _paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  @override
  void update(double dt) {
    final drift = game.scrollSpeed * dt * 0.9;
    for (var i = 0; i < _points.length; i++) {
      _points[i] = _points[i].translate(0, drift);
    }
    final player = game.player;
    if (player.visible && game.state != GameState.menu) {
      _points.insert(
        0,
        Offset(player.position.x, player.position.y + player.size.y * 0.45),
      );
    }
    while (_points.length > maxPoints) {
      _points.removeLast();
    }
    if (!player.visible && _points.isNotEmpty) _points.removeLast();
  }

  @override
  void render(Canvas canvas) {
    for (var i = _points.length - 1; i >= 0; i--) {
      final t = i / maxPoints;
      final color = Color.lerp(
        const Color(0xFF4FC3F7),
        const Color(0xFFB388FF),
        t,
      )!;
      _paint.color = color.withValues(alpha: (1 - t) * 0.55);
      canvas.drawCircle(_points[i], 7 * (1 - t) + 1.5, _paint);
    }
  }
}
