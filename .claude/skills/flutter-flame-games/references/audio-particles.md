# Audio & Particle Effects

Complete guide to audio management and visual effects.

## Audio System

### Setup

```yaml
dependencies:
  flame_audio: ^2.1.0
```

### Supported Formats

| Format | Platform Support |
|--------|-----------------|
| MP3 | All platforms |
| OGG | All platforms |
| WAV | All platforms (best for SFX) |
| AAC | iOS/macOS only |

### Audio Cache

Preload audio files to prevent runtime lag:

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    // Preload individual files
    await FlameAudio.audioCache.load('jump.wav');
    await FlameAudio.audioCache.load('coin.wav');
    
    // Preload all in directory
    await FlameAudio.audioCache.loadAll([
      'jump.wav',
      'coin.wav',
      'explosion.wav',
      'bgm.mp3',
    ]);
  }
}
```

### Background Music (BGM)

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    // Initialize BGM system
    await FlameAudio.bgm.initialize();
    
    // Play background music
    await FlameAudio.bgm.play('bgm.mp3');
    
    // With options
    await FlameAudio.bgm.play(
      'bgm.mp3',
      volume: 0.5,
    );
  }
  
  void pauseMusic() => FlameAudio.bgm.pause();
  void resumeMusic() => FlameAudio.bgm.resume();
  void stopMusic() => FlameAudio.bgm.stop();
  
  @override
  void onRemove() {
    FlameAudio.bgm.dispose();
    super.onRemove();
  }
}
```

### Sound Effects (SFX)

```dart
class Player extends PositionComponent {
  void jump() {
    // Play one-shot sound
    FlameAudio.play('jump.wav');
    
    // With volume (0.0 to 1.0)
    FlameAudio.play('jump.wav', volume: 0.8);
    
    velocity.y = -300;
  }
  
  void collectCoin() {
    FlameAudio.play('coin.wav', volume: 0.5);
  }
}
```

### Audio Pools (For Rapid Sounds)

Prevents audio cutting off when played rapidly:

```dart
class Weapon extends Component {
  late final AudioPool shootPool;
  
  @override
  Future<void> onLoad() async {
    shootPool = await FlameAudio.createPool(
      'shoot.wav',
      minPlayers: 3,
      maxPlayers: 5,
    );
  }
  
  void shoot() {
    shootPool.start(volume: 0.7);
  }
}
```

### Audio with Component Lifecycle

```dart
class GameAudio extends Component {
  static const double sfxVolume = 0.8;
  static const double musicVolume = 0.5;
  
  @override
  Future<void> onLoad() async {
    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll([
      'bgm.mp3',
      'jump.wav',
      'coin.wav',
    ]);
  }
  
  void playBGM(String file) {
    FlameAudio.bgm.play(file, volume: musicVolume);
  }
  
  void playSFX(String file, {double? volume}) {
    FlameAudio.play(file, volume: volume ?? sfxVolume);
  }
  
  @override
  void onRemove() {
    FlameAudio.bgm.dispose();
  }
}
```

### Dynamic Audio

```dart
class DynamicAudio extends Component {
  // Play different sounds based on context
  void playFootstep(String groundType) {
    switch (groundType) {
      case 'grass':
        FlameAudio.play('step_grass.wav');
      case 'wood':
        FlameAudio.play('step_wood.wav');
      case 'metal':
        FlameAudio.play('step_metal.wav');
    }
  }
  
  // Random variation
  void playHit() {
    final variant = Random().nextInt(3) + 1;
    FlameAudio.play('hit_$variant.wav');
  }
}
```

### Spatial Audio (Simulated)

```dart
class SpatialAudio extends Component {
  void playAtPosition(String sound, Vector2 sourcePos, Vector2 listenerPos) {
    final distance = (sourcePos - listenerPos).length;
    final maxDistance = 500;
    
    // Calculate volume based on distance
    final volume = (1 - (distance / maxDistance)).clamp(0.0, 1.0);
    
    // Calculate pan based on relative x position
    final direction = (sourcePos - listenerPos).normalized();
    final pan = direction.x;
    
    if (volume > 0) {
      FlameAudio.play(sound, volume: volume);
      // Note: Pan requires platform-specific implementation
    }
  }
}
```

### Audio Settings Manager

```dart
class AudioSettings extends ChangeNotifier {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.5;
  double _sfxVolume = 0.8;
  
  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  
  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (value) {
      FlameAudio.bgm.resume();
    } else {
      FlameAudio.bgm.pause();
    }
    notifyListeners();
  }
  
  set musicVolume(double value) {
    _musicVolume = value;
    FlameAudio.bgm.audioPlayer.setVolume(value);
    notifyListeners();
  }
  
  void playSFX(String file) {
    if (_sfxEnabled) {
      FlameAudio.play(file, volume: _sfxVolume);
    }
  }
}
```

## Particle Effects

### Basic Particle

