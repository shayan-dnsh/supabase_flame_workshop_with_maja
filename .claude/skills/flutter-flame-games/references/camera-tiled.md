# Camera System & Tiled Maps

Complete guide to camera management and Tiled map integration.

## Camera System

### CameraComponent Overview

The camera system in Flame consists of:
- **CameraComponent**: The camera itself
- **Viewfinder**: Controls zoom, rotation, and position
- **Viewport**: Defines visible area
- **World**: Contains all game entities

### Basic Camera Setup

```dart
class MyGame extends FlameGame {
  late final Player player;
  
  @override
  Future<void> onLoad() async {
    // Create world
    final world = World();
    
    // Create player
    player = Player();
    await world.add(player);
    
    // Add world to game
    await add(world);
    
    // Create camera
    camera = CameraComponent.withFixedResolution(
      world: world,
      width: 800,
      height: 600,
    );
    await add(camera);
    
    // Follow player
    camera.follow(player);
  }
}
```

### Camera Following

```dart
// Basic follow
camera.follow(player);

// Follow with options
camera.follow(
  player,
  maxSpeed: 300,        // Max follow speed
  snap: false,          // Smooth follow (true = instant)
  horizontalOnly: false,
  verticalOnly: false,
);
```

### Camera Bounds

```dart
// Keep camera within world bounds
camera.setBounds(
  Rectangle.fromLTRB(0, 0, worldWidth, worldHeight),
);

// With padding
camera.setBounds(
  Rectangle.fromLTRB(100, 100, worldWidth - 100, worldHeight - 100),
);
```

### Camera Zoom

```dart
// Set zoom level
camera.viewfinder.zoom = 2.0; // 2x zoom

// Animated zoom
await camera.viewfinder.zoomTo(
  2.0,
  speed: 2.0,
);

// Clamp zoom
camera.viewfinder.zoom = zoom.clamp(0.5, 3.0);
```

### Camera Rotation

```dart
// Rotate camera
camera.viewfinder.angle = pi / 4; // 45 degrees

// Animated rotation
await camera.viewfinder.rotateTo(
  pi / 2,
  speed: 2.0,
);

// Lock to player rotation
camera.viewfinder.anchor = Anchor.center;
```

### Fixed Resolution

```dart
// Game renders at fixed resolution, scales to fit screen
camera = CameraComponent.withFixedResolution(
  world: world,
  width: 800,
  height: 600,
);
```

### Viewport Types

```dart
// Fixed resolution (pixel-perfect)
camera = CameraComponent.withFixedResolution(
  world: world,
  width: 320,
  height: 180,
);

// Max viewport (fills screen)
camera = CameraComponent(
  world: world,
  viewport: MaxViewport(),
);

// Fixed aspect ratio
camera = CameraComponent(
  world: world,
  viewport: FixedAspectRatioViewport(aspectRatio: 16 / 9),
);
```

### Coordinate Conversion

```dart
class MyGame extends FlameGame {
  void handleInput() {
    // Screen to world coordinates
    final screenPos = Vector2(100, 100);
    final worldPos = camera.globalToLocal(screenPos);
    
    // World to screen coordinates
    final worldPosition = player.position;
    final screenPosition = camera.localToGlobal(worldPosition);
  }
}
```

### Camera Shake

```dart
class CameraShake extends Component {
  double intensity = 0;
  double duration = 0;
  
  @override
  void update(double dt) {
    if (duration > 0) {
      final offset = Vector2.random() * intensity;
      game.camera.viewfinder.position = offset;
      duration -= dt;
    } else {
      game.camera.viewfinder.position = Vector2.zero();
    }
  }
  
  void shake({required double intensity, required double duration}) {
    this.intensity = intensity;
    this.duration = duration;
  }
}

// Usage
cameraShake.shake(intensity: 5, duration: 0.3);
```

### Multi-Camera Setup

```dart
class SplitScreenGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    final world = World();
    
    // Player 1 camera (left half)
    final camera1 = CameraComponent(
      world: world,
      viewport: FixedSizeViewport(400, 600)
        ..position = Vector2(0, 0),
    );
    camera1.follow(player1);
    
    // Player 2 camera (right half)
    final camera2 = CameraComponent(
      world: world,
      viewport: FixedSizeViewport(400, 600)
        ..position = Vector2(400, 0),
    );
    camera2.follow(player2);
    
    await addAll([world, camera1, camera2]);
  }
}
```

