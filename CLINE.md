# CLINE.md - Best Practices & Context for HelloKnight Development

## Project Overview
HelloKnight is a 2D action RPG/Souls-like game built in Godot 4. Focus on methodical combat, risk/reward, and atmospheric storytelling within a small scope (30-90 minutes).

## Development Philosophy
- **Finish over perfect**: Prioritize completion over complexity
- **Iterative design**: Build core systems first, expand later
- **Clean architecture**: Keep code modular and readable
- **Test early**: Validate mechanics before adding features

## ⚠️ Critical Lessons Learned

### State Machine Structural Breakdowns
**Issue**: Base class state behaviors that automatically transition states can conflict with subclass logic (e.g., enemy IDLE immediately changing to PATROL, breaking timer-based idle periods).

**Prevention**:
- Base classes should handle movement/physics only
- Subclasses control state transitions and timing
- Use clear separation: base handles "what", subclass handles "when"
- Avoid automatic transitions in base state behaviors
- Document state responsibilities clearly

**Example Fixed**:
```gdscript
# ❌ Bad: Base assumes IDLE = transition
func _idle_behavior(delta): change_state(PATROL)

# ✅ Good: Base handles movement, subclass handles logic
func _idle_behavior(delta): velocity.x = move_toward(velocity.x, 0, friction)
# Subclass decides: if timer_done: change_state(PATROL)
```

**Additional Fix**: Enemy idle timer issue - base class was overriding subclass timer logic
- **Problem**: Base `_idle_behavior` immediately changed to PATROL, canceling timer
- **Solution**: Base only stops movement, subclasses handle all transitions
- **Result**: Timer-based idle periods now work correctly

**Multi-Hit Prevention Fix**: Attack hitboxes were causing multiple damage per attack
- **Problem**: Enemy attack animations stayed active longer than hurtbox i-frames
- **Solution**: Added `has_hit` flag to attack_hitbox, reset on animation finish
- **Result**: Clean single-hit attacks, no damage spam

**Killzone Death State Fix**: Killzone bypassed proper death handling
- **Problem**: Killzone directly reloaded scene instead of triggering die() method
- **Solution**: Killzone now calls `body.die()` for proper slow-motion death sequence
- **Result**: Consistent death handling across fall damage and enemy kills

## Current Architecture

### State Machines
**Player States (11)**: IDLE, RUN, JUMP, FALL, ROLL, ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAGGER, HURT, DIE
**Enemy States (6)**: IDLE, PATROL, CHASE, ATTACK, HURT, DIE

**Animation-Based States** (use animation_finished signal):
- ROLL, ATTACK_LIGHT, ATTACK_HEAVY, HURT, DIE
- **Advantage**: Easy timing tweaks via animation FPS/frames
- **Consistency**: Multi-hit prevention can use HURT animation length

**Future States to Plan For**:
- **STAMINA**: Low stamina state affecting movement/combat
- **BLOCK_STAMINA**: Blocking while stamina depleted
- **CLIMB**: Ladder/wall climbing (if added)
- **SWIM**: Water movement (if added)

### Combat System
- **Simple Damage**: Direct hit detection (attack_hitbox → hurtbox → take_damage)
- **I-Frames**: Hurtbox monitoring toggles during actions
- **Health System**: Signals for UI updates
- **Future**: RPS outcomes, timing windows, directional attacks

### Collision Layers (Godot Project Settings)
- Layer 1: World/TileMap
- Layer 2: PlayerBody (masks: 1,3)
- Layer 3: EnemyBody (masks: 1,2)
- Layer 4: Hurtbox (masks: 5)
- Layer 5: AttackHitbox (masks: 4, monitoring: false by default)

**Layer Setup Protocol**: For collision layer changes, user will handle manual setup in Godot editor to ensure accuracy. Avoid programmatic layer modifications to prevent confusion between decimal/binary representations.

## Best Practices

### State Machine Patterns
- **Categories**: Group related states for condition checks
- **Transitions**: Centralize in change_state() function
- **Animation**: Match state names to animation names where possible
- **Cleanup**: Handle monitoring, timers, and effects in change_state

### Combat Design
- **Hitboxes**: Separate from body collision
- **I-Frames**: Disable hurtbox during vulnerable actions
- **Feedback**: Print debug info during development
- **Balance**: Start simple, iterate based on feel

### Code Organization
- **Scripts**: One primary responsibility per script
- **Signals**: Use for decoupling (health_changed, died)
- **Constants**: Define state arrays at top of scripts
- **Comments**: Explain complex logic, not obvious code

### Debugging Workflow
1. **Isolate**: Test one system at a time
2. **Prints**: Add debug output for state changes
3. **Layers**: Verify collision layer configurations
4. **Signals**: Check signal connections in editor

## Project Assets & Notes

### Project Assets & Notes
- **Coin**: Working placeholder for collectable items or currency later
- **Enemy Assets**: Snoblin pack provides main enemy sprites/animations
- **Animation Limits**: Most enemies have limited animations - plan for sprite shaking/polish
- **Enemy Types**: Focus on goblin variants from Snoblin pack for initial enemies

