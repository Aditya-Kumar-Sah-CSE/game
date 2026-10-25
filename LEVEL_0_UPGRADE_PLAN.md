# LEVEL 0 UPGRADE PLAN: CAMP BLACKWOOD TACTICAL TRAINING FACILITY

**Project:** OPERATION SHADOW (Godot 4.7.2)  
**Document:** LEVEL_0_UPGRADE_PLAN.md  
**Author:** Senior 3D Game Developer & Level Architect  
**Status:** APPROVED FOR EXECUTION  

---

## 1. Inspection of Existing Level 0 Implementation

### 1.1 Current Architecture
- **Scene Entry:** `scenes/levels/level_base.tscn` instantiates `scripts/levels/level_base.gd`.
- **Environment Generation:** Currently generates a flat plane with procedural procedural cover objects (`Sandbags.glb`, `Crate.glb`, `Barrel.glb`, `Tree_1.glb`, `Bush_1.glb`) scattered randomly via RNG.
- **Player Setup:** Spawns `PlayerController` at `(0, 0.1, 0)` with camera pivot, SpringArm3D collision, over-the-shoulder ADS camera, and equipped Assault Rifle (`AssaultRifle.glb`).
- **Enemies / Targets:** Spawns 3 stationary `training_dummy` entities in a line at `Z = -18.0`.
- **Navigation:** `NavigationRegion3D` bakes static colliders on Collision Layer 1.
- **Collision Matrix:**
  - Layer 1: Static Environment & Obstacles
  - Layer 2: Player (`PlayerController`)
  - Layer 4: Enemies (`EnemyController`) & Target hitboxes
  - Layer 8: Hitscan Weapon Projectiles
  - Layer 32: Triggers (Waypoints, Beacons, Obstacle Detectors)
- **Defects Identified:**
  1. *Premature Extraction:* `MissionManager` currently allows reaching `waypoint_2` before earlier targets are destroyed.
  2. *Unstructured Arena:* The training level is randomly scattered rather than laid out as a real military training ground.
  3. *Missing Moving Targets:* All targets are stationary; no track-based moving targets exist.
  4. *Missing Obstacle Course:* No actual jump barriers, crouch clearance tunnels, or sprint zones exist to teach movement mechanics.
  5. *Missing Combat Arena in Level 0:* Training lacks a tactical combat encounter with live hostile combatants before extraction.

---

## 2. Structured Training Facility Layout (5 Zones)

The upgraded level transforms the 100m x 100m facility into 5 dedicated, sequential zones:

```
[ +Z: South ]
                  [ ZONE A: SPAWN & ORIENTATION ]
                         Origin: (0, 0, 16)
                    Staging Pad, Ammo Benches, Signs
                                 |
                                 v
                 [ ZONE B: MOVEMENT OBSTACLE COURSE ]
                         Path: (0, 0, 10) -> (0, 0, 0)
                   Sprint Lane -> Jump Hurdle -> Crouch Pipe
                                 |
                                 v  (Waypoint 1)
                  [ ZONE C: TACTICAL SHOOTING RANGE ]
                         Firing Line: (0, 0, -8)
                   Stationary Targets (12m, 20m) & Moving Targets
                                 |
                                 v
                  [ ZONE D: COMBAT TRAINING ARENA ]
                        Center: (18, 0, -18)
                 Sandbag Redoubts, Crate Cover, 2 Live Hostiles
                                 |
                                 v
                    [ ZONE E: EXTRACTION HELIPAD ]
                         Pad: (32, 0, -28)
               Sequentially Locked Beacon (Unlocks when Clear)
[ -Z: North ]
```

### Zone A: Spawn & Orientation Zone
- **Coordinates:** `(0, 0, 16)` facing North (`-Z`).
- **Visuals:** Steel staging platform, security gate perimeter, warning signs, weapon supply tables displaying rifle, shotgun, sniper, and pistol models.
- **Tutorial Guidance:** On-screen briefing: *"WELCOME TO BASIC TRAINING, OPERATIVE. PROCEED TO THE OBSTACLE COURSE."*

### Zone B: Movement Obstacle Course
- **Coordinates:** `(0, 0, 12)` to `(0, 0, -2)`.
- **Obstacle 1 — Sprint Lane:** Open straightaway lined with concrete curbs and sandbag dividers. Detects high-speed movement.
- **Obstacle 2 — Jump Hurdle:** 0.6m high concrete barricade requiring the player to press `JUMP` to clear.
- **Obstacle 3 — Crouch Clearance Tunnel:** Low-clearance industrial scaffolding (1.1m ceiling) requiring `CROUCH` to pass beneath without colliding.
- **Waypoint 1 Beacon:** Placed at `(0, 0, -4)` marking course completion and range entry.

