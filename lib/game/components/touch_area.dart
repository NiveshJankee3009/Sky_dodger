import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../sky_dodger_game.dart';

/// Invisible full-screen layer that turns drags anywhere into ship movement,
/// so the player's finger never has to cover the ship.
class TouchArea extends PositionComponent
    with DragCallbacks, HasGameReference<SkyDodgerGame> {
  TouchArea() : super(priority: 100);

  /// Ship moves slightly more than the finger for comfortable one-thumb play.
  static const double sensitivity = 1.25;

  @override
  Future<void> onLoad() async {
    size = game.size.clone();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (game.state == GameState.playing) {
      game.player.nudge(event.localDelta.x * sensitivity);
    }
  }
}
