extends Node
## GameManager - Global game state controller (Autoload Singleton)
## Manages game states, scene transitions, campaign progression, and player data.

const MissionDatabase = preload("res://scripts/missions/mission_database.gd")

signal state_changed(new_state: GameState)
signal mission_started(mission_id: int)
signal mission_completed(mission_id: int, stats: Dictionary)
signal mission_failed(mission_id: int, reason: String)
signal player_died()

enum GameState {
	MAIN_MENU,
	LOADING,
	PLAYING,
	PAUSED,
	MISSION_COMPLETE,
	MISSION_FAILED,
	CHARACTER_SELECT,
	WEAPON_SELECT,
	SETTINGS
}

var current_state: GameState = GameState.MAIN_MENU
var current_mission_id: int = -1
var selected_character: String = "male_soldier"
var is_mobile: bool = false

# Campaign data
var campaign_data: Dictionary = {
	"xp": 0,
	"currency": 0,
	"unlocked_levels": [0],
	"completed_levels": [],
	"unlocked_weapons": ["assault_rifle", "pistol"],
	"selected_weapons": ["assault_rifle", "pistol"],
	"statistics": {
		"missions_completed": 0,
		"missions_failed": 0,
		"enemies_killed": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"time_played": 0.0,
		"deaths": 0
	}
}

# Current mission runtime stats
var mission_stats: Dictionary = {}


func _ready() -> void:
	# Detect mobile platform
	is_mobile = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
	
	# Load saved data
	var save_data := SaveManager.load_game()
	if save_data.size() > 0:
		_apply_save_data(save_data)
	
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current_state == GameState.PLAYING:
			set_state(GameState.PAUSED)
		elif current_state == GameState.PAUSED:
			set_state(GameState.PLAYING)


func set_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		GameState.PAUSED:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameState.MAIN_MENU, GameState.MISSION_COMPLETE, GameState.MISSION_FAILED:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	state_changed.emit(new_state)


func start_mission(mission_id: int) -> void:
	current_mission_id = mission_id
	mission_stats = {
		"enemies_killed": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"damage_taken": 0,
		"time_started": Time.get_unix_time_from_system(),
		"objectives_completed": 0,
		"headshots": 0
	}
	
	# Load the mission scene
	var mission_data: Dictionary = MissionDatabase.get_mission(mission_id)
	if mission_data.is_empty():
		push_error("GameManager: Invalid mission_id %d" % mission_id)
		return
	
	set_state(GameState.LOADING)
	
	var scene_path: String = mission_data.get("scene_path", "res://scenes/levels/level_base.tscn")
	get_tree().change_scene_to_file(scene_path)
	
	# State will be set to PLAYING after scene loads
	await get_tree().tree_changed
	set_state(GameState.PLAYING)
	mission_started.emit(mission_id)


func complete_mission() -> void:
	if current_state != GameState.PLAYING:
		return
	
	mission_stats["time_elapsed"] = Time.get_unix_time_from_system() - mission_stats.get("time_started", 0)
	
	# Update campaign data
	if current_mission_id not in campaign_data["completed_levels"]:
		campaign_data["completed_levels"].append(current_mission_id)
	
	# Unlock next level
	var next_level := current_mission_id + 1
	if next_level not in campaign_data["unlocked_levels"] and next_level <= 50:
		campaign_data["unlocked_levels"].append(next_level)
	
	# Update statistics
	campaign_data["statistics"]["missions_completed"] += 1
	campaign_data["statistics"]["enemies_killed"] += mission_stats.get("enemies_killed", 0)
	campaign_data["statistics"]["shots_fired"] += mission_stats.get("shots_fired", 0)
	campaign_data["statistics"]["shots_hit"] += mission_stats.get("shots_hit", 0)
	
	# Award XP and currency
	var mission_data: Dictionary = MissionDatabase.get_mission(current_mission_id)
	var rewards: Dictionary = mission_data.get("rewards", {"xp": 100, "currency": 50})
	campaign_data["xp"] += rewards.get("xp", 100)
	campaign_data["currency"] += rewards.get("currency", 50)
	
	# Save progress
	SaveManager.save_game(_get_save_data())
	
	set_state(GameState.MISSION_COMPLETE)
	mission_completed.emit(current_mission_id, mission_stats)


func fail_mission(reason: String = "Player died") -> void:
	if current_state != GameState.PLAYING:
		return
	
	mission_stats["time_elapsed"] = Time.get_unix_time_from_system() - mission_stats.get("time_started", 0)
	mission_stats["failure_reason"] = reason
	
	campaign_data["statistics"]["missions_failed"] += 1
	campaign_data["statistics"]["deaths"] += 1
	
	SaveManager.save_game(_get_save_data())
	
	set_state(GameState.MISSION_FAILED)
	mission_failed.emit(current_mission_id, reason)


func restart_mission() -> void:
	if current_mission_id >= 0:
		start_mission(current_mission_id)


func return_to_menu() -> void:
	current_mission_id = -1
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	set_state(GameState.MAIN_MENU)


func is_level_unlocked(level_id: int) -> bool:
	for lvl in campaign_data.get("unlocked_levels", []):
		if int(lvl) == level_id:
			return true
	return false


func is_level_completed(level_id: int) -> bool:
	for lvl in campaign_data.get("completed_levels", []):
		if int(lvl) == level_id:
			return true
	return false


func record_shot_fired() -> void:
	mission_stats["shots_fired"] = mission_stats.get("shots_fired", 0) + 1


func record_shot_hit(is_headshot: bool = false) -> void:
	mission_stats["shots_hit"] = mission_stats.get("shots_hit", 0) + 1
	if is_headshot:
		mission_stats["headshots"] = mission_stats.get("headshots", 0) + 1


func record_enemy_killed() -> void:
	mission_stats["enemies_killed"] = mission_stats.get("enemies_killed", 0) + 1


func _get_save_data() -> Dictionary:
	return {
		"save_version": 1,
		"selected_character": selected_character,
		"campaign": campaign_data.duplicate(true),
		"settings": SettingsManager.get_all_settings()
	}


func _apply_save_data(data: Dictionary) -> void:
	if data.has("selected_character"):
		selected_character = data["selected_character"]
	if data.has("campaign"):
		# Merge carefully to preserve structure
		var saved_campaign: Dictionary = data["campaign"]
		for key in saved_campaign:
			campaign_data[key] = saved_campaign[key]
		
		# Ensure level arrays contain ints (JSON numbers are parsed as floats)
		var unlocked: Array[int] = []
		for lvl in campaign_data.get("unlocked_levels", [0]):
			unlocked.append(int(lvl))
		campaign_data["unlocked_levels"] = unlocked
		
		var completed: Array[int] = []
		for lvl in campaign_data.get("completed_levels", []):
			completed.append(int(lvl))
		campaign_data["completed_levels"] = completed
