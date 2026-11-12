import 'package:flutter/material.dart';

import '../game/sky_dodger_game.dart';

const _accent = Color(0xFF4FC3F7);
const _gold = Color(0xFFFFC107);

/// Title screen.
class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        const Text(
          'SKY\nDODGER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 56,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: _accent,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Drag anywhere to steer.\nDodge the rocks, grab the coins.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 28),
        _BestScore(best: game.highScores.best),
        const SizedBox(height: 28),
        _BigButton(label: 'PLAY', icon: Icons.play_arrow, onPressed: game.start),
      ],
    );
  }
}

/// In-game score display and pause button.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: game.score,
              builder: (context, value, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12, color: _gold),
                      const SizedBox(width: 6),
                      Text(
                        '${game.scoreKeeper.coins}',
                        style: const TextStyle(fontSize: 16, color: _gold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton.filledTonal(
              iconSize: 28,
              onPressed: game.pause,
              icon: const Icon(Icons.pause),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pause menu.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      dim: true,
      children: [
        const Text(
          'PAUSED',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        const SizedBox(height: 32),
        _BigButton(label: 'RESUME', icon: Icons.play_arrow, onPressed: game.resume),
        const SizedBox(height: 12),
        TextButton(onPressed: game.goToMenu, child: const Text('Quit to menu')),
      ],
    );
  }
}

/// Results screen.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    final record = game.lastRunWasRecord;
    return _Panel(
      dim: true,
      children: [
        const Text(
          'GAME OVER',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        const SizedBox(height: 20),
        Text(
          '${game.scoreKeeper.score}',
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _accent),
        ),
        Text(
          '${game.scoreKeeper.coins} coins  •  ${game.elapsed.toStringAsFixed(1)}s',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        if (record)
          const Text(
            'NEW BEST!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _gold),
          )
        else
          _BestScore(best: game.highScores.best),
        const SizedBox(height: 32),
        _BigButton(label: 'PLAY AGAIN', icon: Icons.replay, onPressed: game.start),
        const SizedBox(height: 12),
        TextButton(onPressed: game.goToMenu, child: const Text('Menu')),
      ],
    );
  }
}

// ------------------------------------------------------------------ helpers

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.dim = false});
  final List<Widget> children;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dim ? Colors.black54 : Colors.transparent,
      alignment: Alignment.center,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _BestScore extends StatelessWidget {
  const _BestScore({required this.best});
  final int best;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, color: _gold),
        const SizedBox(width: 8),
        Text('Best: $best', style: const TextStyle(fontSize: 20, color: _gold)),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 60,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
