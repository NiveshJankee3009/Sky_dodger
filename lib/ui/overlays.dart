import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/audio_manager.dart';
import '../game/sky_dodger_game.dart';
import '../online/online_service.dart';
import 'online_screens.dart';

const _cyan = Color(0xFF4FC3F7);
const _violet = Color(0xFFB388FF);
const _pink = Color(0xFFFF80AB);
const _gold = Color(0xFFFFC107);

// =================================================================== MENU

/// Title screen: glowing title, best score card, Play, music/sound toggles.
class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x660B1026), Color(0xCC0B1026)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: Column(
          children: [
            const Spacer(flex: 3),
            const _FloatingTitle(),
            const SizedBox(height: 14),
            Text(
              'Drift through the stars',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 2,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(flex: 2),
            _GlassCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: _gold, size: 30),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEST SCORE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${game.highScores.best}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _GlowButton(
              label: 'PLAY',
              icon: Icons.play_arrow_rounded,
              pulse: true,
              onPressed: game.start, // start() plays its own sound
            ),
            if (game.online.available) ...[
              const SizedBox(height: 14),
              _OutlineButton(
                label: 'LEADERBOARD',
                icon: Icons.leaderboard_rounded,
                onPressed: () {
                  game.audio.play(Sfx.click);
                  openLeaderboard(context, game.online);
                },
              ),
            ],
            const SizedBox(height: 30),
            _AudioToggles(audio: game.audio),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swipe_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Drag anywhere to steer  •  Grab the coins',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        )),
            if (game.online.available)
              Positioned(
                top: 8,
                right: 12,
                child: _AccountChip(game: game),
              ),
          ],
        ),
      ),
    );
  }
}

// =================================================================== HUD

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
                      shadows: [Shadow(color: _cyan, blurRadius: 12)],
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
            _RoundIconButton(
              icon: Icons.pause_rounded,
              onPressed: () {
                game.audio.play(Sfx.click);
                game.pause();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================== PAUSE

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return _Dimmed(
      child: _GlassCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GradientText('PAUSED', fontSize: 36),
            const SizedBox(height: 28),
            _GlowButton(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                game.audio.play(Sfx.click);
                game.resume();
              },
            ),
            const SizedBox(height: 24),
            _AudioToggles(audio: game.audio),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                game.audio.play(Sfx.click);
                game.goToMenu();
              },
              child: const Text('Quit to menu'),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================== GAME OVER

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    final record = game.lastRunWasRecord;
    return _Dimmed(
      child: _GlassCard(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GradientText('GAME OVER', fontSize: 34),
            const SizedBox(height: 16),
            Text(
              '${game.scoreKeeper.score}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: _cyan, blurRadius: 20)],
              ),
            ),
            Text(
              '${game.scoreKeeper.coins} coins  •  ${game.elapsed.toStringAsFixed(1)}s',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            if (record)
              const Text(
                '★ NEW BEST! ★',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                  shadows: [Shadow(color: _gold, blurRadius: 14)],
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: _gold),
                  const SizedBox(width: 8),
                  Text(
                    'Best: ${game.highScores.best}',
                    style: const TextStyle(fontSize: 18, color: _gold),
                  ),
                ],
              ),
            if (game.online.available) ...[
              const SizedBox(height: 12),
              _OnlineStatus(game: game),
            ],
            const SizedBox(height: 28),
            _GlowButton(
              label: 'PLAY AGAIN',
              icon: Icons.replay_rounded,
              onPressed: game.start,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                game.audio.play(Sfx.click);
                game.goToMenu();
              },
              child: const Text('Menu'),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================== ONLINE

/// Top-right chip on the menu: "Sign in" or the player's nickname.
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OnlinePlayer?>(
      valueListenable: game.online.player,
      builder: (context, player, _) {
        final label = player == null
            ? 'Sign in'
            : (player.nickname ?? 'Set nickname');
        return ActionChip(
          avatar: Icon(
            player == null ? Icons.login_rounded : Icons.person_rounded,
            size: 18,
            color: _cyan,
          ),
          label: Text(label),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          onPressed: () async {
            game.audio.play(Sfx.click);
            if (player?.nickname != null) {
              await openLeaderboard(context, game.online);
            } else {
              await ensureOnlineProfile(context, game.online);
            }
          },
        );
      },
    );
  }
}

