# Implementation Plan

## Overview
Rework the state machine architecture in player.gd and enemy_template.gd to resolve structural breakdowns where base class automatic transitions conflict with subclass logic. Base classes will handle only movement and physics; subclasses will control state transitions and timing. This ensures modular, extensible state machines for the HelloKnight game.

The rework aligns with .clinerules best practices: one responsibility per script, signals for decoupling, state arrays at top. It prepares for state machine improvements before further development.

## Types
No new type system changes. Reuse existing State enums in player.gd and enemy_template.gd.

State enums:
- Player: IDLE, RUN, JUMP, FALL, ROLL, ATTACK_LIGHT, ATTACK_HEAVY, BLOCK, STAMINA, STAGGER, HURT, DIE
- Enemy: IDLE, PATROL, CHASE, ATTACK, HURT, DIE

Add typed dict for state data if needed: {name: String, animation: String, vulnerable: bool}

## Files
New files:
- None

Existing files to modify:
- scripts/player.gd - Refactor state machine to base movement/physics, add StateMachine subclass
- scripts/enemy_template.gd - Same for enemies
- scripts/enemy_grunt.gd - Update to use new state logic
- scripts/combat_manager.gd - Minor adjustments for new state queries

No files to delete.

## Functions
New functions:
- player_state_machine.gd: process_input(input_dir: Vector2, delta: float) -> State
- enemy_state_machine.gd: process_ai(delta: float, player_pos: Vector2) -> State

Modified functions:
- player.gd _physics_process(delta) - Delegate to state machine
- enemy_template.gd _physics_process(delta) - Delegate to state machine
- change_state(new_state: State) - Centralize in state machine, emit signals

No functions to remove.

## Classes
New classes:
- StateMachine (base class for player/enemy state logic)
  - process(delta: float) -> State
  - get_state() -> State
  - transition_conditions() -> Array[Callable]

Modified classes:
- Player (scripts/player.gd) - Add state_machine: StateMachine
- EnemyTemplate (scripts/enemy_template.gd) - Add state_machine: StateMachine

Removed classes:
- None

## Dependencies
No new dependencies.

## Testing
Manual testing:
- Run game.tscn
- Test player states: movement, combat, transitions
- Test enemy grunt patrol/chase/attack
- Verify no conflicts in state changes
- Check collision layers, hitboxes

No new test files.

## Implementation Order
1. Create StateMachine base class in new scripts/state_machine.gd
2. Refactor player.gd: Move state logic to PlayerStateMachine extends StateMachine
3. Refactor enemy_template.gd: Move state logic to EnemyStateMachine extends StateMachine
4. Update enemy_grunt.gd to use EnemyStateMachine
5. Update combat_manager.gd for new state queries
6. Test all player/enemy behaviors
7. Update .clinerules with lessons learned