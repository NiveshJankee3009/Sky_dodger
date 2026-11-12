import 'dart:math' as math;

/// Pure difficulty curve, kept free of Flame so it is easy to unit test.
class Difficulty {
  const Difficulty();

  static const double baseSpeed = 200;
  static const double maxSpeed = 700;
  static const double speedPerSecond = 7;

  static const double baseSpawnInterval = 0.95;
  static const double minSpawnInterval = 0.28;
  static const double spawnDecayPerSecond = 0.011;

  /// Falling speed (pixels/second) after [elapsed] seconds of play.
  double fallSpeed(double elapsed) =>
      math.min(maxSpeed, baseSpeed + elapsed * speedPerSecond);

  /// Seconds between rock spawns after [elapsed] seconds of play.
  double spawnInterval(double elapsed) => math.max(
        minSpawnInterval,
        baseSpawnInterval - elapsed * spawnDecayPerSecond,
      );

  /// Seconds between coin spawns (roughly constant, slightly faster later).
  double coinInterval(double elapsed) =>
      math.max(1.4, 2.6 - elapsed * 0.01);
}

/// Score bookkeeping: points for survival time plus coin bonuses.
class ScoreKeeper {
  static const int pointsPerSecond = 10;
  static const int coinBonus = 50;

  double _timePoints = 0;
  int _coins = 0;

  int get coins => _coins;
  int get score => _timePoints.floor() + _coins * coinBonus;

  void tick(double dt) => _timePoints += dt * pointsPerSecond;
  void addCoin() => _coins++;

  void reset() {
    _timePoints = 0;
    _coins = 0;
  }
}
