import 'package:flame/cache.dart';
import 'package:flame/components.dart';

/// All sprite artwork, loaded once at start-up (see tool/make_sprites.py).
class GameSprites {
  GameSprites({
    required this.ship,
    required this.coin,
    required this.rocks,
    required this.planets,
    required this.nebulae,
  });

  final Sprite ship;
  final Sprite coin;
  final List<Sprite> rocks;
  final List<Sprite> planets;
  final List<Sprite> nebulae;

  static Future<GameSprites> load(Images images) async {
    Future<Sprite> s(String file) async => Sprite(await images.load(file));
    return GameSprites(
      ship: await s('ship.png'),
      coin: await s('coin.png'),
      rocks: [for (var i = 0; i < 3; i++) await s('rock_$i.png')],
      planets: [for (var i = 0; i < 3; i++) await s('planet_$i.png')],
      nebulae: [for (var i = 0; i < 2; i++) await s('nebula_$i.png')],
    );
  }
}