## Tiled Maps

### Setup

```yaml
dependencies:
  flame_tiled: ^1.18.0
```

### Loading Tiled Maps

```dart
import 'package:flame_tiled/flame_tiled.dart';

class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    final mapComponent = await TiledComponent.load(
      'map.tmx',
      Vector2(32, 32), // Tile size (must match Tiled)
    );
    await add(mapComponent);
  }
}
```

### Accessing Layers

```dart
class MyGame extends FlameGame {
  late final TiledComponent map;
  
  @override
  Future<void> onLoad() async {
    map = await TiledComponent.load('map.tmx', Vector2(32, 32));
    await add(map);
    
    // Access tile layers
    final groundLayer = map.tileMap.getLayer<TileLayer>('ground');
    final decorationLayer = map.tileMap.getLayer<TileLayer>('decoration');
    
    // Access object layers
    final spawnLayer = map.tileMap.getLayer<ObjectGroup>('spawns');
    final collisionLayer = map.tileMap.getLayer<ObjectGroup>('collision');
    
    // Access layer properties
    final isVisible = groundLayer?.visible ?? true;
    final opacity = groundLayer?.opacity ?? 1.0;
  }
}
```

### Reading Tile Data

```dart
void readTiles(TileLayer layer) {
  for (var y = 0; y < layer.height; y++) {
    for (var x = 0; x < layer.width; x++) {
      final tile = layer.tileData![y][x];
      
      if (tile.tile > 0) {
        // Tile exists at this position
        print('Tile ${tile.tile} at ($x, $y)');
        
        // Check flip flags
        final flippedHorizontally = tile.flipsHorizontal;
        final flippedVertically = tile.flipsVertical;
      }
    }
  }
}
```

### Object Layers

```dart
void processObjectGroup(ObjectGroup layer) {
  for (final object in layer.objects) {
    switch (object.name) {
      case 'player_spawn':
        spawnPlayer(object);
        break;
      case 'enemy':
        spawnEnemy(object);
        break;
      case 'coin':
        spawnCoin(object);
        break;
    }
    
    // Access object properties
    final type = object.type;
    final x = object.x;
    final y = object.y;
    final width = object.width;
    final height = object.height;
    
    // Custom properties
    final health = object.properties.getValue<int>('health') ?? 100;
    final speed = object.properties.getValue<double>('speed') ?? 5.0;
  }
}

void spawnPlayer(TiledObject object) {
  final player = Player()
    ..position = Vector2(object.x, object.y);
  add(player);
}
```

### Generating Collisions from Tiles

```dart
class TileMapCollisionBuilder {
  static List<PositionComponent> build(
    TiledComponent map,
    String layerName,
  ) {
    final layer = map.tileMap.getLayer<TileLayer>(layerName);
    final collisions = <PositionComponent>[];
    
    if (layer == null) return collisions;
    
    for (var y = 0; y < layer.height; y++) {
      for (var x = 0; x < layer.width; x++) {
        final tile = layer.tileData![y][x];
        
        if (tile.tile > 0) {
          final tileset = map.tileMap.tilesets.first;
          final tileData = tileset.tiles[tile.tile];
          
          // Check if tile has collision
          if (tileData?.collisionObjects?.isNotEmpty ?? false) {
            collisions.add(
              PositionComponent(
                position: Vector2(
                  x * map.tileMap.map.tileWidth,
                  y * map.tileMap.map.tileHeight,
                ),
                size: Vector2(
                  map.tileMap.map.tileWidth,
                  map.tileMap.map.tileHeight,
                ),
              )..add(RectangleHitbox()),
            );
          }
        }
      }
    }
    
    return collisions;
  }
}

// Usage
final collisionBlocks = TileMapCollisionBuilder.build(map, 'ground');
addAll(collisionBlocks);
```

### Optimized Collision (Single Hitbox per Row)

