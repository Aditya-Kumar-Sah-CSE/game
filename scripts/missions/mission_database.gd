extends Node
class_name MissionDatabase
## Static mission data provider. All mission configurations live here.

# Mission data structure:
# {
#   "id": int,
#   "name": String,
#   "description": String,
#   "environment": String,  # forest, desert, military_base, village, industrial
#   "scene_path": String,
#   "objectives": [{ "type": String, "target": Variant, "count": int, "description": String }],
#   "enemy_count": int,
#   "enemy_types": [String],
#   "difficulty": float,  # 0.0 to 1.0
#   "weapons_available": [String],
#   "completion_conditions": Dictionary,
#   "failure_conditions": Dictionary,
#   "rewards": { "xp": int, "currency": int },
#   "next_level": int,
#   "time_limit": float  # 0 = no limit
# }

static var _missions: Dictionary = {}
static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_build_mission_database()


static func get_mission(id: int) -> Dictionary:
	_ensure_init()
	return _missions.get(id, {})


static func get_all_missions() -> Dictionary:
	_ensure_init()
	return _missions


static func get_mission_count() -> int:
	_ensure_init()
	return _missions.size()


static func validate_mission(id: int) -> Array[String]:
	"""Returns a list of validation errors for a mission. Empty = valid."""
	_ensure_init()
	var errors: Array[String] = []
	
	if not _missions.has(id):
		errors.append("Mission %d does not exist" % id)
		return errors
	
	var m: Dictionary = _missions[id]
	
	if not m.has("name") or m["name"].is_empty():
		errors.append("Mission %d: missing name" % id)
	if not m.has("objectives") or m["objectives"].size() == 0:
		errors.append("Mission %d: no objectives defined" % id)
	if not m.has("scene_path") or m["scene_path"].is_empty():
		errors.append("Mission %d: missing scene_path" % id)
	if not m.has("rewards"):
		errors.append("Mission %d: missing rewards" % id)
	if m.has("next_level") and m["next_level"] > 0:
		if not _missions.has(m["next_level"]):
			errors.append("Mission %d: next_level %d does not exist" % [id, m["next_level"]])
	
	# Validate objectives
	for obj in m.get("objectives", []):
		if not obj.has("type"):
			errors.append("Mission %d: objective missing type" % id)
		if not obj.has("description"):
			errors.append("Mission %d: objective missing description" % id)
	
	return errors


static func validate_all_missions() -> Dictionary:
	"""Validate every mission. Returns {mission_id: [errors]}."""
	_ensure_init()
	var results: Dictionary = {}
	for id in _missions:
		var errors := validate_mission(id)
		if errors.size() > 0:
			results[id] = errors
	return results