## Current Development Status

### ✅ Version 0.1 Complete - Pushed to GitHub
**Repository**: https://github.com/Toastyst/HelloKnight
**Commit**: feat: Complete core state machine and combat system
**Files**: 967 objects committed and pushed

**Core Features Implemented:**
- Player state machine with combat states (11/11 states)
- Enemy template with AI framework (6/8 states)
- Health system with signals
- Stamina system with consumption/regeneration (attacks: 15/25, roll: 20, block: 15)
- Blocking mechanics with damage reduction (50%)
- Roll pass-through collision system (enemy body avoidance during roll)
- Multi-hit prevention for attacks (clean single-hit damage)
- Basic UI components (health + stamina bars)
- Collision layer planning and implementation
- Direct damage system with CombatManager
- Killzone proper death state handling
- Git repository setup and version control

### 🚧 In Progress
- Combat testing and balancing
- Animation implementation (block, exhausted states)

### 📋 Next Steps
- Add enemy variety (skeleton)
- Implement advanced combat features (parry, lock-on)
- Polish animations and visual feedback
- Add sound effects and music integration

## Future Expansion Planning

### State Machine Scalability
**Current Structure**: Clean separation between player/enemy states
**Future Additions**:
- Add STAMINA state to both player and enemies
- BLOCK_STAMINA for exhausted blocking
- Movement states (CLIMB, SWIM) if platforming expands

**State Categories to Maintain**:
```gdscript
const MOVEMENT_STATES = [IDLE, RUN, JUMP, FALL, CLIMB, SWIM]
const COMBAT_STATES = [ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAMINA, ...]
const VULNERABLE_STATES = [IDLE, RUN, JUMP, FALL, STAGGER]
```

### Combat System Expansion
- **RPS Outcomes**: Rock-paper-scissors style attack resolution
- **Timing Windows**: Parry/clash timing mechanics
- **Directional Attacks**: Position-based attack variations
- **Stamina Costs**: Resource management for actions
- **Line-of-Sight Detection**: Raycast-based enemy vision
- **Enhanced Attack Behavior**: Active positioning during attacks
- **Directional Attack Hitboxes**: Hitbox positioning adjusts based on facing direction
- **Roll Phase-Through**: Player can pass through enemy bodies during roll (i-frames)
- **Dynamic Collision Layers**: Collision masks change during special abilities

## File Structure
```
scripts/
├── player.gd              # Player state machine & controls
├── enemy_template.gd      # Base enemy with states & AI
├── enemy_grunt.gd         # Patrol enemy implementation
├── attack_hitbox.gd       # Direct damage dealing (multi-hit prevention)
├── hurtbox.gd             # Damage receiving (parked)
├── combat_manager.gd      # Complex combat resolution (parked)
├── health_bar.gd          # UI health display
├── stamina_bar.gd         # UI stamina display
├── game_manager.gd        # Game state management (parked)
├── controls_layout.gd     # Input configuration (parked)
└── coin.gd               # Collectable placeholder

scenes/
├── player.tscn           # Player with hitboxes
├── enemies/
│   ├── enemy_grunt.tscn  # Enemy with hitboxes
│   └── skele0.tscn       # Future skeleton enemy
├── ui_bars.tscn          # Health and stamina UI
└── game.tscn            # Main scene
```

## Development Workflow
1. **Plan**: Update CLINE.md with new features/decisions
2. **Implement**: Follow established patterns
3. **Test**: Use debug prints, verify state transitions
4. **Document**: Update CLINE.md with lessons learned
5. **Iterate**: Small changes, frequent testing

---

*Last Updated: 2026-03-26*

### StateMachine Structure
**Base Class (state_machine.gd)**:
- Node extending, manages hurtbox/attackbox monitoring, animation playback.
- Virtual methods: process(), handle_animation_finished(), getters for states/types.
- change_state() handles monitoring and animation.

**PlayerStateMachine (player_state_machine.gd)**:
- Enum: IDLE, RUN, JUMP, FALL, ROLL, ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAMINA, STAGGER, HURT, DIE
- process_input(): Input priority (combat > movement), auto-transitions (landing, air).
- handle_animation_finished(): Roll/attack/hurt/die transitions, collision for roll.

**EnemyStateMachine (enemy_state_machine.gd)**:
- Enum: IDLE, PATROL, CHASE, ATTACK, HURT, DIE
- process_ai(): Detection/transitions, cooldowns.
- handle_animation_finished(): Attack cooldown, return to chase/idle.

**GruntStateMachine (enemy_grunt_state_machine.gd)**:
- Extends EnemyStateMachine, adds patrol ping-pong with idle timer.
- Overrides process_ai() for patrol logic, change_state() for random attack_type.

**Integration**:
- Base classes (player.gd, enemy_template.gd): Instantiate SM in _ready, delegate process_* in _physics_process, match state for physics/behaviors, delegate combat methods.
- Subclasses (enemy_grunt.gd): Override SM type, keep specific behaviors (_chase_behavior for jump).

*Keep this file current with project evolution*
