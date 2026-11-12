import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'online_rules.dart';

/// The signed-in player. [nickname] is null until they pick one.
@immutable
class OnlinePlayer {
  const OnlinePlayer({required this.uid, this.nickname});
  final String uid;
  final String? nickname;
}

enum Board { weekly, allTime }

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.nickname,
    required this.score,
    required this.rank,
  });

  final String uid;
  final String nickname;
  final int score;
  final int rank;
}

@immutable
class LeaderboardData {
  const LeaderboardData({required this.top, this.me});

  /// Best players, highest score first.
  final List<LeaderboardEntry> top;

  /// The signed-in player's own entry (also when outside the top list).
  final LeaderboardEntry? me;
}

/// Ranks after submitting a score (null when not on that board).
@immutable
class SubmitResult {
  const SubmitResult({this.weeklyRank, this.allTimeRank});
  final int? weeklyRank;
  final int? allTimeRank;
}

/// Thrown with a player-friendly message.
class OnlineException implements Exception {
  const OnlineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google sign-in, nicknames and the global leaderboard (Firebase).
///
/// Data layout in Firestore:
///   users/{uid}                          nickname, nicknameKey, createdAt
///   nicknames/{nicknameKey}              uid   (keeps nicknames unique)
///   leaderboard_alltime/{uid}            nickname, score, updatedAt
///   leaderboard_weekly/{week}/entries/{uid}   same fields, week = "2026-W46"
class OnlineService {
  static const int topCount = 50;

  /// False when Firebase isn't configured or failed to start; the game then
  /// simply hides the online features.
  bool get available => _available;
  bool _available = false;

