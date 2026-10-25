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


var _hp_val_label: Label
var _armor_val_label: Label
var _crosshair_container: Control
var _reticle_ticks: Array[ColorRect] = []


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
	_mission_name_label.text = "OPERATION: %s" % name_text.to_upper()


func show_hit_indicator() -> void:
	_damage_overlay.modulate = Color(1, 0.1, 0.1, 0.45)
	var tween := create_tween()
	tween.tween_property(_damage_overlay, "modulate:a", 0.0, 0.35)


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# Damage overlay (vignette border flash)
	_damage_overlay = ColorRect.new()
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_overlay)
	
	# Health and Armor Card (bottom left)
	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left = 24
	status_panel.offset_bottom = -24
	status_panel.offset_top = -110
	status_panel.offset_right = 260
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.1, 0.75)
	panel_style.border_color = Color(0.2, 0.6, 0.4, 0.35)
	panel_style.border_width_left = 2
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(status_panel)
	
	var health_container := VBoxContainer.new()
	health_container.add_theme_constant_override("separation", 3)
	health_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(health_container)
	
	# Health Row
	var hp_row := HBoxContainer.new()
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_container.add_child(hp_row)
	
	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	hp_row.add_child(hp_label)
	
	_hp_val_label = Label.new()
	_hp_val_label.text = "100 / 100"
	_hp_val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_val_label.add_theme_font_size_override("font_size", 10)
	_hp_val_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	hp_row.add_child(_hp_val_label)
	
	_health_bar = ProgressBar.new()
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.custom_minimum_size = Vector2(210, 14)
	_health_bar.show_percentage = false
	
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.16, 0.14, 0.9)
	hp_bg.corner_radius_top_left = 3
	hp_bg.corner_radius_top_right = 3
	hp_bg.corner_radius_bottom_right = 3
	hp_bg.corner_radius_bottom_left = 3
	_health_bar.add_theme_stylebox_override("background", hp_bg)
	
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.25, 0.85, 0.38)
	hp_fill.corner_radius_top_left = 3
	hp_fill.corner_radius_top_right = 3
	hp_fill.corner_radius_bottom_right = 3
	hp_fill.corner_radius_bottom_left = 3
	_health_bar.add_theme_stylebox_override("fill", hp_fill)
	health_container.add_child(_health_bar)
	
	# Armor Row
	var armor_row := HBoxContainer.new()
	armor_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_container.add_child(armor_row)
	
	var armor_label := Label.new()
	armor_label.text = "ARMOR"
	armor_label.add_theme_font_size_override("font_size", 11)
	armor_label.add_theme_color_override("font_color", Color(0.25, 0.75, 0.95))
	armor_row.add_child(armor_label)
	
	_armor_val_label = Label.new()
	_armor_val_label.text = "50 / 50"
	_armor_val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armor_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_armor_val_label.add_theme_font_size_override("font_size", 10)
	_armor_val_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	armor_row.add_child(_armor_val_label)
	
	_armor_bar = ProgressBar.new()
	_armor_bar.max_value = 50
	_armor_bar.value = 50
	_armor_bar.custom_minimum_size = Vector2(210, 10)
	_armor_bar.show_percentage = false
	
	var armor_bg := StyleBoxFlat.new()
	armor_bg.bg_color = Color(0.1, 0.14, 0.18, 0.9)
	armor_bg.corner_radius_top_left = 2
	armor_bg.corner_radius_top_right = 2
	armor_bg.corner_radius_bottom_right = 2
	armor_bg.corner_radius_bottom_left = 2
	_armor_bar.add_theme_stylebox_override("background", armor_bg)
	
	var armor_fill := StyleBoxFlat.new()
	armor_fill.bg_color = Color(0.2, 0.7, 0.95)
	armor_fill.corner_radius_top_left = 2
	armor_fill.corner_radius_top_right = 2
	armor_fill.corner_radius_bottom_right = 2
	armor_fill.corner_radius_bottom_left = 2
	_armor_bar.add_theme_stylebox_override("fill", armor_fill)
	health_container.add_child(_armor_bar)
	
	# Weapon Card (bottom right)
	var weapon_panel := PanelContainer.new()
	weapon_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_panel.offset_right = -24
	weapon_panel.offset_left = -230
	weapon_panel.offset_bottom = -24
	weapon_panel.offset_top = -100
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var wpn_style := StyleBoxFlat.new()
	wpn_style.bg_color = Color(0.06, 0.08, 0.1, 0.75)
	wpn_style.border_color = Color(0.9, 0.75, 0.3, 0.4)
	wpn_style.border_width_right = 2
	wpn_style.border_width_bottom = 1
	wpn_style.corner_radius_top_left = 6
	wpn_style.corner_radius_top_right = 6
	wpn_style.corner_radius_bottom_right = 6
	wpn_style.corner_radius_bottom_left = 6
	wpn_style.content_margin_left = 12
	wpn_style.content_margin_top = 8
	wpn_style.content_margin_right = 12
	wpn_style.content_margin_bottom = 8
	weapon_panel.add_theme_stylebox_override("panel", wpn_style)
	root.add_child(weapon_panel)
	
	var ammo_container := VBoxContainer.new()
	ammo_container.add_theme_constant_override("separation", 2)
	ammo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_panel.add_child(ammo_container)
	
	_weapon_label = Label.new()
	_weapon_label.text = "AR-7 VANGUARD"
	_weapon_label.add_theme_font_size_override("font_size", 13)
	_weapon_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_container.add_child(_weapon_label)
	
	_ammo_label = Label.new()
	_ammo_label.text = "30 / 120"
	_ammo_label.add_theme_font_size_override("font_size", 28)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_container.add_child(_ammo_label)
	
	# Tactical Crosshair (center)
	_crosshair_container = Control.new()
	_crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair_container.offset_left = 0
	_crosshair_container.offset_top = 0
	_crosshair_container.offset_right = 0
	_crosshair_container.offset_bottom = 0
	_crosshair_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair_container)
	
	# Center dot
	var dot := ColorRect.new()
	dot.size = Vector2(2, 2)
	dot.position = Vector2(-1, -1)
	dot.color = Color(1.0, 1.0, 1.0, 0.9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_container.add_child(dot)
	
	# 4 Crosshair Ticks (Top, Bottom, Left, Right)
	var tick_positions := [
		Vector2(-1, -14),  # Top
		Vector2(-1, 6),    # Bottom
		Vector2(-14, -1),  # Left
		Vector2(6, -1)     # Right
	]
	var tick_sizes := [
		Vector2(2, 8),
		Vector2(2, 8),
		Vector2(8, 2),
		Vector2(8, 2)
	]
	for i in 4:
		var tick := ColorRect.new()
		tick.size = tick_sizes[i]
		tick.position = tick_positions[i]
		tick.color = Color(1.0, 1.0, 1.0, 0.8)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crosshair_container.add_child(tick)
		_reticle_ticks.append(tick)
	
	# Objectives Card (top right)
	var obj_panel := PanelContainer.new()
	obj_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	obj_panel.offset_right = -24
	obj_panel.offset_left = -340
	obj_panel.offset_top = 70
	obj_panel.offset_bottom = 180
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0.06, 0.08, 0.1, 0.75)
	obj_style.border_color = Color(0.3, 0.5, 0.7, 0.3)
	obj_style.border_width_left = 3
	obj_style.corner_radius_top_left = 6
	obj_style.corner_radius_top_right = 6
	obj_style.corner_radius_bottom_right = 6
	obj_style.corner_radius_bottom_left = 6
	obj_style.content_margin_left = 12
	obj_style.content_margin_top = 8
	obj_style.content_margin_right = 12
	obj_style.content_margin_bottom = 8
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	root.add_child(obj_panel)
	
	_objective_container = VBoxContainer.new()
	_objective_container.add_theme_constant_override("separation", 6)
	_objective_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_panel.add_child(_objective_container)
	
	# Mission Name Banner (top center)
	var mission_panel := PanelContainer.new()
	mission_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mission_panel.offset_left = 380
	mission_panel.offset_right = -380
	mission_panel.offset_top = 16
	mission_panel.offset_bottom = 48
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.06, 0.08, 0.1, 0.7)
	banner_style.border_color = Color(0.9, 0.75, 0.25, 0.5)
	banner_style.border_width_bottom = 2
	banner_style.corner_radius_bottom_left = 6
	banner_style.corner_radius_bottom_right = 6
	mission_panel.add_theme_stylebox_override("panel", banner_style)
	root.add_child(mission_panel)
	
	_mission_name_label = Label.new()
	_mission_name_label.text = ""
	_mission_name_label.add_theme_font_size_override("font_size", 14)
	_mission_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_mission_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mission_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(_mission_name_label)
	
	# FPS counter (top left)
	_fps_label = Label.new()
	_fps_label.text = "FPS: 60"
	_fps_label.add_theme_font_size_override("font_size", 12)
	_fps_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_fps_label.position = Vector2(24, 16)
	_fps_label.visible = false
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fps_label)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	if _hp_val_label:
		_hp_val_label.text = "%d / %d" % [maxi(0, int(current)), int(maximum)]
	if current < maximum:
		show_hit_indicator()


func _on_armor_changed(current: float, maximum: float) -> void:
	_armor_bar.max_value = maximum
	_armor_bar.value = current
	if _armor_val_label:
		_armor_val_label.text = "%d / %d" % [maxi(0, int(current)), int(maximum)]


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current_mag, reserve]
	if current_mag <= 5:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	else:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))


func _on_weapon_switched(weapon_data: WeaponData) -> void:
	_weapon_label.text = weapon_data.weapon_name.to_upper()


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
