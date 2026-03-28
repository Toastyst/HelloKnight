# HelloKnight

A 2D action RPG/Souls-like game built in Godot 4. Experience methodical combat, risk/reward mechanics, and atmospheric storytelling in a dark fantasy world. This is a complete core implementation with state machines, combat systems, and enemy AI.

## Current Status

**Version 0.1 - Core Systems Complete**
- ✅ Player state machine with 11 states (IDLE, RUN, JUMP, FALL, ROLL, ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAGGER, HURT, DIE)
- ✅ Enemy AI with 6 states (IDLE, PATROL, CHASE, ATTACK, HURT, DIE)
- ✅ Health & Stamina systems with regeneration
- ✅ Combat mechanics (attacks, blocking, damage reduction)
- ✅ Roll pass-through collision system
- ✅ Multi-hit prevention for clean attacks
- ✅ UI components (health/stamina bars)
- ✅ Collision layer configuration
- ✅ Modular state machine architecture

## How to Play

- Clone the repository
- Open `project.godot` in Godot 4.x
- Run the main scene: `scenes/main scenes/game.tscn`

## Controls

- **Movement**: WASD or Arrow Keys
- **Jump**: Space
- **Roll**: Shift (ground only, costs 20 stamina)
- **Block**: Hold Shift (50% damage reduction, drains 15 stamina)
- **Light Attack**: Left Mouse Button (costs 15 stamina)
- **Heavy Attack**: Right Mouse Button (costs 25 stamina)


## Core Mechanics



### Combat System
- **Stamina Costs**: Light (15), Heavy (25), Roll (20), Block (15/sec)
- **Regeneration**: 20/sec after 2-second delay
- **Blocking**: Reduces damage by 50%, drains stamina while held
- **Roll Evasion**: Pass through enemy bodies during roll

### State Machines
- **Player**: 11 states with animation-based transitions
- **Enemies**: 6 states with AI-driven behavior
- **Modular Architecture**: Separate physics from state logic

### Enemy AI
- **Grunt Enemies**: Patrol between points with idle timers
- **Detection**: Chase player when in range
- **Combat**: Attack with cooldowns and multi-hit prevention

## Project Structure

```
scripts/
├── player.gd              # Player physics & state delegation
├── player_state_machine.gd # Player state logic & transitions
├── enemy_template.gd      # Base enemy with AI framework
├── enemy_grunt.gd         # Patrol enemy implementation
├── state_machine.gd       # Base state machine class
├── attack_hitbox.gd       # Damage dealing with hit prevention
├── hurtbox.gd             # Damage receiving
├── combat_manager.gd      # Combat resolution system
└── [UI components]

scenes/
├── main scenes/game.tscn  # Main game scene
├── Player and Enemies/    # Character scenes
└── UI/                   # Interface elements
```

## Development

This project follows strict architectural patterns:
- **Separation of Concerns**: Physics in base classes, logic in state machines
- **Signal-Based Communication**: Decoupled systems
- **State-Driven Design**: All behavior controlled by state machines
- **Modular Combat**: Separate hitboxes from collision bodies

See `CLINE.md` for detailed development guidelines and `HelloKnight_Design_Doc.md` for design specifications.

## Credits

All assets are credited in `assets/LICENSES & CREDITS/`. Includes CC0 and commercial assets.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
