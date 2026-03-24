	--GAME DESIGN DOCUMENT — SOLO 2D SOULS-LIKE--



1. Project Overview

	Working Title: _____HelloKnight__________
	Genre: 2D Action RPG / Souls-like
	Platform: PC (Steam)
	Target Price: $2–$4
	Estimated Playtime: 30–90 minutes
	Developer: Solo

	--High Concept--
	A short, challenging 2D action game inspired by Souls-likes, focused on tight combat, exploration, and tense risk-reward mechanics.

	--Design Goals--
	Deliver a complete, polished small game
	Emphasize skill-based combat over complexity
	Create a strong atmosphere with minimal resources
	Avoid scope creep
	Ship on Steam

	--NON-Goals (Important)--
	NO Large open world
	NO Deep RPG systems
	NO Complex builds
	NO Long narrative
	NO AAA production values

2. Core Pillars -- These define what the game MUST deliver.

	⚔️ Pillar 1 — Methodical Combat
	Stamina-based actions
	Precise timing matters
	Button mashing punished
	Enemy attacks are readable

	💀 Pillar 2 — Risk & Consequence
	Death penalty
	Limited healing
	Currency loss/retrieval
	Tension while exploring

	🏰 Pillar 3 — Oppressive Atmosphere
	Dark or melancholic tone
	Minimal exposition
	Environmental storytelling
	Lonely world feel

3. Core Gameplay Loop
	Fight → Explore → Gain Currency → Upgrade → Die → Retry → Progress
	Player explores hostile area
	Fights enemies carefully
	Collects currency
	Finds checkpoint
	Spends upgrades
	Pushes deeper
	Dies and retries

4. Player Mechanics
	Movement
		Walk / Run
		Jump (optional: Yes / No)
		Dodge Roll or Dash (with i-frames)
	Combat
		Light Attack (fast, low damage, short range)
		Heavy Attack (slow, high damage, longer range)
		Block (reduces damage, drains stamina)
		Parry (perfect timing window for counter-attack)
		Directional attacks based on facing
		Directional rolls based on input

		Attack Flow Chart (Punishing but Fair Timing)

		Light Attack + Idle = Hit (standard damage)
		Light Attack + Light Attack = 50/50 Clash (both stagger)
		Light Attack + Heavy Attack = Defender Advantage (attacker staggers)
		Light Attack + Block = Reduced Damage (50% damage, stamina drain)
		Light Attack + Parry = Perfect Counter (attacker staggers, defender riposte opportunity)

		Heavy Attack + Idle = Big Hit (high damage)
		Heavy Attack + Light Attack = Attacker Advantage (defender staggers)
		Heavy Attack + Heavy Attack = Mutual Stagger (high risk/reward)
		Heavy Attack + Block = Reduced Damage (50% damage, high stamina drain)
		Heavy Attack + Parry = Perfect Counter (attacker staggers, defender riposte opportunity)




	Stamina System (Implemented)
		Light Attack: 15 stamina
		Heavy Attack: 25 stamina
		Roll: 20 stamina
		Block: 15 stamina drain while held
		Regeneration: 20/sec after 2-second delay
		Low stamina affects movement/combat (future feature)
	Health & Healing
		Health bar
		Limited healing uses per checkpoint
		Healing animation can be interrupted

	Strategic Depth & Positioning (Implemented)
		Risk/Reward Combat: Aggressive play vs conservative positioning
		Terrain Usage: Use platforms, walls for flanking and cover
		Enemy Positioning: Lure enemies into traps, separate groups
		Stamina Management: Balance offense vs defense vs mobility
		Roll Pass-Through: Player can roll through enemy bodies (i-frames)
		Attack Anticipation: Read enemy telegraphs for counter opportunities
		Combo Potential: Chain attacks for damage bonuses (future feature)

5. Death System
	Core Souls-like mechanic.
	Player drops currency on death
	Respawns at last checkpoint
	Death spot marked
	Currency recoverable once
	Second death loses it permanently

