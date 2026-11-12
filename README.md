# Sky Dodger 🚀

A casual arcade game for Android and iOS, built with [Flutter](https://flutter.dev) and the [Flame](https://flame-engine.org) game engine.

Drag anywhere on the screen to steer your ship, dodge the falling rocks and grab coins. The longer you survive, the faster it gets. Your best score is saved on the device.

## Features

- One-thumb drag controls (drag anywhere, the ship follows smoothly and banks)
- Difficulty that ramps up over time (speed and spawn rate)
- Coins worth bonus points, with sparkle effect
- Explosion particles and haptic feedback
- Pause menu (also pauses automatically when you leave the app)
- High score saved locally
- No image assets: everything is drawn in code, so the repo stays tiny

## Run it locally

Requires the Flutter SDK (3.41 or newer).

```bash
git clone https://github.com/<your-username>/sky_dodger.git
cd sky_dodger
flutter create --platforms=android,ios --org com.github.skydodger --project-name sky_dodger .   # first time only
flutter pub get
flutter run
```

`flutter create .` adds the `android/` and `ios/` folders without touching the game code. Commit them afterwards if you want to customise the app icon, name or signing.

## Download the APK

Every push to `main` is built by GitHub Actions (see `.github/workflows/build.yml`): it analyzes, tests and builds a release APK. Grab it from the **Actions** tab → latest run → **Artifacts**.

Push a version tag to publish the APK on the **Releases** page:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Project layout

```
lib/
  main.dart                    App entry, overlays wiring, portrait lock
  game/
    sky_dodger_game.dart       Game loop, state, spawning, effects
    difficulty.dart            Difficulty curve + score keeping (pure Dart)
    high_score_store.dart      Best score persistence
    components/
      player.dart              Ship: movement, drawing, collisions
      rock.dart                Falling asteroids
      coin.dart                Collectible coins
      starfield.dart           Parallax background
      touch_area.dart          Full-screen drag input
  ui/
    overlays.dart              Menu, HUD, pause and game-over screens
test/
  widget_test.dart             Unit tests for difficulty, score and high score
```

## Tweaking

Most of the feel lives in `lib/game/difficulty.dart` (speeds, spawn rates, points) and the constants at the top of `player.dart` and `touch_area.dart` (follow speed, drag sensitivity).

## Licence

MIT
