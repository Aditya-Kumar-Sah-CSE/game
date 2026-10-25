extends CanvasLayer
class_name MissionResultScreen
## Mission complete/failed overlay with stats and navigation.

var _is_success: bool = false
var _panel: PanelContainer


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_build_screen()
	
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.mission_completed.connect(_on_mission_completed)
	GameManager.mission_failed.connect(_on_mission_failed)


func _build_screen() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	add_child(dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(_panel)


func _show_results(is_success: bool, stats: Dictionary = {}, reason: String = "") -> void:
	_is_success = is_success
	
	# Clear old content
	for child in _panel.get_children():
		child.queue_free()
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "MISSION COMPLETE" if is_success else "MISSION FAILED"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 1, 0.3) if is_success else Color(1, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	if not is_success and reason:
		var reason_lbl := Label.new()
		reason_lbl.text = reason
		reason_lbl.add_theme_font_size_override("font_size", 16)
		reason_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		reason_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(reason_lbl)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Stats
	var stats_to_show := {
		"Enemies Eliminated": stats.get("enemies_killed", 0),
		"Shots Fired": stats.get("shots_fired", 0),
		"Shots Hit": stats.get("shots_hit", 0),
		"Headshots": stats.get("headshots", 0),
		"Time": "%.1f s" % stats.get("time_elapsed", 0),
	}
	
	if stats.get("shots_fired", 0) > 0:
		var accuracy := float(stats.get("shots_hit", 0)) / float(stats.get("shots_fired", 1)) * 100
		stats_to_show["Accuracy"] = "%.1f%%" % accuracy
	
	for key in stats_to_show:
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 20)
		
		var key_lbl := Label.new()
		key_lbl.text = key
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.custom_minimum_size = Vector2(200, 0)
		stat_row.add_child(key_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = str(stats_to_show[key])
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		stat_row.add_child(val_lbl)
		
		vbox.add_child(stat_row)
	
	# Rewards (success only)
	if is_success:
		var mission_data := MissionDatabase.get_mission(GameManager.current_mission_id)
		var rewards: Dictionary = mission_data.get("rewards", {})
		var rewards_lbl := Label.new()
		rewards_lbl.text = "Rewards: +%d XP  +%d Credits" % [rewards.get("xp", 0), rewards.get("currency", 0)]
		rewards_lbl.add_theme_font_size_override("font_size", 18)
		rewards_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		rewards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rewards_lbl)
	
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 20)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)
	
	if is_success:
		var next_btn := Button.new()
		next_btn.text = "NEXT MISSION"
		next_btn.custom_minimum_size = Vector2(180, 50)
		next_btn.pressed.connect(func():
			var next_id := GameManager.current_mission_id + 1
			if GameManager.is_level_unlocked(next_id):
				GameManager.start_mission(next_id)
			else:
				GameManager.return_to_menu()
		)
		btn_container.add_child(next_btn)
	else:
		var retry_btn := Button.new()
		retry_btn.text = "RETRY"
		retry_btn.custom_minimum_size = Vector2(180, 50)
		retry_btn.pressed.connect(func(): GameManager.restart_mission())
		btn_container.add_child(retry_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(180, 50)
	menu_btn.pressed.connect(func(): GameManager.return_to_menu())
	btn_container.add_child(menu_btn)


func _on_mission_completed(mission_id: int, stats: Dictionary) -> void:
	_show_results(true, stats)


func _on_mission_failed(mission_id: int, reason: String) -> void:
	_show_results(false, GameManager.mission_stats, reason)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = (new_state in [GameManager.GameState.MISSION_COMPLETE, GameManager.GameState.MISSION_FAILED])