```dart
import 'package:flame/particles.dart';

class SimpleExplosion extends ParticleSystemComponent {
  SimpleExplosion({required Vector2 position})
      : super(
          position: position,
          particle: Particle.generate(
            count: 20,
            lifespan: 0.5,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 200), // Gravity
              speed: Vector2.random() * 200 - Vector2(100, 100),
              child: CircleParticle(
                radius: 4,
                paint: Paint()..color = Colors.orange,
              ),
            ),
          ),
        );
}
```

### Particle Types

#### Moving Particle

```dart
MovingParticle(
  from: Vector2.zero(),
  to: Vector2(100, 0),
  child: CircleParticle(
    radius: 5,
    paint: Paint()..color = Colors.blue,
  ),
)
```

#### Accelerated Particle

```dart
AcceleratedParticle(
  acceleration: Vector2(0, 100), // Gravity
  speed: Vector2(50, -100),      // Initial velocity
  child: CircleParticle(
    radius: 3,
    paint: Paint()..color = Colors.red,
  ),
)
```

#### Image Particle

```dart
SpriteParticle(
  sprite: await Sprite.load('spark.png'),
  size: Vector2(16, 16),
)
```

#### Animation Particle

```dart
SpriteAnimationParticle(
  animation: await loadAnimation(),
  size: Vector2(32, 32),
)
```

#### Computed Particle (Custom)

```dart
ComputedParticle(
  lifespan: 1.0,
  renderer: (canvas, particle) {
    final progress = particle.progress;
    final radius = 10 * (1 - progress);
    final alpha = ((1 - progress) * 255).toInt();
    
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = Colors.yellow.withAlpha(alpha),
    );
  },
)
```

### Translated Particles (Movement)

```dart
TranslatedParticle(
  lifespan: 2.0,
  offset: Vector2(0, -50), // Move up
  child: CircleParticle(
    radius: 5,
    paint: Paint()..color = Colors.green,
  ),
)
```

### Scaled Particles (Growth/Shrink)

```dart
ScaledParticle(
  lifespan: 1.0,
  scale: 2.0, // Grow to 2x size
  child: CircleParticle(
    radius: 5,
    paint: Paint()..color = Colors.purple,
  ),
)
```

### Curved Particles (Easing)

```dart
CurvedParticle(
  lifespan: 1.0,
  curve: Curves.easeOut,
  child: CircleParticle(
    radius: 10,
    paint: Paint()..color = Colors.cyan,
  ),
)
```

### Particle System Component

```dart
class FireEffect extends ParticleSystemComponent {
  FireEffect()
      : super(
          particle: Particle.generate(
            count: 50,
            lifespan: 1.5,
            generator: (i) {
              final random = Random();
              return TranslatedParticle(
                offset: Vector2(0, -30 - random.nextDouble() * 20),
                child: ComputedParticle(
                  renderer: (canvas, particle) {
                    final progress = particle.progress;
                    final size = 10 * (1 - progress);
                    
                    // Color gradient from yellow to red
                    final color = Color.lerp(
                      Colors.yellow,
                      Colors.red,
                      progress,
                    )!;
                    
                    canvas.drawCircle(
                      Offset(
                        (random.nextDouble() - 0.5) * 20 * progress,
                        0,
                      ),
                      size,
                      Paint()..color = color.withAlpha((255 * (1 - progress)).toInt()),
                    );
                  },
                ),
              );
            },
          ),
        );
}
```

### Common Effects

#### Explosion

```dart
ParticleSystemComponent generateExplosion(Vector2 position) {
  return ParticleSystemComponent(
    position: position,
    particle: Particle.generate(
      count: 30,
      lifespan: 0.8,
      generator: (i) {
        final angle = (i / 30) * 2 * pi;
        final speed = 100 + Random().nextDouble() * 100;
        
        return AcceleratedParticle(
          acceleration: Vector2(0, 300), // Gravity
          speed: Vector2(
            cos(angle) * speed,
            sin(angle) * speed,
          ),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final progress = particle.progress;
              final colors = [Colors.yellow, Colors.orange, Colors.red];
              final color = colors[(progress * colors.length).floor()];
              
              canvas.drawCircle(
                Offset.zero,
                5 * (1 - progress),
                Paint()..color = color.withAlpha((255 * (1 - progress)).toInt()),
              );
            },
          ),
        );
      },
    ),
  );
}
```

#### Trail Effect

```dart
class TrailEffect extends Component {
  final PositionComponent target;
  final List<Vector2> positions = [];
  final int maxPoints = 20;
  final Paint paint = Paint()
    ..color = Colors.cyan
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  
  TrailEffect(this.target);
  
  @override
  void update(double dt) {
    positions.add(target.position.clone());
    if (positions.length > maxPoints) {
      positions.removeAt(0);
    }
  }
  
  @override
  void render(Canvas canvas) {
    if (positions.length < 2) return;
    
    final path = Path();
    path.moveTo(positions.first.x, positions.first.y);
    
    for (var i = 1; i < positions.length; i++) {
      path.lineTo(positions[i].x, positions[i].y);
    }
    
    canvas.drawPath(path, paint);
  }
}
```

