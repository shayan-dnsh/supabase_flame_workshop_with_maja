# Input Handling

Complete guide to handling user input in Flame games.

## Keyboard Input

### Setup

```dart
class MyGame extends FlameGame with HasKeyboardHandlerComponents {
  // Now components can handle keyboard
}

class Player extends PositionComponent with KeyboardHandler {
  // Component handles its own keyboard input
}
```

### Basic Keyboard Handling

```dart
class Player extends PositionComponent with KeyboardHandler {
  Vector2 velocity = Vector2.zero();
  double speed = 200;
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Reset velocity
    velocity = Vector2.zero();
    
    // Check pressed keys
    final isLeft = keysPressed.contains(LogicalKeyboardKey.keyA) ||
                   keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRight = keysPressed.contains(LogicalKeyboardKey.keyD) ||
                    keysPressed.contains(LogicalKeyboardKey.arrowRight);
    final isUp = keysPressed.contains(LogicalKeyboardKey.keyW) ||
                 keysPressed.contains(LogicalKeyboardKey.arrowUp);
    final isDown = keysPressed.contains(LogicalKeyboardKey.keyS) ||
                   keysPressed.contains(LogicalKeyboardKey.arrowDown);
    
    // Apply movement
    if (isLeft) velocity.x = -1;
    if (isRight) velocity.x = 1;
    if (isUp) velocity.y = -1;
    if (isDown) velocity.y = 1;
    
    // Normalize to prevent faster diagonal movement
    if (velocity.length > 0) {
      velocity = velocity.normalized() * speed;
    }
    
    return true; // Event handled
  }
  
  @override
  void update(double dt) {
    position += velocity * dt;
  }
}
```

### Key Events (Pressed/Released)

```dart
class Player extends PositionComponent with KeyboardHandler {
  bool isJumping = false;
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Key press detection
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          if (!isJumping) jump();
          return true;
        case LogicalKeyboardKey.keyX:
          attack();
          return true;
        case LogicalKeyboardKey.escape:
          pauseGame();
          return true;
      }
    }
    
    // Key release detection
    if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        stopJump();
      }
    }
    
    return false; // Event not handled
  }
}
```

## Touch/Tap Input

### Tap Callbacks

```dart
class Button extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;
  
  Button({required this.onPressed});
  
  @override
  void onTapDown(TapDownEvent event) {
    // Visual feedback
    scale = Vector2.all(0.95);
  }
  
  @override
  void onTapUp(TapUpEvent event) {
    scale = Vector2.all(1.0);
    onPressed();
  }
  
  @override
  void onTapCancel(TapCancelEvent event) {
    // Tap was cancelled (e.g., dragged off)
    scale = Vector2.all(1.0);
  }
  
  @override
  void onLongTapDown(TapDownEvent event) {
    // Long press started
  }
}
```

### Tap at Game Level

```dart
class MyGame extends FlameGame with TapCallbacks {
  @override
  void onTapDown(TapDownEvent event) {
    // Get tap position in world coordinates
    final worldPos = camera.globalToLocal(event.localPosition);
    
    // Spawn something at tap location
    add(ParticleEffect(position: worldPos));
  }
}
```

## Drag/Pan Input

### Drag Callbacks

```dart
class DraggableItem extends PositionComponent with DragCallbacks {
  Vector2? dragStartPosition;
  Vector2? itemStartPosition;
  
  @override
  void onDragStart(DragStartEvent event) {
    dragStartPosition = event.localPosition;
    itemStartPosition = position.clone();
    priority = 100; // Bring to front while dragging
  }
  
  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (dragStartPosition != null && itemStartPosition != null) {
      // Calculate new position
      final delta = event.localPosition - dragStartPosition!;
      position = itemStartPosition! + delta;
    }
  }
  
  @override
  void onDragEnd(DragEndEvent event) {
    _endDrag();
  }
  
  @override
  void onDragCancel(DragCancelEvent event) {
    // Return to original position
    if (itemStartPosition != null) {
      position = itemStartPosition!;
    }
    _endDrag();
  }
  
  void _endDrag() {
    dragStartPosition = null;
    itemStartPosition = null;
    priority = 0;
  }
}
```

### Pan Detection (Camera)