static func _build_mission_database() -> void:
	# Level 0: Tutorial
	_missions[0] = {
		"id": 0,
		"name": "Basic Training",
		"description": "Learn the fundamentals of combat. Movement, aiming, firing, and reloading.",
		"environment": "military_base",
		"scene_path": "res://scenes/levels/level_base.tscn",
		"objectives": [
			{"type": "reach", "target": "waypoint_1", "count": 1, "description": "Move to the training grounds"},
			{"type": "eliminate", "target": "training_dummy", "count": 3, "description": "Destroy 3 training targets"},
			{"type": "reach", "target": "waypoint_2", "count": 1, "description": "Reach the extraction point"}
		],
		"enemy_count": 3,
		"enemy_types": ["training_dummy"],
		"difficulty": 0.1,
		"weapons_available": ["assault_rifle"],
		"completion_conditions": {"all_objectives": true},
		"failure_conditions": {"player_death": true},
		"rewards": {"xp": 50, "currency": 25},
		"next_level": 1,
		"time_limit": 0
	}
	
	# Levels 1-5: Basic Combat
	var basic_levels := [
		{"name": "First Contact", "desc": "Engage patrol enemies in the forest.", "env": "forest", "enemies": 5, "diff": 0.15},
		{"name": "Clearing the Path", "desc": "Eliminate hostiles blocking the road.", "env": "forest", "enemies": 6, "diff": 0.2},
		{"name": "Silent Approach", "desc": "Navigate through enemy territory.", "env": "forest", "enemies": 7, "diff": 0.25},
		{"name": "Supply Run", "desc": "Secure the supply depot.", "env": "village", "enemies": 8, "diff": 0.3},
		{"name": "Holding Ground", "desc": "Defend your position against waves.", "env": "village", "enemies": 10, "diff": 0.35}
	]
	
	for i in basic_levels.size():
		var level_id := i + 1
		var data: Dictionary = basic_levels[i]
		_missions[level_id] = {
			"id": level_id,
			"name": data["name"],
			"description": data["desc"],
			"environment": data["env"],
			"scene_path": "res://scenes/levels/level_base.tscn",
			"objectives": [
				{"type": "eliminate", "target": "enemy", "count": data["enemies"], "description": "Eliminate all hostiles (%d)" % data["enemies"]}
			],
			"enemy_count": data["enemies"],
			"enemy_types": ["soldier_basic"],
			"difficulty": data["diff"],
			"weapons_available": ["assault_rifle", "pistol"],
			"completion_conditions": {"all_objectives": true},
			"failure_conditions": {"player_death": true},
			"rewards": {"xp": 100 + level_id * 20, "currency": 50 + level_id * 10},
			"next_level": level_id + 1,
			"time_limit": 0
		}
	
	# Levels 6-10: Tactical Combat
	var tactical_names := ["Patrol Intercept", "Ammo Conservation", "Timed Strike", "Flanking Maneuver", "Night Ops"]
	var tactical_envs := ["forest", "village", "military_base", "forest", "village"]
	for i in tactical_names.size():
		var level_id := i + 6
		_missions[level_id] = {
			"id": level_id,
			"name": tactical_names[i],
			"description": "Advanced tactical operation requiring careful planning.",
			"environment": tactical_envs[i],
			"scene_path": "res://scenes/levels/level_base.tscn",
			"objectives": [
				{"type": "eliminate", "target": "enemy", "count": 8 + i * 2, "description": "Eliminate hostiles (%d)" % (8 + i * 2)},
				{"type": "survive", "target": null, "count": 60 + i * 30, "description": "Survive for %d seconds" % (60 + i * 30)}
			],
			"enemy_count": 8 + i * 2,
			"enemy_types": ["soldier_basic", "soldier_patrol"],
			"difficulty": 0.4 + i * 0.04,
			"weapons_available": ["assault_rifle", "pistol", "smg"],
			"completion_conditions": {"all_objectives": true},
			"failure_conditions": {"player_death": true},
			"rewards": {"xp": 200 + level_id * 20, "currency": 100 + level_id * 10},
			"next_level": level_id + 1,
			"time_limit": 300 if i == 2 else 0
		}
	
	# Generate remaining levels (11-50) procedurally from templates
	var env_cycle := ["village", "military_base", "desert", "industrial", "forest"]
	var difficulty_names := [
		"Breach and Clear", "Urban Warfare", "Desert Storm", "Factory Raid", "Deep Forest",
		"Village Assault", "Base Infiltration", "Sand Dune Ambush", "Warehouse Siege", "Jungle Strike",
		"Civilian Rescue", "Command Post", "Oasis Defense", "Refinery Sabotage", "River Crossing",
		"Market Square", "Armory Heist", "Canyon Pursuit", "Power Plant", "Ridge Assault",
		"Harbor Strike", "Tower Defense", "Dust Bowl", "Pipeline Sabotage", "Final Frontier",
		"Last Stand", "Operation Endgame", "Shadow Protocol", "Iron Curtain", "Ghost Recon",
		"Eagle Eye", "Thunder Strike", "Silent Storm", "Dark Horizon", "Omega Point",
		"Phoenix Rising", "Viper Strike", "Wolf Pack", "Iron Fist", "Final Shadow"
	]
	
	for i in range(40):
		var level_id := i + 11
		var env_index := i % env_cycle.size()
		var enemy_count := 10 + (i / 5) * 3
		var diff := 0.5 + (float(i) / 40.0) * 0.5  # 0.5 to 1.0
		var name_index := mini(i, difficulty_names.size() - 1)
		
		var objectives: Array = [
			{"type": "eliminate", "target": "enemy", "count": enemy_count, "description": "Eliminate all hostiles (%d)" % enemy_count}
		]
		
		# Add variety in objectives
		if i % 3 == 0:
			objectives.append({"type": "reach", "target": "extraction", "count": 1, "description": "Reach the extraction point"})
		if i % 5 == 0:
			objectives.append({"type": "survive", "target": null, "count": 120, "description": "Survive for 120 seconds"})
		if i % 7 == 0:
			objectives.append({"type": "defend", "target": "base", "count": 90, "description": "Defend the base for 90 seconds"})
		
		var enemy_types := ["soldier_basic", "soldier_patrol"]
		if level_id > 20:
			enemy_types.append("soldier_heavy")
		if level_id > 35:
			enemy_types.append("soldier_elite")
		
		var available_weapons := ["assault_rifle", "pistol", "smg"]
		if level_id > 15:
			available_weapons.append("shotgun")
		if level_id > 25:
			available_weapons.append("sniper")
		
		_missions[level_id] = {
			"id": level_id,
			"name": difficulty_names[name_index],
			"description": "Campaign mission %d — %s" % [level_id, difficulty_names[name_index]],
			"environment": env_cycle[env_index],
			"scene_path": "res://scenes/levels/level_base.tscn",
			"objectives": objectives,
			"enemy_count": enemy_count,
			"enemy_types": enemy_types,
			"difficulty": diff,
			"weapons_available": available_weapons,
			"completion_conditions": {"all_objectives": true},
			"failure_conditions": {"player_death": true},
			"rewards": {"xp": 150 + level_id * 25, "currency": 75 + level_id * 15},
			"next_level": level_id + 1 if level_id < 50 else -1,
			"time_limit": 0
		}
