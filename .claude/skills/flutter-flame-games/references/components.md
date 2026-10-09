# Components Deep Dive

Detailed reference for Flame component system.

## Component Types

### Component (Base)

The foundation of all game entities.

```dart
abstract class Component {
  // Lifecycle methods
  FutureOr<void> onLoad();
  void onMount();
  void update(double dt);
  void render(Canvas canvas);
  void onRemove();
  
  // Hierarchy
  Component? parent;
  ComponentSet children;
  
  // State
  bool mounted = false;
  bool removed = false;
}
```

### PositionComponent

Adds position, size, scale, angle, and anchor to components.

```dart
class MyEntity extends PositionComponent {
  MyEntity()
      : super(
          position: Vector2(100, 200), // Top-left position
          size: Vector2(64, 64),        // Width, height
          scale: Vector2(1, 1),         // Scaling factor
          angle: 0,                     // Rotation in radians
          anchor: Anchor.center,        // Pivot point
        );
}
```

#### Position

```dart
// Setting position
position = Vector2(100, 200);
position.x = 100;
position.y = 200;

// Moving relative
position += Vector2(10, 0); // Move right

// Top-left corner
final topLeft = position;

// Center point
final center = position + (size / 2);
```

#### Anchor Points

```dart
Anchor.topLeft      // (0, 0) - default
Anchor.topCenter    // (0.5, 0)
Anchor.topRight     // (1, 0)
Anchor.centerLeft   // (0, 0.5)
Anchor.center       // (0.5, 0.5) - rotation center
Anchor.centerRight  // (1, 0.5)
Anchor.bottomLeft   // (0, 1)
Anchor.bottomCenter // (0.5, 1)
Anchor.bottomRight  // (1, 1)
```

#### Size

```dart
// Set size
size = Vector2(100, 50);

// Scale uniformly
size = Vector2.all(64);

// Access dimensions
double width = size.x;
double height = size.y;
```

#### Angle (Rotation)

```dart
// Rotate 90 degrees (π/2 radians)
angle = pi / 2;

// Rotate 45 degrees
angle = degrees2Radians * 45;

// Get current rotation in degrees
double degrees = angle * radians2Degrees;
```

### SpriteComponent

Displays static images.

```dart
class Player extends SpriteComponent {
  Player()
      : super(
          size: Vector2(64, 64),
          position: Vector2.zero(),
        );
  
  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('player.png');
    
    // Alternative: Load from image with src rect
    final image = await game.images.load('spritesheet.png');
    sprite = Sprite(
      image,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(32, 32),
    );
  }
}
```

### SpriteAnimationComponent

Displays animated sprites.

```dart
class AnimatedCharacter extends SpriteAnimationComponent {
  AnimatedCharacter() : super(size: Vector2(64, 64));
  
  @override
  Future<void> onLoad() async {
    // Method 1: From sprite sheet
    final spritesheet = await game.images.load('character.png');
    
    animation = SpriteAnimation.fromFrameData(
      spritesheet,
      SpriteAnimationData.sequenced(
        amount: 8,              // Total frames
        amountPerRow: 8,        // Frames per row
        textureSize: Vector2(64, 64), // Frame size
        stepTime: 0.1,          // Seconds per frame
        loop: true,             // Loop animation
      ),
    );
    
    // Method 2: Manual frames
    final frames = <SpriteAnimationFrame>[
      for (var i = 0; i < 8; i++)
        SpriteAnimationFrame(
          Sprite(
            spritesheet,
            srcPosition: Vector2(i * 64, 0),
            srcSize: Vector2(64, 64),
          ),
          stepTime: 0.1,
        ),
    ];
    animation = SpriteAnimation(frames, loop: true);
  }
}
```

### TextComponent

Render text in the game.

```dart
class ScoreDisplay extends TextComponent {
  ScoreDisplay()
      : super(
          text: 'Score: 0',
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          position: Vector2(20, 20),
        );
  
  void updateScore(int score) {
    text = 'Score: $score';
  }
}
```

### ShapeComponent

Built-in geometric shapes.

