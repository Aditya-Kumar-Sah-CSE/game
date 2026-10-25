extends Node
## SaveManager - Handles persistent save/load with version handling (Autoload Singleton)

const SAVE_PATH := "user://operation_shadow_save.json"
const CURRENT_SAVE_VERSION := 1

signal save_completed()
signal load_completed(data: Dictionary)


func save_game(data: Dictionary) -> bool:
	data["save_version"] = CURRENT_SAVE_VERSION
	data["save_timestamp"] = Time.get_unix_time_from_system()
	
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Cannot open save file for writing: %s" % FileAccess.get_open_error())
		return false
	
	file.store_string(json_string)
	file.close()
	
	save_completed.emit()
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Cannot open save file for reading")
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		push_warning("SaveManager: Save file is empty")
		return {}
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Failed to parse save file: %s" % json.get_error_message())
		return _get_defaults()
	
	var data: Dictionary = json.data
	if not data is Dictionary:
		push_error("SaveManager: Save data is not a dictionary")
		return _get_defaults()
	
	# Version migration
	var save_version: int = data.get("save_version", 0)
	if save_version < CURRENT_SAVE_VERSION:
		data = _migrate_save(data, save_version)
	
	load_completed.emit(data)
	return data


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _get_defaults() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"selected_character": "male_soldier",
		"campaign": {
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
	}


func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	# Future migration logic goes here
	# Example: if from_version < 2: add new fields
	data["save_version"] = CURRENT_SAVE_VERSION
	return data
