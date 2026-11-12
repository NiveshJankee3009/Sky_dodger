import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_dodger/game/difficulty.dart';
import 'package:sky_dodger/game/high_score_store.dart';
import 'package:sky_dodger/online/online_rules.dart';

void main() {
  group('Difficulty', () {
    const d = Difficulty();

    test('starts at base values', () {
      expect(d.fallSpeed(0), Difficulty.baseSpeed);
      expect(d.spawnInterval(0), Difficulty.baseSpawnInterval);
    });

    test('gets harder over time', () {
      expect(d.fallSpeed(30), greaterThan(d.fallSpeed(0)));
      expect(d.spawnInterval(30), lessThan(d.spawnInterval(0)));
    });

    test('is capped', () {
      expect(d.fallSpeed(10000), Difficulty.maxSpeed);
      expect(d.spawnInterval(10000), Difficulty.minSpawnInterval);
      expect(d.coinInterval(10000), 1.4);
    });
  });

  group('ScoreKeeper', () {
    test('counts time and coins', () {
      final s = ScoreKeeper()
        ..tick(2.0)
        ..addCoin();
      expect(s.score, 2 * ScoreKeeper.pointsPerSecond + ScoreKeeper.coinBonus);
      expect(s.coins, 1);
      s.reset();
      expect(s.score, 0);
    });
  });

  group('HighScoreStore', () {
    test('only saves better scores', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await HighScoreStore.load();
      expect(store.best, 0);
      expect(await store.submit(120), isTrue);
      expect(await store.submit(80), isFalse);
      expect(store.best, 120);
    });
  });

  group('Nicknames', () {
    test('accepts good names', () {
      expect(validateNickname('Nivesh'), isNull);
      expect(validateNickname('ace_pilot_99'), isNull);
    });

    test('rejects bad names', () {
      expect(validateNickname('ab'), isNotNull);
      expect(validateNickname('a' * 16), isNotNull);
      expect(validateNickname('has space'), isNotNull);
      expect(validateNickname('12345'), isNotNull);
      expect(validateNickname('Sh1t_head'), isNotNull);
    });

    test('key is case-insensitive', () {
      expect(nicknameKey('  NiVeSh '), 'nivesh');
    });
  });

  group('isoWeekId', () {
    test('known dates', () {
      expect(isoWeekId(DateTime.utc(2026, 11, 12)), '2026-W46');
      expect(isoWeekId(DateTime.utc(2026, 1, 1)), '2026-W01');
      expect(isoWeekId(DateTime.utc(2027, 1, 1)), '2026-W53');
      expect(isoWeekId(DateTime.utc(2024, 12, 30)), '2025-W01');
    });

    test('changes on Monday 00:00 UTC', () {
      expect(isoWeekId(DateTime.utc(2026, 11, 15, 23, 59)), '2026-W46');
      expect(isoWeekId(DateTime.utc(2026, 11, 16)), '2026-W47');
    });
  });
}
