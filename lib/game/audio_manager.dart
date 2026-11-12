import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Sfx { coin, crash, click, start, newBest }

/// Music and sound effects, with on/off settings saved on the device.
///
/// All playback is fire-and-forget and wrapped in try/catch: a sound that
/// fails to play must never break the game.
class AudioManager {
  AudioManager(this._prefs)
      : musicOn = ValueNotifier(_prefs.getBool(_musicKey) ?? true),
        soundOn = ValueNotifier(_prefs.getBool(_soundKey) ?? true);

  static const _musicKey = 'sky_dodger_music_on';
  static const _soundKey = 'sky_dodger_sound_on';

  static const _musicFile = 'music.mp3';
  static const double _musicVolume = 0.4;

  static const _files = {
    Sfx.coin: 'coin.mp3',
    Sfx.crash: 'crash.mp3',
    Sfx.click: 'click.mp3',
    Sfx.start: 'start.mp3',
    Sfx.newBest: 'new_best.mp3',
  };

  static const _volumes = {
    Sfx.coin: 0.55,
    Sfx.crash: 0.8,
    Sfx.click: 0.5,
    Sfx.start: 0.6,
    Sfx.newBest: 0.7,
  };

  final SharedPreferences _prefs;
  final ValueNotifier<bool> musicOn;
  final ValueNotifier<bool> soundOn;

  /// Pools for sounds that can overlap quickly (coins, button taps).
  final Map<Sfx, AudioPool> _pools = {};

  static Future<AudioManager> load() async =>
      AudioManager(await SharedPreferences.getInstance());

  Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll([_musicFile, ..._files.values]);
      _pools[Sfx.coin] =
          await FlameAudio.createPool(_files[Sfx.coin]!, maxPlayers: 4);
      _pools[Sfx.click] =
          await FlameAudio.createPool(_files[Sfx.click]!, maxPlayers: 2);
      await FlameAudio.bgm.initialize();
      if (musicOn.value) await _startMusic();
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  void play(Sfx sfx) {
    if (!soundOn.value) return;
    unawaited(_play(sfx));
  }

  Future<void> _play(Sfx sfx) async {
    final volume = _volumes[sfx]!;
    final pool = _pools[sfx];
    try {
      if (pool != null) {
        await pool.start(volume: volume);
      } else {
        await FlameAudio.play(_files[sfx]!, volume: volume);
      }
    } catch (e) {
      debugPrint('Could not play $sfx: $e');
    }
  }

  Future<void> toggleMusic() async {
    musicOn.value = !musicOn.value;
    await _prefs.setBool(_musicKey, musicOn.value);
    try {
      if (musicOn.value) {
        await _startMusic();
      } else {
        await FlameAudio.bgm.stop();
      }
    } catch (e) {
      debugPrint('Music toggle failed: $e');
    }
  }

  Future<void> toggleSound() async {
    soundOn.value = !soundOn.value;
    await _prefs.setBool(_soundKey, soundOn.value);
    if (soundOn.value) play(Sfx.click);
  }

  Future<void> _startMusic() =>
      FlameAudio.bgm.play(_musicFile, volume: _musicVolume);
}