  final ValueNotifier<OnlinePlayer?> player = ValueNotifier(null);

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      await GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? GoogleSignInIds.iosClientId
            : null,
        serverClientId: GoogleSignInIds.serverClientId,
      );
      _available = true;
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_loadPlayer);
    } catch (e) {
      debugPrint('Online features unavailable: $e');
    }
  }

  void dispose() => _authSub?.cancel();

  Future<void> _loadPlayer(User? user) async {
    if (user == null) {
      player.value = null;
      return;
    }
    if (player.value?.uid != user.uid) {
      player.value = OnlinePlayer(uid: user.uid);
    }
    try {
      final snap = await _db.doc('users/${user.uid}').get();
      player.value = OnlinePlayer(
        uid: user.uid,
        nickname: snap.data()?['nickname'] as String?,
      );
    } catch (e) {
      debugPrint('Could not load profile: $e');
    }
  }

  // ------------------------------------------------------------- sign in/out

  /// Returns normally on success; throws [OnlineException] with a message to
  /// show. Returns false if the player cancelled.
  Future<bool> signInWithGoogle() async {
    if (!_available) {
      throw const OnlineException('Online features are not available.');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const OnlineException('Google did not return a sign-in token.');
      }
      final cred = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      await _loadPlayer(cred.user);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      debugPrint('Google sign-in error: ${e.code} ${e.description}');
      throw OnlineException('Google sign-in failed (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase auth error: ${e.code} ${e.message}');
      throw OnlineException('Sign-in failed (${e.code}).');
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  // ------------------------------------------------------------- nickname

  /// Claims [nickname] for the signed-in player (or renames them).
  Future<void> setNickname(String nickname) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const OnlineException('Please sign in first.');
    final nick = nickname.trim();
    final problem = validateNickname(nick);
    if (problem != null) throw OnlineException(problem);
    final key = nicknameKey(nick);

    bool claimed;
    try {
      claimed = await _db.runTransaction<bool>((tx) async {
        final nickRef = _db.doc('nicknames/$key');
        final userRef = _db.doc('users/$uid');
        final nickSnap = await tx.get(nickRef);
        final userSnap = await tx.get(userRef);

        if (nickSnap.exists && nickSnap.data()?['uid'] != uid) return false;
        final oldKey = userSnap.data()?['nicknameKey'] as String?;
        if (oldKey != null && oldKey != key) {
          tx.delete(_db.doc('nicknames/$oldKey'));
        }
        if (!nickSnap.exists) tx.set(nickRef, {'uid': uid});
        tx.set(userRef, {
          'nickname': nick,
          'nicknameKey': key,
          'createdAt':
              userSnap.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException catch (e) {
      debugPrint('setNickname failed: ${e.code} ${e.message}');
      throw const OnlineException('Could not save the nickname. Try again.');
    }
    if (!claimed) throw const OnlineException('That nickname is taken.');

    player.value = OnlinePlayer(uid: uid, nickname: nick);
    await _renameEntries(uid, nick);
  }

  /// Keeps existing leaderboard rows in sync after a nickname change.
  Future<void> _renameEntries(String uid, String nick) async {
    for (final ref in [_allTimeRef.doc(uid), _weeklyRef().doc(uid)]) {
      try {
        final snap = await ref.get();
        final data = snap.data();
        if (data == null || data['nickname'] == nick) continue;
        await ref.set({
          'nickname': nick,
          'score': data['score'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Rename entry failed: $e');
      }
    }
  }

  // ------------------------------------------------------------- scores

  CollectionReference<Map<String, dynamic>> get _allTimeRef =>
      _db.collection('leaderboard_alltime');

  CollectionReference<Map<String, dynamic>> _weeklyRef([DateTime? now]) => _db
      .collection('leaderboard_weekly')
      .doc(isoWeekId(now ?? DateTime.now()))
      .collection('entries');

  CollectionReference<Map<String, dynamic>> _ref(Board board) =>
      board == Board.weekly ? _weeklyRef() : _allTimeRef;

  /// Records [score] on both boards if it beats the player's previous best.
  /// Returns null when the player can't submit (not signed in / no nickname).
  Future<SubmitResult?> submitScore(int score) async {
    final p = player.value;
    if (!_available || p == null || p.nickname == null) return null;
    if (score <= 0 || score > maxAcceptedScore) return null;

    final weekly = await _submitTo(_weeklyRef(), p, score);
    final allTime = await _submitTo(_allTimeRef, p, score);
    return SubmitResult(weeklyRank: weekly, allTimeRank: allTime);
  }

  /// Returns the player's rank on that board afterwards.
  Future<int?> _submitTo(
    CollectionReference<Map<String, dynamic>> col,
    OnlinePlayer p,
    int score,
  ) async {
    final ref = col.doc(p.uid);
    try {
      final best = await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        final old = (snap.data()?['score'] as num?)?.toInt() ?? 0;
        if (snap.exists && score <= old) return old;
        tx.set(ref, {
          'nickname': p.nickname,
          'score': score,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return score;
      });
      return await _rankOf(col, best);
    } catch (e) {
      debugPrint('Score submit failed: $e');
      return null;
    }
  }

  Future<int?> _rankOf(
    CollectionReference<Map<String, dynamic>> col,
    int score,
  ) async {
    try {
      final agg = await col.where('score', isGreaterThan: score).count().get();
      return (agg.count ?? 0) + 1;
    } catch (e) {
      debugPrint('Rank query failed: $e');
      return null;
    }
  }

  Future<LeaderboardData> fetch(Board board) async {
    if (!_available) {
      throw const OnlineException('Online features are not available.');
    }
    final col = _ref(board);
    try {
      final snap = await col
          .orderBy('score', descending: true)
          .limit(topCount)
          .get();
      final top = <LeaderboardEntry>[];
      for (final (i, doc) in snap.docs.indexed) {
        final d = doc.data();
        top.add(
          LeaderboardEntry(
            uid: doc.id,
            nickname: d['nickname'] as String? ?? '???',
            score: (d['score'] as num?)?.toInt() ?? 0,
            rank: i + 1,
          ),
        );
      }

      LeaderboardEntry? me;
      final p = player.value;
      if (p != null) {
        me = top.where((e) => e.uid == p.uid).firstOrNull;
        if (me == null) {
          final mine = await col.doc(p.uid).get();
          final score = (mine.data()?['score'] as num?)?.toInt();
          if (score != null) {
            me = LeaderboardEntry(
              uid: p.uid,
              nickname: p.nickname ?? '',
              score: score,
              rank: await _rankOf(col, score) ?? 0,
            );
          }
        }
      }
      return LeaderboardData(top: top, me: me);
    } on FirebaseException catch (e) {
      debugPrint('Leaderboard fetch failed: ${e.code} ${e.message}');
      throw const OnlineException('Could not load the leaderboard.');
    }
  }
}
