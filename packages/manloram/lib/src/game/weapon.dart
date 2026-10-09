import '../db/supabase_schema.g.dart';
import '../game_config.dart';

class Weapon {
  const Weapon({
    required this.id,
    required this.name,
    required this.damage,
    required this.speed,
    required this.cooldownMs,
    required this.bodyPoints,
    required this.headPoints,
  });

  factory Weapon.fromRow(WeaponsRow row) {
    return Weapon(
      id: row.id,
      name: row.name,
      damage: row.damage,
      speed: row.speed,
      cooldownMs: row.cooldownMs,
      bodyPoints: row.bodyPoints,
      headPoints: row.headPoints,
    );
  }

  static const stoneId = 'stone';
  static const ajorId = 'ajor';
  static const chubId = 'chub';

  static const stone = Weapon(
    id: stoneId,
    name: 'Stone',
    damage: 15,
    speed: 1100,
    cooldownMs: 450,
    bodyPoints: 10,
    headPoints: 25,
  );

  static const ajor = Weapon(
    id: ajorId,
    name: 'Ajor',
    damage: 40,
    speed: 950,
    cooldownMs: 1400,
    bodyPoints: 15,
    headPoints: 100,
  );

  /// The chub, the Lor fighting stick, swung up close.
  static const chub = Weapon(
    id: chubId,
    name: 'Chub',
    damage: 20,
    speed: 1,
    cooldownMs: 650,
    bodyPoints: 20,
    headPoints: 50,
  );

  /// How far in front of the player a chub swing reaches, in pixels.
  static const chubReach = 60.0;
  static const chubSwingSeconds = 0.28;

  final String id;
  final String name;
  final double damage;
  final double speed;
  final int cooldownMs;
  final int bodyPoints;
  final int headPoints;

  bool get isAjor => id == ajorId;

  bool get isChub => id == chubId;

  double get cooldownSeconds => cooldownMs / 1000;

  int pointsFor(BodyPart part) =>
      part == BodyPart.head ? headPoints : bodyPoints;

  double damageFor(BodyPart part) =>
      part == BodyPart.head ? damage * GameConfig.headDamageMultiplier : damage;

  /// How much a hit slows the player down, and for how long: a stone to the
  /// body barely, an Ajor to the head badly.
  ({double speed, double seconds}) slowFor(BodyPart part) {
    final head = part == BodyPart.head;
    if (isChub) {
      return head ? (speed: 0.35, seconds: 1.6) : (speed: 0.5, seconds: 1.0);
    }
    if (isAjor) {
      return head ? (speed: 0.3, seconds: 2.2) : (speed: 0.5, seconds: 1.4);
    }
    return head ? (speed: 0.45, seconds: 1.4) : (speed: 0.65, seconds: 0.8);
  }
}

class WeaponCatalog {
  WeaponCatalog({
    Weapon stone = Weapon.stone,
    Weapon ajor = Weapon.ajor,
    Weapon chub = Weapon.chub,
  }) : _byId = {stone.id: stone, ajor.id: ajor, chub.id: chub};

  final Map<String, Weapon> _byId;

  Weapon get stone => _byId[Weapon.stoneId]!;
  Weapon get ajor => _byId[Weapon.ajorId]!;
  Weapon get chub => _byId[Weapon.chubId]!;

  Weapon byId(String id) => _byId[id] ?? stone;

  void replaceWith(Iterable<Weapon> weapons) {
    for (final weapon in weapons) {
      if (_byId.containsKey(weapon.id)) {
        _byId[weapon.id] = weapon;
      }
    }
  }
}