```dart
List<PositionComponent> buildOptimizedCollisions(
  TiledComponent map,
  String layerName,
) {
  final layer = map.tileMap.getLayer<TileLayer>(layerName);
  final collisions = <PositionComponent>[];
  
  if (layer == null) return collisions;
  
  for (var y = 0; y < layer.height; y++) {
    var startX = -1;
    
    for (var x = 0; x <= layer.width; x++) {
      final hasTile = x < layer.width && layer.tileData![y][x].tile > 0;
      
      if (hasTile && startX == -1) {
        // Start of platform
        startX = x;
      } else if (!hasTile && startX != -1) {
        // End of platform
        final width = x - startX;
        collisions.add(
          PositionComponent(
            position: Vector2(
              startX * map.tileMap.map.tileWidth,
              y * map.tileMap.map.tileHeight,
            ),
            size: Vector2(
              width * map.tileMap.map.tileWidth,
              map.tileMap.map.tileHeight,
            ),
          )..add(RectangleHitbox()),
        );
        startX = -1;
      }
    }
  }
  
  return collisions;
}
```

### Animated Tiles

```dart
class AnimatedTileLayer extends Component {
  final TiledComponent map;
  final String layerName;
  
  AnimatedTileLayer(this.map, this.layerName);
  
  @override
  void update(double dt) {
    map.tileMap.update(dt);
  }
}
```

### Modifying Tiles at Runtime

```dart
void removeTile(TiledComponent map, int x, int y) {
  final layer = map.tileMap.getLayer<TileLayer>('ground');
  if (layer != null) {
    layer.setTileData(x, y, const Gid(0)); // 0 = empty tile
  }
}

void setTile(TiledComponent map, int x, int y, int tileId) {
  final layer = map.tileMap.getLayer<TileLayer>('ground');
  if (layer != null) {
    layer.setTileData(x, y, Gid(tileId));
  }
}
```

### Map Properties

```dart
void readMapProperties(TiledComponent map) {
  final props = map.tileMap.map.properties;
  
  final gravity = props.getValue<double>('gravity') ?? 9.8;
  final timeLimit = props.getValue<int>('time_limit') ?? 300;
  final nextLevel = props.getValue<String>('next_level') ?? 'level2';
}
```

### Camera with Tiled Map

```dart
class MyGame extends FlameGame with HasCollisionDetection {
  late final TiledComponent map;
  late final Player player;
  
  @override
  Future<void> onLoad() async {
    // Load map
    map = await TiledComponent.load('level1.tmx', Vector2(32, 32));
    
    // Create world
    final world = World();
    await world.add(map);
    
    // Get map dimensions
    final mapWidth = map.tileMap.map.width * map.tileMap.map.tileWidth;
    final mapHeight = map.tileMap.map.height * map.tileMap.map.tileHeight;
    
    // Spawn player from object layer
    final spawnLayer = map.tileMap.getLayer<ObjectGroup>('spawns');
    final spawn = spawnLayer?.objects.firstWhere((o) => o.name == 'player');
    
    player = Player()
      ..position = Vector2(spawn?.x ?? 100, spawn?.y ?? 100);
    await world.add(player);
    
    // Setup camera
    camera = CameraComponent.withFixedResolution(
      world: world,
      width: 800,
      height: 600,
    );
    camera.follow(player);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, mapWidth, mapHeight),
    );
    
    await addAll([world, camera]);
    
    // Add collisions
    final collisions = buildOptimizedCollisions(map, 'ground');
    await world.addAll(collisions);
  }
}
```

## Parallax Backgrounds

### Basic Parallax

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData('bg_sky.png'),
        ParallaxImageData('bg_mountains.png'),
        ParallaxImageData('bg_trees.png'),
      ],
      baseVelocity: Vector2(20, 0),
      velocityMultiplierDelta: Vector2(1.5, 0),
    );
    
    add(parallax);
  }
}
```

### Parallax with Camera

```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    final world = World();
    
    // Add parallax to world
    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData('bg_layer1.png'),
        ParallaxImageData('bg_layer2.png'),
      ],
      size: Vector2(800, 600),
    );
    await world.add(parallax);
    
    // Camera will move parallax automatically
    camera = CameraComponent(world: world);
    camera.follow(player);
  }
}
```

### Vertical Parallax

```dart
final parallax = await loadParallaxComponent(
  [
    ParallaxImageData('bg_sky.png'),
    ParallaxImageData('bg_clouds.png'),
  ],
  baseVelocity: Vector2(0, 10), // Move down
  velocityMultiplierDelta: Vector2(0, 1.5),
  repeat: ImageRepeat.repeatY,
);
```