6. Progression System
	Currency Used for:
	Leveling stats
	Optional upgrades

	Player Stats (Max 3 Recommended)
	☐ Health
	☐ Stamina
	☐ Damage

	Equipment
		Choose ONE approach
			Option A — Single Weapon
			One main weapon for entire game

			Option B — Limited Choice
			1–2 weapon types only
		Weapon upgrades:
		Simple +1, +2, +3 system (optional)

7. Enemies
	Target: 4–8 Types Total
	Type	Description
	Grunt	Basic melee enemy
	Fast	Agile but fragile
	Tank	Slow, high HP
	Ranged	Attacks from distance
	Elite	Strong variant
	Reuse via:
	Palette swaps
	Stat adjustments
	Group compositions

	Enemy Attack Patterns:
	Cooldowns between attacks to prevent spam
	Potential stamina system for enemy actions
	Animation-based attack timing for consistency

8. Bosses
	Target: 2–4 Bosses
	Each boss should have:
	Unique appearance
	Distinct attack patterns
	Large health pool
	Clear telegraphs
	Memorable arena

	Optional:
	Phase 2 (faster or new attack)

9. World Design
	Structure (Choose One)
	☐ Interconnected “Metroidvania-Lite”
	☐ Linear with branching paths ⭐ Recommended for first game

	Features
	Checkpoints reset enemies
	Shortcuts between areas
	Secrets / optional rooms
	Environmental storytelling
	Avoid:
	Large open world
	Complex ability gating

10. Checkpoints
	Function similar to bonfires.
	Save progress
	Restore health & healing
	Respawn enemies
	Allow upgrades

11. Narrative & Setting
	Story Delivery
	Minimal dialogue
	Environmental clues
	Optional item descriptions
	Mysterious tone

	Tone Keywords
	(e.g., bleak, cursed, abandoned, tragic)

12. Visual Style
	Art Direction: _______________________
	Examples:
	Dark pixel art
	Minimalist silhouettes
	Hand-drawn 2D
	Low-color palette
	Key goals:
	Readable enemies
	Clear telegraphs
	Strong atmosphere

13. Audio Design
	Music
	Atmospheric background tracks
	Boss themes (if possible)
	Sound Effects
	Impactful weapon hits
	Distinct enemy sounds
	UI feedback sounds
	Audio carries feel more than graphics.

14. User Interface
	Health bar
	Stamina bar
	Currency display
	Healing count
	Pause menu
	Keep UI minimal.

15. Controls
	Keyboard support
	Controller support ⭐ Highly recommended ⭐
	Rebindable inputs

	Current Godot Input Actions (Implemented):
	A/D or Left/Right Arrow: Move left/right
	W or Up Arrow or Space: Jump
	Shift: Roll (hold during landing for instant roll) - costs 20 stamina
	Left Click: Light attack (costs 15 stamina)
	Shift + Left Click: Heavy attack (costs 25 stamina)
	Right Click (hold): Block (50% damage reduction, drains 15 stamina)


16. Technical Requirements
	Must-have for Steam release:
	Save system
	Settings menu
	Windowed / Fullscreen
	Stable performance
	No game-breaking bugs

17. Scope Targets
	Content Goals
	2–3 Areas
	2–4 Bosses
	4–8 Enemy Types
	30–90 Minutes Gameplay

Completion Criteria

Game is “done” when:

	☐ Playable start to finish
	☐ All bosses implemented
	☐ No progression blockers
	☐ Menus functional
	☐ Credits screen added
	☐ Stable build ready

18. Unique Selling Points (USP)
	What makes THIS game worth buying?
	Examples:
	Unique setting
	Distinct art style
	Novel mechanic
	Humor / tone contrast
	Speedrun-friendly design






19. Future Ideas (Post-Launch)

	(Keep scope safe by parking ideas here.)


---🏁 Final Advice (Solo Dev Reality)---

Your real goal is not: “Make a perfect Souls-like.”

It is: "Finish a complete commercial game."
