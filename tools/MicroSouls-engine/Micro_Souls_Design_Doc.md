# Project: "MircoSouls-Engine" - The Final Build
We are initializing a new project folder: `/MircoSouls_Engine`. This is a professional-grade, unified AI engine for Godot that handles character barks and animation sequences.

## 1. Environment & Version Control Setup
- Initialize a new Git repository in the `/MircoSouls_Engine` folder.
- Create a `.gitignore` that excludes `__pycache__`, large raw model weights (.pth), and OS-specific files.
- Perform a 'git init' and a 'git commit -m "Initial commit: Project structure and core design"' immediately after setup.

## 2. Integrated "Director" Architecture
- Review `/scripts/enemy_grunt.gd` and `/scripts/player.gd` for state-machine parity.
- Build a unified Character-Level Transformer (under 5MB ONNX) that outputs JSON: 
  `{"text": "Bark Content", "anim": ["frame_01", "frame_02"], "mood": "Aggressive"}`.

## 3. The MircoSouls Dashboard (Streamlit)
- Build a one-page command center in `src/dashboard.py`.
- Features: 
  - **Live Testing:** Dropdowns for Bosses/Villagers/Grunts to see their generated sequences.
  - **The "Forge":** Buttons to generate data, train the model, and export to INT8 ONNX.
  - **State Tweak:** Sliders for Temperature and Top-P to vary the "souls" of your characters.

## 4. Best Practices Implementation
- Use a `requirements.txt` for all Python dependencies.
- Implement a logging system so I can see training loss in the dashboard.
- Ensure the GDScript bridge is modular and can be attached to any CharacterBody2D in Godot.

Cline, please begin by initializing the folder, setting up Git, and drafting the project README.
