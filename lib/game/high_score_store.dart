import 'package:shared_preferences/shared_preferences.dart';

/// Persists the best score on the device.
class HighScoreStore {
  HighScoreStore(this._prefs);

  static const _key = 'sky_dodger_high_score';
  final SharedPreferences _prefs;

  static Future<HighScoreStore> load() async =>
      HighScoreStore(await SharedPreferences.getInstance());

  int get best => _prefs.getInt(_key) ?? 0;

  /// Saves [score] if it beats the current best. Returns true on a new record.
  Future<bool> submit(int score) async {
    if (score <= best) return false;
    await _prefs.setInt(_key, score);
    return true;
  }
}
