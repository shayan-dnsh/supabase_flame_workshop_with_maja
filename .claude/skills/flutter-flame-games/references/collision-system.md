# Collision System

Complete guide to collision detection in Flame.

## Setup

### Enable Collision Detection

```dart
class MyGame extends FlameGame with HasCollisionDetection {
  @override
  Future<void> onLoad() async {
    // Add screen boundaries
    add(ScreenHitbox());
    
    // Add collidable entities
    add(Player());
    add(Enemy());
  }
}
```

### Make Component Collidable

```dart
class Player extends PositionComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    // Add hitbox
    add(CircleHitbox(radius: 20));
  }
}
```

## Hitbox Types

### CircleHitbox

```dart
CircleHitbox(
  radius: 20,
  position: Vector2(0, 0), // Relative to parent
  anchor: Anchor.center,
)
```

### RectangleHitbox

```dart
RectangleHitbox(
  size: Vector2(40, 60),
  position: Vector2.zero(),
  anchor: Anchor.topLeft,
)
```

### PolygonHitbox

```dart
PolygonHitbox([
  Vector2(0, 0),
  Vector2(30, 10),
  Vector2(20, 30),
  Vector2(-10, 20),
])
```

### Multiple Hitboxes

```dart
class Player extends PositionComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    // Body hitbox
    add(RectangleHitbox(
      size: Vector2(30, 50),
      position: Vector2(5, 0),
    )..debugMode = true);
    
    // Head hitbox
    add(CircleHitbox(
      radius: 12,
      position: Vector2(20, -5),
    )..debugMode = true);
  }
}
```

## Collision Callbacks

### Basic Callbacks

```dart
class Player extends PositionComponent with CollisionCallbacks {
  bool isGrounded = false;
  
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Ground) {
      isGrounded = true;
    }
    if (other is Enemy) {
      takeDamage();
    }
  }
  
  @override
  void onCollision(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    // Called every frame while colliding
    if (other is Platform) {
      // Push out of platform
      resolveCollision(intersectionPoints);
    }
  }
  
  @override
  void onCollisionEnd(PositionComponent other) {
    if (other is Ground) {
      isGrounded = false;
    }
  }
}
```

### Collision Points

```dart
@override
void onCollisionStart(
  Set<Vector2> intersectionPoints,
  PositionComponent other,
) {
  if (intersectionPoints.length == 2) {
    // Line collision - calculate normal
    final point1 = intersectionPoints.elementAt(0);
    final point2 = intersectionPoints.elementAt(1);
    final midPoint = (point1 + point2) / 2;
    final collisionNormal = (position - midPoint).normalized();
  } else if (intersectionPoints.length == 1) {
    // Point collision
    final collisionPoint = intersectionPoints.first;
  }
}
```

## Collision Types

### Active vs Passive

```dart
class Bullet extends PositionComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: 5)
      ..collisionType = CollisionType.passive);
  }
}

class Player extends PositionComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    // Active by default - checks collisions with everything
    add(RectangleHitbox(size: Vector2(40, 60)));
  }
}
```

| Type | Description |
|------|-------------|
| `active` | Checks collisions with all types (default) |
| `passive` | Only checked by active hitboxes |
| `inactive` | No collision detection |

Use `passive` for:
- Bullets (many objects)
- Collectibles
- Particles
- Any entity that doesn't need to check collisions itself

## Collision Resolution

### Basic Push Response

```dart
class Player extends PositionComponent with CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Wall) {
      // Simple bounce
      velocity = -velocity;
      
      // Or stop movement
      velocity = Vector2.zero();
    }
  }
}
```

### Platform Collision

```dart
class Player extends PositionComponent with CollisionCallbacks {
  bool onGround = false;
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Platform) {
      final collisionPoint = intersectionPoints.first;
      final collisionNormal = (position - collisionPoint).normalized();
      
      // Check if landing on top
      if (collisionNormal.y < -0.5) {
        // Landed on platform
        position.y = other.position.y - size.y;
        velocity.y = 0;
        onGround = true;
      }
    }
  }
}
```

