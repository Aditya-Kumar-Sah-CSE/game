extends Control
## Level Selection screen — shows campaign map with unlocked/completed/locked levels.


var _level_buttons: Array[Button] = []


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Header
	var header := Label.new()
	header.text = "CAMPAIGN"
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 20
	header.offset_bottom = 70
	add_child(header)
	
	# Back button
	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.position = Vector2(20, 20)
	back_btn.size = Vector2(120, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	add_child(back_btn)
	
	# Stats bar
	var stats := Label.new()
	stats.text = "XP: %d | Currency: %d | Completed: %d/%d" % [
		GameManager.campaign_data["xp"],
		GameManager.campaign_data["currency"],
		GameManager.campaign_data["completed_levels"].size(),
		MissionDatabase.get_mission_count()
	]
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stats.offset_top = 60
	stats.offset_bottom = 85
	add_child(stats)
	
	# Scroll container for levels
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 100
	scroll.offset_bottom = -20
	scroll.offset_left = 20
	scroll.offset_right = -20
	add_child(scroll)
	
	# Grid of level buttons
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	# Create level buttons (show first 51 levels: 0-50)
	for i in range(51):
		var mission := MissionDatabase.get_mission(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 80)
		
		var is_unlocked := GameManager.is_level_unlocked(i)
		var is_completed := GameManager.is_level_completed(i)
		
		if is_completed:
			btn.text = "✓ Level %d\n%s" % [i, mission.get("name", "")]
			btn.modulate = Color(0.5, 1.0, 0.5)
		elif is_unlocked:
			btn.text = "► Level %d\n%s" % [i, mission.get("name", "")]
			btn.modulate = Color(1.0, 0.9, 0.6)
		else:
			btn.text = "🔒 Level %d\nLocked" % i
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true
		
		btn.add_theme_font_size_override("font_size", 14)
		
		var level_id := i  # Capture for lambda
		btn.pressed.connect(func(): _start_level(level_id))
		
		grid.add_child(btn)
		_level_buttons.append(btn)


func _start_level(level_id: int) -> void:
	if not GameManager.is_level_unlocked(level_id):
		return
	GameManager.start_mission(level_id)