```dart
class MyGame extends FlameGame with PanDetector {
  @override
  void onPanUpdate(DragUpdateInfo info) {
    // Pan camera
    camera.viewfinder.position -= info.delta.global;
  }
  
  @override
  void onPanEnd(DragEndInfo info) {
    // Pan ended
  }
}
```

## Virtual Joystick

### Basic Joystick

```dart
class MyGame extends FlameGame {
  late final JoystickComponent joystick;
  late final Player player;
  
  @override
  Future<void> onLoad() async {
    player = Player();
    await add(player);
    
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 20,
        paint: Paint()..color = Colors.red.withAlpha(200),
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()..color = Colors.black.withAlpha(100),
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    await add(joystick);
  }
  
  @override
  void update(double dt) {
    if (joystick.direction != JoystickDirection.idle) {
      player.move(joystick.delta * 5);
    }
    super.update(dt);
  }
}
```

### Joystick Directions

```dart
void handleJoystick() {
  switch (joystick.direction) {
    case JoystickDirection.up:
    case JoystickDirection.upLeft:
    case JoystickDirection.upRight:
      player.moveUp();
      break;
    case JoystickDirection.down:
    case JoystickDirection.downLeft:
    case JoystickDirection.downRight:
      player.moveDown();
      break;
    case JoystickDirection.left:
      player.moveLeft();
      break;
    case JoystickDirection.right:
      player.moveRight();
      break;
    case JoystickDirection.idle:
      player.idle();
      break;
  }
}
```

### Custom Joystick with Images

```dart
JoystickComponent(
  knob: SpriteComponent(
    sprite: await Sprite.load('joystick_knob.png'),
    size: Vector2(40, 40),
  ),
  background: SpriteComponent(
    sprite: await Sprite.load('joystick_bg.png'),
    size: Vector2(100, 100),
  ),
  margin: const EdgeInsets.only(right: 40, bottom: 40),
)
```

## Gesture Detection

### Scale (Pinch to Zoom)

```dart
class MyGame extends FlameGame with ScaleDetector {
  double startZoom = 1.0;
  
  @override
  void onScaleStart(ScaleStartInfo info) {
    startZoom = camera.viewfinder.zoom;
  }
  
  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    camera.viewfinder.zoom = startZoom * info.scale.global;
    
    // Clamp zoom
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(0.5, 3.0);
  }
}
```

### Combined Gestures

```dart
class MyGame extends FlameGame 
    with TapCallbacks, PanDetector, ScaleDetector {
  
  @override
  void onTapDown(TapDownEvent event) {
    // Handle tap
  }
  
  @override
  void onPanUpdate(DragUpdateInfo info) {
    // Handle pan
  }
  
  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // Handle scale
  }
}
```

## Physical Gamepad

### Gamepad Setup

Add dependency:
```yaml
dependencies:
  gamepads: ^0.1.1
```

### Gamepad Input

```dart
import 'package:gamepads/gamepads.dart';

class MyGame extends FlameGame {
  StreamSubscription? gamepadSubscription;
  Vector2 leftStick = Vector2.zero();
  
  @override
  Future<void> onLoad() async {
    // Listen to gamepad events
    gamepadSubscription = Gamepads.events.listen((event) {
      handleGamepadEvent(event);
    });
  }
  
  void handleGamepadEvent(GamepadEvent event) {
    switch (event.key) {
      case 'buttonA':
        if (event.value == 1) player.jump();
        break;
      case 'buttonB':
        if (event.value == 1) player.attack();
        break;
      case 'leftX':
        leftStick.x = event.value;
        break;
      case 'leftY':
        leftStick.y = event.value;
        break;
    }
  }
  
  @override
  void update(double dt) {
    // Apply stick movement with deadzone
    if (leftStick.length > 0.2) {
      player.velocity = leftStick * player.speed;
    }
    super.update(dt);
  }
  
  @override
  void onRemove() {
    gamepadSubscription?.cancel();
    super.onRemove();
  }
}
```

## Mouse Input

### Mouse Position

```dart
class MyGame extends FlameGame {
  Vector2 mousePosition = Vector2.zero();
  
  @override
  void onMount() {
    // Track mouse position
    children.register<MouseTracker>();
  }
}

class Player extends PositionComponent with MouseMovementDetector {
  @override
  void onMouseMove(PointerMoveInfo info) {
    // Look at mouse
    angle = (info.eventPosition.widget - position).angleToSigned(Vector2(1, 0));
  }
}
```