### Zone C: Tactical Shooting Range
- **Firing Line:** Marked red concrete line with sandbag firing positions at `(0, 0, -8)`.
- **Target Arrays:**
  - 3 Stationary wooden bullseye standees at varying combat ranges (14m, 20m, 26m).
  - 2 Motorized moving targets sliding horizontally on rail tracks between defined waypoints (`X = -6.0` to `X = 6.0` at `Z = -22.0` and `Z = -28.0`).
- **Hit Feedback:** Sparks, wooden splinter particles, target wobble on impact, and clean destruction signal dispatch.

### Zone D: Combat Training Arena
- **Coordinates:** `(16, 0, -16)` to `(28, 0, -28)`.
- **Layout:** Urban tactical redoubt with concrete blast barriers, stacked crates, steel drums, and high-low cover.
- **Hostiles:** 2 active combat training soldiers using existing `EnemyController` (configured with training health and reduced attack damage).
- **Behavior:** Patrol behind cover, detect the player upon breach, advance using navigation mesh, take tactical cover, and fire.

### Zone E: Extraction Helipad & Pickup Beacon
- **Coordinates:** `(32, 0, -28)`.
- **Visuals:** Concrete helipad with yellow perimeter hazard stripes, high-intensity corner floodlights, and a central circular landing pad.
- **Sequential Lock Mechanism:**
  - While training is active: extraction beacon is locked (red beacon light, prompt: *"OBJECTIVES INCOMPLETE"*).
  - When all targets and hostiles are neutralized: beacon turns vivid neon green, radio chime sounds, and on-screen prompt declares: *"EXTRACTION ZONE ACTIVE — MOVE TO EXTRACTION"*.
  - Stepping into the extraction zone completes the mission cleanly and triggers the victory summary.

---

## 3. Modular 3D Asset Utilization (CC0)

All assets utilized in Level 0 are verified under **Creative Commons Zero (CC0)**:
- **`Sandbags.glb`:** Standard tactical waist-high cover (scale `3.2`).
- **`Crate.glb`:** Wooden munitions and supply crates (scale `4.5`–`5.5`).
- **`Barrel.glb`:** Steel fuel drums for tactical perimeter lining (scale `5.5`).
- **`GasCan.glb` & `PropaneTank.glb`:** Hazardous supply props in combat arena.
- **`Rock_1.glb` & `Rock_2.glb`:** Natural granite borders preventing arena exit.
- **`Tree_1.glb`, `Tree_2.glb`, `Bush_1.glb`:** Military perimeter foliage.
- **`AssaultRifle.glb`, `Pistol.glb`, `Shotgun.glb`, `Sniper.glb`:** Weapon displays in orientation zone.

---

## 4. Technical Architecture & Sequential Objective Flow

To guarantee backward compatibility with automated tests while enforcing tutorial ordering:
1. **Objective 0 (`waypoint_1`):** Reaching the end of the obstacle course triggers `report_location_reached("waypoint_1")`.
2. **Objective 1 (`training_dummy` x 3):** Destroying targets on the range dispatches `report_enemy_killed("training_dummy")`.
3. **Combat Arena Hostiles:** Defeating live enemies dispatches `report_enemy_killed("soldier_basic")` or `"enemy"`.
4. **Objective 2 (`waypoint_2`):** Extraction beacon only completes when `current_count >= required_count` for all prior objectives.
5. **No Premature Triggers:** If player walks into the extraction zone early, an alert sounds and extraction does not trigger.

---

## 5. Execution Steps

1. **Step 1:** Create moving target system (`MovingTarget3D`) integrated with weapon damage hit detection.
2. **Step 2:** Build structured 5-zone training facility in `level_base.gd` (Zones A, B, C, D, E).
3. **Step 3:** Implement obstacle course mechanics (jump hurdle, crouch clearance check, sprint prompts).
4. **Step 4:** Implement sequential extraction lock in `level_base.gd` and `mission_manager.gd`.
5. **Step 5:** Run full automated test suite (69/69) and verify zero regressions.
6. **Step 6:** Run E2E gameplay test and capture live in-engine screenshots of the upgraded training grounds.
7. **Step 7:** Verify Android release APK build and measure file size (< 50 MB).
8. **Step 8:** Generate `LEVEL_0_QA_REPORT.md` and commit to Git.
