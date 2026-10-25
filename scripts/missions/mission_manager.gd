extends Node
class_name MissionManager
## Manages active mission objectives, tracking progress, and completion/failure.

signal objective_updated(index: int, progress: int, target: int, description: String)
signal objective_completed(index: int, description: String)
signal all_objectives_completed()
signal mission_timer_updated(time_remaining: float)

var _mission_data: Dictionary = {}
var _objectives: Array[Dictionary] = []
var _is_active: bool = false
var _survive_timer: float = 0.0
var _defend_timer: float = 0.0
var _time_limit: float = 0.0
var _time_elapsed: float = 0.0


func start_mission(mission_data: Dictionary) -> void:
	_mission_data = mission_data
	_objectives = []
	_is_active = true
	_time_elapsed = 0.0
	_time_limit = mission_data.get("time_limit", 0.0)
	
	# Initialize objectives
	for obj_data in mission_data.get("objectives", []):
		_objectives.append({
			"type": obj_data.get("type", "eliminate"),
			"target": obj_data.get("target", ""),
			"required_count": obj_data.get("count", 1),
			"current_count": 0,
			"description": obj_data.get("description", ""),
			"completed": false
		})
	
	# Emit initial state
	for i in _objectives.size():
		var obj := _objectives[i]
		objective_updated.emit(i, obj["current_count"], obj["required_count"], obj["description"])


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time_elapsed += delta
	
	# Time limit check
	if _time_limit > 0:
		var remaining := _time_limit - _time_elapsed
		mission_timer_updated.emit(remaining)
		if remaining <= 0:
			GameManager.fail_mission("Time expired")
			_is_active = false
			return
	
	# Update survive-type objectives
	for i in _objectives.size():
		var obj := _objectives[i]
		if obj["completed"]:
			continue
		
		if obj["type"] == "survive" or obj["type"] == "defend":
			obj["current_count"] = int(_time_elapsed)
			if obj["current_count"] >= obj["required_count"]:
				obj["completed"] = true
				objective_completed.emit(i, obj["description"])
			objective_updated.emit(i, mini(obj["current_count"], obj["required_count"]), obj["required_count"], obj["description"])
	
	# Check if all objectives are complete
	_check_all_complete()


func report_enemy_killed(enemy_type: String = "enemy") -> void:
	if not _is_active:
		return
	
	for i in _objectives.size():
		var obj := _objectives[i]
		if obj["completed"]:
			continue
		if obj["type"] == "eliminate":
			var target := obj["target"] as String
			if target == "enemy" or target == enemy_type or target == "training_dummy":
				obj["current_count"] += 1
				objective_updated.emit(i, obj["current_count"], obj["required_count"], obj["description"])
				if obj["current_count"] >= obj["required_count"]:
					obj["completed"] = true
					objective_completed.emit(i, obj["description"])
	
	_check_all_complete()


func report_location_reached(location_id: String) -> void:
	if not _is_active:
		return
	
	for i in _objectives.size():
		var obj := _objectives[i]
		if obj["completed"]:
			continue
		if obj["type"] == "reach" and obj["target"] == location_id:
			obj["current_count"] = obj["required_count"]
			obj["completed"] = true
			objective_updated.emit(i, obj["current_count"], obj["required_count"], obj["description"])
			objective_completed.emit(i, obj["description"])
	
	_check_all_complete()


func report_item_collected(item_id: String) -> void:
	if not _is_active:
		return
	
	for i in _objectives.size():
		var obj := _objectives[i]
		if obj["completed"]:
			continue
		if obj["type"] == "collect" and obj["target"] == item_id:
			obj["current_count"] += 1
			objective_updated.emit(i, obj["current_count"], obj["required_count"], obj["description"])
			if obj["current_count"] >= obj["required_count"]:
				obj["completed"] = true
				objective_completed.emit(i, obj["description"])
	
	_check_all_complete()


func report_object_activated(object_id: String) -> void:
	if not _is_active:
		return
	
	for i in _objectives.size():
		var obj := _objectives[i]
		if obj["completed"]:
			continue
		if obj["type"] == "activate" and obj["target"] == object_id:
			obj["current_count"] = obj["required_count"]
			obj["completed"] = true
			objective_updated.emit(i, obj["current_count"], obj["required_count"], obj["description"])
			objective_completed.emit(i, obj["description"])
	
	_check_all_complete()


func get_objectives_summary() -> Array[Dictionary]:
	return _objectives.duplicate(true)


func get_progress_percentage() -> float:
	if _objectives.is_empty():
		return 0.0
	var completed := 0
	for obj in _objectives:
		if obj["completed"]:
			completed += 1
	return float(completed) / float(_objectives.size()) * 100.0


func _check_all_complete() -> void:
	if not _is_active:
		return
	
	for obj in _objectives:
		if not obj["completed"]:
			return
	
	# All objectives complete!
	_is_active = false
	all_objectives_completed.emit()
	GameManager.complete_mission()


func stop() -> void:
	_is_active = false
