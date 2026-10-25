extends SceneTree
## Mission Database Validator — Validates all 51 campaign levels and generates a machine-readable JSON report.

const MissionDatabase = preload("res://scripts/missions/mission_database.gd")

func _init() -> void:
	print("Running comprehensive validation on all campaign missions (0–50)...")
	var missions: Dictionary = MissionDatabase.get_all_missions()
	var report: Dictionary = {
		"total_missions_evaluated": missions.size(),
		"valid_count": 0,
		"issue_count": 0,
		"environments": {},
		"objective_types_found": {},
		"progression_chain_intact": true,
		"mission_details": {}
	}
	
	var supported_objectives := ["eliminate", "reach", "survive", "defend", "collect", "activate"]
	var valid_environments := ["forest", "desert", "military_base", "village", "industrial"]
	
	for id in range(51):
		var issues: Array[String] = []
		if not missions.has(id):
			issues.append("Missing mission ID %d in database" % id)
			report["mission_details"][str(id)] = {"valid": false, "issues": issues}
			report["issue_count"] += 1
			continue
		
		var m: Dictionary = missions[id]
		var env: String = m.get("environment", "")
		if env not in valid_environments:
			issues.append("Unknown environment '%s'" % env)
		report["environments"][env] = report["environments"].get(env, 0) + 1
		
		var scene_path: String = m.get("scene_path", "")
		if not ResourceLoader.exists(scene_path):
			issues.append("Referenced scene does not exist: '%s'" % scene_path)
		
		var objectives: Array = m.get("objectives", [])
		if objectives.is_empty():
			issues.append("No objectives defined")
		else:
			for obj in objectives:
				var obj_type: String = obj.get("type", "")
				report["objective_types_found"][obj_type] = report["objective_types_found"].get(obj_type, 0) + 1
				if obj_type not in supported_objectives:
					issues.append("Unsupported objective type '%s'" % obj_type)
				if not obj.has("description") or str(obj["description"]).is_empty():
					issues.append("Objective missing description")
		
		var rewards: Dictionary = m.get("rewards", {})
		if not rewards.has("xp") or not rewards.has("currency"):
			issues.append("Incomplete rewards definition")
		
		var next_lvl: int = m.get("next_level", -1)
		if id < 50 and next_lvl != id + 1:
			issues.append("Progression chain broken: expected next_level %d, got %d" % [id + 1, next_lvl])
			report["progression_chain_intact"] = false
		elif id == 50 and next_lvl != -1:
			issues.append("Endgame level 50 should point to next_level -1, got %d" % next_lvl)
		
		var is_valid := issues.is_empty()
		if is_valid:
			report["valid_count"] += 1
		else:
			report["issue_count"] += 1
		
		report["mission_details"][str(id)] = {
			"name": m.get("name", "Unnamed"),
			"environment": env,
			"difficulty": m.get("difficulty", 0.0),
			"enemy_count": m.get("enemy_count", 0),
			"enemy_types": m.get("enemy_types", []),
			"objective_count": objectives.size(),
			"rewards": rewards,
			"next_level": next_lvl,
			"valid": is_valid,
			"issues": issues
		}
	
	# Write machine-readable report to reports directory
	if not DirAccess.dir_exists_absolute("d:/game/reports"):
		DirAccess.make_dir_absolute("d:/game/reports")
	
	var file := FileAccess.open("d:/game/reports/mission_validation_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("Mission validation report saved to d:/game/reports/mission_validation_report.json")
	
	print("Validation Summary: %d / %d missions fully valid. %d issues found." % [report["valid_count"], report["total_missions_evaluated"], report["issue_count"]])
	quit(0 if report["issue_count"] == 0 else 1)
