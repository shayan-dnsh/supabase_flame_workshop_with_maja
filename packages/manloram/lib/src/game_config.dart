import 'dart:ui';

class GameConfig {
  static const viewWidth = 960.0;
  static const viewHeight = 540.0;

  static const gravity = 1500.0;
  static const moveSpeed = 230.0;
  static const jumpSpeed = 640.0;

  /// A jump pressed this long before landing still happens on landing, and
  /// one pressed this long after walking off a ledge still leaves the ground,
  /// so a dodge is never lost to a few frames.
  static const jumpBufferSeconds = 0.12;
  static const coyoteSeconds = 0.1;

  static const maxHp = 100.0;
  static const headDamageMultiplier = 2.0;
  static const respawnSeconds = 3.0;
  static const spawnProtectionSeconds = 1.5;

  static const chargeSeconds = 0.9;
  static const minPower = 0.35;
  static const aimPreviewSeconds = 0.3;
  static const projectileTtl = 4.0;

  /// On-screen sticks on a phone, in screen pixels: big enough for a thumb
  /// on a small phone, and laid out on the whole screen rather than scaled
  /// with the arena.
  static const stickRadius = 56.0;

  /// How far a stick must be pushed, as a share of its radius, to walk,
  /// jump, drop off a ledge, or aim. Jump needs a clear push up so walking
  /// with a slightly raised thumb does not hop.
  static const stickWalkThreshold = 0.3;
  static const stickJumpThreshold = 0.55;
  static const stickDropThreshold = 0.6;
  static const stickAimDeadZone = 0.25;

  static const countdownSeconds = 4;

  /// Ledges slide this far either side of their place and back, once every
  /// [ledgeSwaySeconds], so a ledge is never a safe place to stand still.
  static const ledgeSwayPx = 40.0;
  static const ledgeSwaySeconds = 5;

  /// Seconds without a knockout before the difficulty level rises anyway.
  static const levelEverySeconds = int.fromEnvironment(
    'LEVEL_SECONDS',
    defaultValue: 30,
  );
  static const matchSeconds = 120;
  static const resultsSeconds = 15;
  static const finishDelay = Duration(milliseconds: 1500);

  static const stateSyncInterval = 0.05;
  static const keepaliveInterval = 1.0;
  static const remoteLerpFactorPerSecond = 14.0;
  static const remoteTeleportDistance = 160.0;

  static const playerColors = [
    Color(0xFFC0392B),
    Color(0xFFE6A23C),
    Color(0xFF1F8A8A),
    Color(0xFF3D4F9F),
    Color(0xFF6B8E23),
    Color(0xFF8E44AD),
    Color(0xFFD35400),
    Color(0xFF2E86C1),
  ];

  static const homeCities = [
    'Khorramabad',
    'Borujerd',
    'Dorud',
    'Aligudarz',
    'Kuhdasht',
    'Azna',
    'Nurabad',
    'Poldokhtar',
    'Aleshtar',
  ];
}
