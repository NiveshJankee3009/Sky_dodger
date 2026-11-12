import 'package:flutter/material.dart';

import '../online/online_rules.dart';
import '../online/online_service.dart';

const _bg = Color(0xFF0B1026);
const _cyan = Color(0xFF4FC3F7);
const _violet = Color(0xFFB388FF);
const _gold = Color(0xFFFFC107);

/// Opens the leaderboard on top of the game.
Future<void> openLeaderboard(BuildContext context, OnlineService online) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LeaderboardPage(online: online)),
  );
}

/// Makes sure the player is signed in and has a nickname.
/// Returns true when they're ready to appear on the leaderboard.
Future<bool> ensureOnlineProfile(
  BuildContext context,
  OnlineService online,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (online.player.value == null) {
    try {
      final ok = await online.signInWithGoogle();
      if (!ok) return false;
    } on OnlineException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }
  if (online.player.value?.nickname == null) {
    if (!context.mounted) return false;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NicknamePage(online: online)),
    );
    return saved ?? false;
  }
  return true;
}

// =================================================================== LEADERBOARD

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.online});
  final OnlineService online;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  Board _board = Board.weekly;
  late Future<LeaderboardData> _future = _load();

  Future<LeaderboardData> _load() => widget.online.fetch(_board);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          'LEADERBOARD',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<Board>(
              segments: const [
                ButtonSegment(
                  value: Board.weekly,
                  label: Text('This week'),
                  icon: Icon(Icons.calendar_today_rounded),
                ),
                ButtonSegment(
                  value: Board.allTime,
                  label: Text('All time'),
                  icon: Icon(Icons.emoji_events_rounded),
                ),
              ],
              selected: {_board},
              onSelectionChanged: (s) {
                _board = s.first;
                _reload();
              },
            ),
          ),
          _AccountBanner(online: widget.online, onChanged: _reload),
          Expanded(
            child: FutureBuilder<LeaderboardData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Message(
                    icon: Icons.cloud_off_rounded,
                    text: snap.error is OnlineException
                        ? (snap.error! as OnlineException).message
                        : 'Could not load the leaderboard.',
                    action: TextButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  );
                }
                final data = snap.data!;
                if (data.top.isEmpty) {
                  return _Message(
                    icon: Icons.rocket_launch_rounded,
                    text: _board == Board.weekly
                        ? 'No scores yet this week.\nBe the first!'
                        : 'No scores yet.\nBe the first!',
                  );
                }
                final myUid = widget.online.player.value?.uid;
                final meOutsideTop =
                    data.me != null && data.me!.rank > data.top.length;
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: data.top.length,
                        itemBuilder: (_, i) => _Row(
                          entry: data.top[i],
                          isMe: data.top[i].uid == myUid,
                        ),
                      ),
                    ),
                    if (meOutsideTop)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white24)),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        child: _Row(entry: data.me!, isMe: true),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _board == Board.weekly
                  ? 'Weekly board resets every Monday (04:00 Mauritius time)'
                  : 'Best score of every player',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final medal = switch (entry.rank) {
      1 => const Color(0xFFFFD54F),
      2 => const Color(0xFFCFD8DC),
      3 => const Color(0xFFFFAB91),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isMe
            ? _cyan.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isMe ? _cyan : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: medal != null
                ? Icon(Icons.military_tech_rounded, color: medal, size: 28)
                : Text(
                    '#${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              isMe ? '${entry.nickname} (you)' : entry.nickname,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${entry.score}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: medal ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Sign-in / nickname / signed-in-as strip at the top of the leaderboard.
class _AccountBanner extends StatelessWidget {
  const _AccountBanner({required this.online, required this.onChanged});
  final OnlineService online;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OnlinePlayer?>(
      valueListenable: online.player,
      builder: (context, player, _) {
        final Widget content;
        if (player == null) {
          content = Row(
            children: [
              const Expanded(
                child: Text('Sign in to put your name on the board'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (await ensureOnlineProfile(context, online)) onChanged();
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Google'),
              ),
            ],
          );
        } else if (player.nickname == null) {
          content = Row(
            children: [
              const Expanded(child: Text('Choose a nickname to join')),
              FilledButton(
                onPressed: () async {
                  if (await ensureOnlineProfile(context, online)) onChanged();
                },
                child: const Text('Set nickname'),
              ),
            ],
          );
        } else {
          content = Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _cyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Playing as ${player.nickname}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  if (v == 'rename') {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => NicknamePage(online: online),
                      ),
                    );
                  } else {
                    await online.signOut();
                  }
                  onChanged();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Change nickname')),
                  PopupMenuItem(value: 'signout', child: Text('Sign out')),
                ],
              ),
            ],
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                _violet.withValues(alpha: 0.18),
                _cyan.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: content,
        );
      },
    );
  }
}

// =================================================================== NICKNAME

class NicknamePage extends StatefulWidget {
  const NicknamePage({super.key, required this.online});
  final OnlineService online;

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.online.player.value?.nickname ?? '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = validateNickname(_ctrl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.online.setNickname(_ctrl.text);
      if (mounted) Navigator.of(context).pop(true);
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, title: const Text('Your nickname')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.badge_rounded, size: 56, color: _gold),
              const SizedBox(height: 16),
              const Text(
                'This name is shown on the global leaderboard.\n'
                'Your email is never shown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLength: 15,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Nickname',
                  helperText: '3–15 letters, numbers or _',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