#### Sparkles

```dart
ParticleSystemComponent generateSparkles(Vector2 position) {
  return ParticleSystemComponent(
    position: position,
    particle: Particle.generate(
      count: 10,
      lifespan: 0.5,
      generator: (i) {
        final random = Random();
        return TranslatedParticle(
          offset: Vector2(
            (random.nextDouble() - 0.5) * 40,
            (random.nextDouble() - 0.5) * 40,
          ),
          child: ScaledParticle(
            scale: 0.5,
            child: CircleParticle(
              radius: 3,
              paint: Paint()..color = Colors.yellow,
            ),
          ),
        );
      },
    ),
  );
}
```

#### Smoke

```dart
ParticleSystemComponent generateSmoke(Vector2 position) {
  return ParticleSystemComponent(
    position: position,
    particle: Particle.generate(
      count: 20,
      lifespan: 2.0,
      generator: (i) {
        final random = Random();
        return TranslatedParticle(
          offset: Vector2(0, -50 - random.nextDouble() * 30),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final progress = particle.progress;
              final size = 15 + 10 * progress;
              
              canvas.drawCircle(
                Offset(
                  (random.nextDouble() - 0.5) * 10,
                  0,
                ),
                size,
                Paint()
                  ..color = Colors.grey.withAlpha((100 * (1 - progress)).toInt()),
              );
            },
          ),
        );
      },
    ),
  );
}
```

### Particle Management

#### Auto-Removing Particles

```dart
class OneShotParticle extends ParticleSystemComponent {
  OneShotParticle({required Particle particle})
      : super(particle: particle);
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Remove when all particles are dead
    if (particle.isDead) {
      removeFromParent();
    }
  }
}
```

#### Particle Pooling

```dart
class ParticlePool {
  final List<ParticleSystemComponent> _available = [];
  final List<ParticleSystemComponent> _inUse = [];
  
  ParticleSystemComponent acquire(Particle particle) {
    ParticleSystemComponent psc;
    
    if (_available.isEmpty) {
      psc = ParticleSystemComponent(particle: particle);
    } else {
      psc = _available.removeLast();
      psc.particle = particle;
    }
    
    _inUse.add(psc);
    return psc;
  }
  
  void release(ParticleSystemComponent psc) {
    _inUse.remove(psc);
    _available.add(psc);
  }
  
  void update(double dt) {
    for (final psc in _inUse.toList()) {
      if (psc.particle.isDead) {
        release(psc);
        psc.removeFromParent();
      }
    }
  }
}
```

## Combined Audio + Particle Effects

### Impact Effect

```dart
class ImpactEffect extends Component {
  static void spawn(Game game, Vector2 position) {
    // Visual
    game.add(generateExplosion(position));
    
    // Audio
    FlameAudio.play('explosion.wav', volume: 0.6);
  }
}

// Usage
ImpactEffect.spawn(game, collisionPoint);
```

### Collectible Effect

```dart
class CollectEffect extends Component {
  static void spawn(Game game, Vector2 position) {
    // Sparkle particles
    game.add(generateSparkles(position));
    
    // Coin sound
    FlameAudio.play('coin.wav', volume: 0.5);
  }
}
```

### Step Effect

```dart
class FootstepEffect extends Component {
  double stepTimer = 0;
  final double stepInterval = 0.3;
  
  @override
  void update(double dt) {
    stepTimer += dt;
    
    if (stepTimer >= stepInterval && isMoving) {
      spawnStep();
      stepTimer = 0;
    }
  }
  
  void spawnStep() {
    // Small dust particle
    parent?.add(ParticleSystemComponent(
      position: position,
      particle: Particle.generate(
        count: 3,
        lifespan: 0.3,
        generator: (i) => CircleParticle(
          radius: 2,
          paint: Paint()..color = Colors.grey.withAlpha(150),
        ),
      ),
    ));
    
    // Footstep sound
    FlameAudio.play('step.wav', volume: 0.3);
  }
}
```

## Performance Tips

### Audio

1. **Preload critical sounds** during loading screen
2. **Use AudioPool** for rapid-fire sounds
3. **Dispose BGM** when not needed
4. **Use WAV for short SFX** (lower latency)
5. **Use OGG/MP3 for music** (smaller file size)

### Particles

1. **Limit particle count** - use 10-50 per effect max
2. **Remove dead particles** promptly
3. **Use simple shapes** (CircleParticle > SpriteParticle)
4. **Batch similar particles** into single component
5. **Use pooling** for frequently spawned effects

```dart
// Bad - creates new particles every frame
@override
void update(double dt) {
  add(ParticleSystemComponent(...));
}

// Good - reuse particles
final pool = ParticlePool();

@override
void update(double dt) {
  pool.update(dt);
}

void spawnEffect() {
  add(pool.acquire(particle));
}
```