### Mouse Buttons

```dart
class MyGame extends FlameGame with SecondaryTapDetector {
  @override
  void onSecondaryTapDown(TapDownInfo info) {
    // Right click
    openContextMenu(info.eventPosition.widget);
  }
}
```

## Input Priority

### Priority Order

Components can consume events to prevent propagation:

```dart
class UIOverlay extends PositionComponent with TapCallbacks {
  @override
  bool containsLocalPoint(Vector2 point) => true; // Consume all taps
  
  @override
  void onTapDown(TapDownEvent event) {
    // Handle UI tap
    event.continuePropagation = false; // Don't pass to game
  }
}
```

## Common Input Patterns

### Platformer Controls

```dart
class Player extends PositionComponent with KeyboardHandler {
  bool onGround = false;
  bool jumpPressed = false;
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Horizontal movement
    if (keysPressed.contains(LogicalKeyboardKey.keyA)) {
      velocity.x = -speed;
    } else if (keysPressed.contains(LogicalKeyboardKey.keyD)) {
      velocity.x = speed;
    } else {
      velocity.x = 0;
    }
    
    // Jump (buffered)
    if (event is KeyDownEvent && 
        event.logicalKey == LogicalKeyboardKey.space) {
      jumpPressed = true;
    }
    
    return true;
  }
  
  @override
  void update(double dt) {
    // Apply gravity
    velocity.y += gravity * dt;
    
    // Jump if buffered and on ground
    if (jumpPressed && onGround) {
      velocity.y = -jumpForce;
      jumpPressed = false;
      onGround = false;
    }
    
    position += velocity * dt;
  }
}
```

### Top-Down RPG Controls

```dart
class Player extends PositionComponent with KeyboardHandler {
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    Vector2 input = Vector2.zero();
    
    if (keysPressed.contains(LogicalKeyboardKey.keyW)) input.y -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyS)) input.y += 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyA)) input.x -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyD)) input.x += 1;
    
    // Normalize for consistent speed
    if (input.length > 0) {
      velocity = input.normalized() * speed;
      
      // Update facing direction
      facing = input.normalized();
    } else {
      velocity = Vector2.zero();
    }
    
    return true;
  }
}
```

### Touch-to-Move

```dart
class Player extends PositionComponent with TapCallbacks {
  Vector2? targetPosition;
  double speed = 150;
  
  @override
  void onTapDown(TapDownEvent event) {
    targetPosition = event.localPosition;
  }
  
  @override
  void update(double dt) {
    if (targetPosition != null) {
      final direction = (targetPosition! - position);
      final distance = direction.length;
      
      if (distance < 5) {
        targetPosition = null;
      } else {
        position += direction.normalized() * speed * dt;
      }
    }
  }
  
  @override
  void render(Canvas canvas) {
    // Draw target indicator
    if (targetPosition != null) {
      canvas.drawCircle(
        (targetPosition! - position).toOffset(),
        5,
        Paint()..color = Colors.red,
      );
    }
  }
}
```

## Input Mapping

### Action-Based Input

```dart
enum GameAction {
  moveLeft,
  moveRight,
  jump,
  attack,
  pause,
}

class InputMapper {
  static final Map<LogicalKeyboardKey, GameAction> keyMap = {
    LogicalKeyboardKey.keyA: GameAction.moveLeft,
    LogicalKeyboardKey.arrowLeft: GameAction.moveLeft,
    LogicalKeyboardKey.keyD: GameAction.moveRight,
    LogicalKeyboardKey.arrowRight: GameAction.moveRight,
    LogicalKeyboardKey.space: GameAction.jump,
    LogicalKeyboardKey.keyJ: GameAction.attack,
    LogicalKeyboardKey.escape: GameAction.pause,
  };
  
  static Set<GameAction> getActions(Set<LogicalKeyboardKey> keys) {
    return keys
        .map((key) => keyMap[key])
        .whereType<GameAction>()
        .toSet();
  }
}

// Usage
class Player extends PositionComponent with KeyboardHandler {
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final actions = InputMapper.getActions(keysPressed);
    
    if (actions.contains(GameAction.moveLeft)) velocity.x = -speed;
    if (actions.contains(GameAction.moveRight)) velocity.x = speed;
    if (actions.contains(GameAction.jump) && onGround) jump();
    
    return true;
  }
}
```
