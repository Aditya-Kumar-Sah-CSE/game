extends CanvasLayer
class_name GameHUD
## Gameplay HUD displaying health, armor, ammo, objectives, crosshair, and mission info.

var _health_bar: ProgressBar
var _armor_bar: ProgressBar
var _ammo_label: Label
var _weapon_label: Label
var _objective_container: VBoxContainer
var _crosshair: TextureRect
var _mission_name_label: Label
var _fps_label: Label
var _hit_indicator: ColorRect
var _damage_overlay: ColorRect


func _ready() -> void:
	layer = 10
	_build_hud()
	
	GameManager.state_changed.connect(_on_state_changed)


func _process(_delta: float) -> void:
	if SettingsManager.get_setting("show_fps"):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		_fps_label.visible = true
	else:
		_fps_label.visible = false


func setup_player(player: PlayerController) -> void:
	player.health_changed.connect(_on_health_changed)
	player.armor_changed.connect(_on_armor_changed)
	
	var wpn_mgr: Node = player.get_node_or_null("WeaponManager")
	if wpn_mgr:
		wpn_mgr.ammo_changed.connect(_on_ammo_changed)
		wpn_mgr.weapon_switched.connect(_on_weapon_switched)


func setup_mission(mission_mgr: MissionManager) -> void:
	mission_mgr.objective_updated.connect(_on_objective_updated)
	mission_mgr.objective_completed.connect(_on_objective_completed)


func update_mission_name(name_text: String) -> void:
	_mission_name_label.text = name_text


func show_hit_indicator() -> void:
	_damage_overlay.modulate = Color(1, 0, 0, 0.3)
	var tween := create_tween()
	tween.tween_property(_damage_overlay, "modulate:a", 0.0, 0.4)


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# Damage overlay
	_damage_overlay = ColorRect.new()
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.color = Color(1, 0, 0, 0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_overlay)
	
	# Health bar (bottom left)
	var health_container := VBoxContainer.new()
	health_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_container.offset_left = 20
	health_container.offset_bottom = -20
	health_container.offset_top = -80
	health_container.offset_right = 220
	health_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(health_container)
	
	var hp_label := Label.new()
	hp_label.text = "HEALTH"
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	health_container.add_child(hp_label)
	
	_health_bar = ProgressBar.new()
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.custom_minimum_size = Vector2(200, 16)
	_health_bar.show_percentage = false
	health_container.add_child(_health_bar)
	
	var armor_label := Label.new()
	armor_label.text = "ARMOR"
	armor_label.add_theme_font_size_override("font_size", 12)
	armor_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	health_container.add_child(armor_label)
	
	_armor_bar = ProgressBar.new()
	_armor_bar.max_value = 50
	_armor_bar.value = 50
	_armor_bar.custom_minimum_size = Vector2(200, 12)
	_armor_bar.show_percentage = false
	health_container.add_child(_armor_bar)
	
	# Ammo display (bottom right)
	var ammo_container := VBoxContainer.new()
	ammo_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_container.offset_right = -20
	ammo_container.offset_left = -200
	ammo_container.offset_bottom = -20
	ammo_container.offset_top = -70
	ammo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ammo_container)
	
	_weapon_label = Label.new()
	_weapon_label.text = "AR-7 Vanguard"
	_weapon_label.add_theme_font_size_override("font_size", 14)
	_weapon_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_container.add_child(_weapon_label)
	
	_ammo_label = Label.new()
	_ammo_label.text = "30 / 120"
	_ammo_label.add_theme_font_size_override("font_size", 28)
	_ammo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_container.add_child(_ammo_label)
	
	# Crosshair (center)
	var crosshair_container := CenterContainer.new()
	crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_container.offset_left = -20
	crosshair_container.offset_top = -20
	crosshair_container.offset_right = 20
	crosshair_container.offset_bottom = 20
	crosshair_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair_container)
	
	# Simple crosshair using labels
	var ch := Label.new()
	ch.text = "+"
	ch.add_theme_font_size_override("font_size", 24)
	ch.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair_container.add_child(ch)
	
	# Objectives (top right)
	_objective_container = VBoxContainer.new()
	_objective_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_container.offset_right = -20
	_objective_container.offset_left = -350
	_objective_container.offset_top = 80
	_objective_container.add_theme_constant_override("separation", 5)
	_objective_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_objective_container)
	
	# Mission name (top center)
	_mission_name_label = Label.new()
	_mission_name_label.text = ""
	_mission_name_label.add_theme_font_size_override("font_size", 18)
	_mission_name_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	_mission_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_mission_name_label.offset_top = 15
	_mission_name_label.offset_bottom = 45
	_mission_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mission_name_label)
	
	# FPS counter (top left)
	_fps_label = Label.new()
	_fps_label.text = "FPS: 0"
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	_fps_label.position = Vector2(20, 15)
	_fps_label.visible = false
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fps_label)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	if current < maximum:
		show_hit_indicator()


func _on_armor_changed(current: float, maximum: float) -> void:
	_armor_bar.max_value = maximum
	_armor_bar.value = current


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current_mag, reserve]
	if current_mag <= 5:
		_ammo_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func _on_weapon_switched(weapon_data: WeaponData) -> void:
	_weapon_label.text = weapon_data.weapon_name


func _on_objective_updated(index: int, progress: int, target: int, description: String) -> void:
	_ensure_objective_label(index)
	var lbl: Label = _objective_container.get_child(index)
	var check := "✓ " if progress >= target else "○ "
	lbl.text = "%s%s (%d/%d)" % [check, description, progress, target]
	if progress >= target:
		lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func _on_objective_completed(index: int, description: String) -> void:
	_ensure_objective_label(index)
	var lbl: Label = _objective_container.get_child(index)
	lbl.text = "✓ %s" % description
	lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5))


func _ensure_objective_label(index: int) -> void:
	while _objective_container.get_child_count() <= index:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_objective_container.add_child(lbl)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = (new_state == GameManager.GameState.PLAYING)