### Separation Physics

```dart
class PhysicsBody extends PositionComponent with CollisionCallbacks {
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is SolidObject) {
      // Calculate penetration depth
      final center = position + size / 2;
      final otherCenter = other.position + other.size / 2;
      final diff = center - otherCenter;
      
      // Minimum translation vector
      final overlapX = (size.x + other.size.x) / 2 - diff.x.abs();
      final overlapY = (size.y + other.size.y) / 2 - diff.y.abs();
      
      // Resolve smallest overlap
      if (overlapX < overlapY) {
        position.x += diff.x > 0 ? overlapX : -overlapX;
      } else {
        position.y += diff.y > 0 ? overlapY : -overlapY;
      }
    }
  }
}
```

## Spatial Hashing (Broad Phase)

For games with many collidable objects, enable spatial hashing:

```dart
class MyGame extends FlameGame with HasCollisionDetection {
  @override
  Future<void> onLoad() async {
    // Enable spatial hashing with cell size
    collisionDetection = CollisionDetection(
      broadphase: SpatialHashBroadphase(cellSize: 100),
    );
  }
}
```

## Screen Boundaries

### ScreenHitbox

```dart
class MyGame extends FlameGame with HasCollisionDetection {
  @override
  Future<void> onLoad() async {
    // Adds collision bounds matching screen size
    add(ScreenHitbox());
    
    // Or with custom size
    add(ScreenHitbox()..size = Vector2(800, 600));
  }
}
```

### Bounce Off Screen Edges

```dart
class Ball extends PositionComponent with CollisionCallbacks {
  Vector2 velocity = Vector2(100, 100);
  
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is ScreenHitbox) {
      final collisionPoint = intersectionPoints.first;
      
      // Determine which edge
      if (collisionPoint.x <= 0 || collisionPoint.x >= game.size.x) {
        velocity.x = -velocity.x; // Bounce horizontally
      }
      if (collisionPoint.y <= 0 || collisionPoint.y >= game.size.y) {
        velocity.y = -velocity.y; // Bounce vertically
      }
    }
  }
}
```

## Raycasting

```dart
class MyGame extends FlameGame with HasCollisionDetection {
  void checkLineOfSight() {
    final ray = Ray2(
      origin: player.position,
      direction: Vector2(1, 0), // Right
    );
    
    final result = collisionDetection.raycast(
      ray,
      maxDistance: 200,
    );
    
    if (result != null && result.hitbox?.parent is Enemy) {
      // Enemy in line of sight
    }
  }
}
```

## Debug Visualization

```dart
class Player extends PositionComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    final hitbox = CircleHitbox(radius: 20);
    hitbox.debugMode = true; // Shows hitbox outline
    hitbox.debugColor = Colors.red;
    add(hitbox);
  }
}
```

## Common Patterns

### Invincibility Frames

```dart
class Player extends PositionComponent with CollisionCallbacks {
  double invincibilityTime = 0;
  
  @override
  void update(double dt) {
    invincibilityTime = (invincibilityTime - dt).clamp(0, double.infinity);
  }
  
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Enemy && invincibilityTime <= 0) {
      takeDamage();
      invincibilityTime = 1.0; // 1 second invincibility
    }
  }
}
```

### One-Way Platforms

```dart
class OneWayPlatform extends PositionComponent with CollisionCallbacks {
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Player) {
      // Only collide if falling down and above platform
      if (other.velocity.y > 0 && 
          other.position.y + other.size.y < position.y + size.y / 2) {
        // Allow collision
        other.position.y = position.y - other.size.y;
        other.velocity.y = 0;
        other.onGround = true;
      }
    }
  }
}
```

### Trigger Zones

```dart
class TriggerZone extends PositionComponent with CollisionCallbacks {
  final VoidCallback onTrigger;
  bool triggered = false;
  
  TriggerZone({required this.onTrigger})
      : super(size: Vector2(100, 100));
  
  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size)
      ..isSolid = false); // Don't block movement
  }
  
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Player && !triggered) {
      triggered = true;
      onTrigger();
    }
  }
}
```