```dart
// Circle
class MyCircle extends CircleComponent {
  MyCircle()
      : super(
          radius: 30,
          position: Vector2(100, 100),
          paint: Paint()..color = Colors.red,
        );
}

// Rectangle
class MyRect extends RectangleComponent {
  MyRect()
      : super(
          size: Vector2(100, 50),
          position: Vector2(100, 100),
          paint: Paint()..color = Colors.blue,
        );
}

// Polygon
class MyPolygon extends PolygonComponent {
  MyPolygon()
      : super(
          [
            Vector2(0, 0),
            Vector2(50, 0),
            Vector2(25, 50),
          ],
          position: Vector2(100, 100),
          paint: Paint()..color = Colors.green,
        );
}
```

## Component Composition

### Parent-Child Relationships

```dart
class Player extends PositionComponent {
  late final HealthBar healthBar;
  late final Weapon weapon;
  
  @override
  Future<void> onLoad() async {
    // Health bar follows player
    healthBar = HealthBar()..position = Vector2(0, -20);
    await add(healthBar);
    
    // Weapon attached to player
    weapon = Weapon()..position = Vector2(40, 20);
    await add(weapon);
  }
}
```

### Component Queries

```dart
class Game extends FlameGame {
  void findComponents() {
    // Find by type
    final players = children.query<Player>();
    
    // Find first
    final player = children.query<Player>().firstOrNull;
    
    // Find in descendants
    final allEnemies = descendants().query<Enemy>();
  }
}
```

## Priority & Rendering Order

```dart
// Higher priority = rendered on top
class Background extends SpriteComponent {
  Background() : super(priority: 0);
}

class Player extends SpriteComponent {
  Player() : super(priority: 10);
}

class UI extends SpriteComponent {
  UI() : super(priority: 100);
}
```

## Component Lifecycle Hooks

```dart
class MyComponent extends PositionComponent {
  @override
  Future<void> onLoad() async {
    // Called once when component is added to game
    // Safe to load assets here
  }
  
  @override
  void onMount() {
    // Called when component is attached to parent
    // Parent is now available
  }
  
  @override
  void update(double dt) {
    // Called every frame
    // dt = time since last frame in seconds
  }
  
  @override
  void render(Canvas canvas) {
    // Called every frame for drawing
  }
  
  @override
  void renderTree(Canvas canvas) {
    // Override to customize rendering of children
    super.renderTree(canvas);
  }
  
  @override
  void onRemove() {
    // Called when component is removed from game
    // Cleanup resources here
  }
}
```

## Custom Components

### Full Example

```dart
class HealthBar extends PositionComponent {
  double maxHealth = 100;
  double currentHealth = 100;
  
  late final RectangleComponent background;
  late final RectangleComponent foreground;
  
  HealthBar()
      : super(
          size: Vector2(60, 8),
          anchor: Anchor.center,
        );
  
  @override
  Future<void> onLoad() async {
    // Background (red)
    background = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.red,
    );
    await add(background);
    
    // Foreground (green)
    foreground = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.green,
    );
    await add(foreground);
  }
  
  void updateHealth(double health) {
    currentHealth = health.clamp(0, maxHealth);
    final ratio = currentHealth / maxHealth;
    foreground.size = Vector2(size.x * ratio, size.y);
  }
  
  @override
  void update(double dt) {
    // Face camera (don't rotate with parent)
    angle = -parent!.angle;
  }
}
```

## Component Communication

### Parent to Child

```dart
class Player extends PositionComponent {
  void takeDamage(double amount) {
    // Notify children
    children.query<HealthBar>().first.updateHealth(health);
  }
}
```

### Child to Parent

```dart
class Weapon extends PositionComponent with HasGameReference {
  void shoot() {
    // Access game through mixin
    final bullet = Bullet();
    game.world.add(bullet);
  }
}
```

### Event Bus Pattern

```dart
class GameEventBus {
  static final _controller = StreamController<GameEvent>.broadcast();
  static Stream<GameEvent> get stream => _controller.stream;
  static void emit(GameEvent event) => _controller.add(event);
}

// Subscribe
class Player extends PositionComponent {
  @override
  void onMount() {
    GameEventBus.stream
        .whereType<EnemyKilledEvent>()
        .listen((event) => addScore(event.points));
  }
}

// Emit
class Enemy extends PositionComponent {
  void die() {
    GameEventBus.emit(EnemyKilledEvent(points: 100));
    removeFromParent();
  }
}
```
