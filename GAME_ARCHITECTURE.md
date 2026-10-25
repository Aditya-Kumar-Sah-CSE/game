# OPERATION SHADOW — Game Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  GameManager                     │
│  (Autoload Singleton - Global State)             │
├─────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐│
│  │SaveManager│ │AudioMgr  │ │SettingsManager   ││
│  └──────────┘ └──────────┘ └──────────────────┘│
├─────────────────────────────────────────────────┤
│                Scene Tree                        │
│  ┌─────────────────────────────────────────────┐│
│  │              Level Scene                     ││
│  │  ┌─────────┐ ┌──────────┐ ┌──────────────┐ ││
│  │  │ Player  │ │ Enemies  │ │ Environment  │ ││
│  │  │ ┌─────┐ │ │ ┌──────┐ │ │ ┌──────────┐ │ ││
│  │  │ │Move │ │ │ │AI FSM│ │ │ │NavMesh   │ │ ││
│  │  │ │Cam  │ │ │ │Health│ │ │ │Terrain   │ │ ││
│  │  │ │Wpn  │ │ │ │Wpn   │ │ │ │Objects   │ │ ││
│  │  │ └─────┘ │ │ └──────┘ │ │ └──────────┘ │ ││
│  │  └─────────┘ └──────────┘ └──────────────┘ ││
│  │  ┌─────────────────────────────────────────┐││
│  │  │         Mission Manager                  │││
│  │  │  Objectives → Progress → Completion      │││
│  │  └─────────────────────────────────────────┘││
│  │  ┌─────────────────────────────────────────┐││
│  │  │         HUD / Touch Controls             │││
│  │  └─────────────────────────────────────────┘││
│  └─────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

## Core Systems

### 1. GameManager (Autoload)
- Global game state (menu, playing, paused, mission_complete, mission_failed)
- Scene transitions
- Player data management
- Campaign progression

### 2. SaveManager (Autoload)
- JSON-based save/load
- Save versioning
- Default values for missing fields
- Corruption detection

### 3. Player System
- **PlayerController** (CharacterBody3D): Movement, physics, collision
- **PlayerCamera** (Camera3D on SpringArm3D): Third-person orbit, collision
- **PlayerInput**: Abstracted input layer (desktop + mobile)
- **PlayerHealth**: HP, armor, damage, death

### 4. Weapon System
- **WeaponData** (Resource): Damage, fire rate, magazine, reload time, recoil, spread
- **WeaponManager**: Current weapon, switching, inventory
- **Weapon** (Node3D): Fire, reload, ammo tracking, effects
- **Projectile/Hitscan**: Raycast or physics-based projectiles

### 5. Enemy AI System
- **EnemyController** (CharacterBody3D): Movement, navigation
- **EnemyAI** (State Machine): Idle→Patrol→Alert→Chase→Attack→Die
- **EnemyHealth**: HP, damage, death
- **EnemySpawner**: Spawning, pooling, wave management

### 6. Mission System
- **MissionData** (Resource/JSON): Objectives, enemies, rewards
- **MissionManager**: Track objectives, check completion/failure
- **ObjectiveTypes**: Eliminate, Reach, Survive, Defend, Collect, Activate

### 7. UI System
- **MainMenu**: Start, continue, settings
- **HUD**: Health, ammo, objectives, minimap
- **TouchControls**: Virtual joystick, action buttons
- **PauseMenu**: Resume, restart, settings, quit
- **MissionResult**: Complete/failed screen with stats

### 8. Audio System
- **AudioManager** (Autoload): Music, SFX, UI sounds
- Volume control per category
- 3D positional audio for weapons, footsteps, enemies

## Data Flow

```
Input → PlayerInput → PlayerController → WeaponManager → Weapon
                                                           ↓
                                              Raycast/Projectile
                                                           ↓
                                              EnemyHealth.take_damage()
                                                           ↓
                                              EnemyAI state change
                                                           ↓
                                              MissionManager.check_objectives()
                                                           ↓
                                              GameManager.mission_complete/fail
```

## Multiplayer-Ready Design
- Input is abstracted through PlayerInput (replaceable with network input)
- Player state separated from input processing
- Damage goes through a validation layer
- Mission state managed centrally (future: server authority)
- No direct coupling between input polling and game logic

## Performance Targets
- 30 FPS minimum on mid-range Android devices
- 60 FPS on capable devices
- Max 8 active enemies simultaneously on mobile
- Object pooling for bullets, effects, particles
- LOD for distant objects
- Texture compression (ETC2/ASTC)
- Baked lighting where possible