/// Game-over line: leaderboard rank, or an invitation to sign in.
class _OnlineStatus extends StatelessWidget {
  const _OnlineStatus({required this.game});
  final SkyDodgerGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: game.onlineStatus,
      builder: (context, status, _) {
        if (status == null) return const SizedBox.shrink();
        if (status == 'signin') {
          return TextButton.icon(
            onPressed: () async {
              final score = game.scoreKeeper.score;
              if (await ensureOnlineProfile(context, game.online)) {
                game.onlineStatus.value = 'Sending to leaderboard…';
                final r = await game.online.submitScore(score);
                game.onlineStatus.value = r?.weeklyRank == null
                    ? 'Could not reach the leaderboard'
                    : '#${r!.weeklyRank} this week'
                        '${r.allTimeRank == null ? '' : '  •  #${r.allTimeRank} all time'}';
              }
            },
            icon: const Icon(Icons.leaderboard_rounded),
            label: const Text('Sign in to join the leaderboard'),
          );
        }
        return GestureDetector(
          onTap: () => openLeaderboard(context, game.online),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_rounded, color: _cyan, size: 18),
              const SizedBox(width: 6),
              Text(status, style: const TextStyle(color: _cyan, fontSize: 15)),
            ],
          ),
        );
      },
    );
  }
}

// =================================================================== PIECES

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: _violet.withValues(alpha: 0.8), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
      ),
    );
  }
}

/// Music and sound on/off buttons that remember their state.
class _AudioToggles extends StatelessWidget {
  const _AudioToggles({required this.audio});
  final AudioManager audio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: audio.musicOn,
          builder: (context, on, _) => _Toggle(
            label: 'Music',
            on: on,
            iconOn: Icons.music_note_rounded,
            iconOff: Icons.music_off_rounded,
            onTap: () {
              audio.play(Sfx.click);
              audio.toggleMusic();
            },
          ),
        ),
        const SizedBox(width: 28),
        ValueListenableBuilder<bool>(
          valueListenable: audio.soundOn,
          builder: (context, on, _) => _Toggle(
            label: 'Sound',
            on: on,
            iconOn: Icons.volume_up_rounded,
            iconOff: Icons.volume_off_rounded,
            onTap: audio.toggleSound,
          ),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.iconOn,
    required this.iconOff,
    required this.onTap,
  });

  final String label;
  final bool on;
  final IconData iconOn;
  final IconData iconOff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on
                  ? _cyan.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: on ? _cyan : Colors.white24,
                width: 2,
              ),
              boxShadow: on
                  ? [BoxShadow(color: _cyan.withValues(alpha: 0.45), blurRadius: 16)]
                  : const [],
            ),
            child: Icon(
              on ? iconOn : iconOff,
              size: 28,
              color: on ? Colors.white : Colors.white38,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          on ? '$label on' : '$label off',
          style: TextStyle(
            fontSize: 13,
            color: on ? Colors.white70 : Colors.white38,
          ),
        ),
      ],
    );
  }
}

/// Big title that gently floats up and down with a soft glow.
class _FloatingTitle extends StatefulWidget {
  const _FloatingTitle();

  @override
  State<_FloatingTitle> createState() => _FloatingTitleState();
}

class _FloatingTitleState extends State<_FloatingTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 6 * math.sin(_c.value * 2 * math.pi)),
        child: child,
      ),
      child: const _GradientText('SKY\nDODGER', fontSize: 64, glow: true),
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.fontSize, this.glow = false});
  final String text;
  final double fontSize;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 0.95,
      fontWeight: FontWeight.w900,
      letterSpacing: 5,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        if (glow)
          Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(
              color: Colors.transparent,
              shadows: [
                Shadow(color: _violet.withValues(alpha: 0.8), blurRadius: 30),
                Shadow(color: _cyan.withValues(alpha: 0.6), blurRadius: 12),
              ],
            ),
          ),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cyan, _violet, _pink],
          ).createShader(rect),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Gradient pill button with a glow; optionally breathes to draw the eye.
class _GlowButton extends StatefulWidget {
  const _GlowButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.pulse = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool pulse;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1 + 0.04 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: _violet.withValues(alpha: 0.35 + 0.25 * t),
                  blurRadius: 18 + 14 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 240,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(colors: [_cyan, _violet]),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: widget.onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 32, color: const Color(0xFF0B1026)),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Color(0xFF0B1026),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}

class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }
}
