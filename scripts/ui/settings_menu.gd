extends Control
## Settings menu — controls for audio, graphics, controls, and quality presets.


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 70
	add_child(title)
	
	# Back button
	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.position = Vector2(20, 20)
	back_btn.size = Vector2(120, 40)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	add_child(back_btn)
	
	# Settings container
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 80
	scroll.offset_left = 100
	scroll.offset_right = -100
	add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# Quality preset
	_add_section(vbox, "GRAPHICS")
	_add_option(vbox, "Quality", ["Low", "Medium", "High"], 
		SettingsManager.get_setting("graphics_quality"),
		func(idx: int): SettingsManager.apply_quality_preset(idx))
	
	_add_toggle(vbox, "Shadows", SettingsManager.get_setting("shadows_enabled"),
		func(val: bool): SettingsManager.set_setting("shadows_enabled", val))
	
	_add_toggle(vbox, "Particles", SettingsManager.get_setting("particles_enabled"),
		func(val: bool): SettingsManager.set_setting("particles_enabled", val))
	
	_add_toggle(vbox, "Show FPS", SettingsManager.get_setting("show_fps"),
		func(val: bool): SettingsManager.set_setting("show_fps", val))
	
	# Audio
	_add_section(vbox, "AUDIO")
	_add_slider(vbox, "Music", SettingsManager.get_setting("music_volume"),
		func(val: float): SettingsManager.set_setting("music_volume", val))
	
	_add_slider(vbox, "Sound Effects", SettingsManager.get_setting("sfx_volume"),
		func(val: float): SettingsManager.set_setting("sfx_volume", val))
	
	_add_slider(vbox, "UI Sounds", SettingsManager.get_setting("ui_volume"),
		func(val: float): SettingsManager.set_setting("ui_volume", val))
	
	# Controls
	_add_section(vbox, "CONTROLS")
	_add_slider(vbox, "Camera Sensitivity X", SettingsManager.get_setting("camera_sensitivity_x"),
		func(val: float): SettingsManager.set_setting("camera_sensitivity_x", val))
	
	_add_slider(vbox, "Camera Sensitivity Y", SettingsManager.get_setting("camera_sensitivity_y"),
		func(val: float): SettingsManager.set_setting("camera_sensitivity_y", val))
	
	_add_toggle(vbox, "Invert Y Axis", SettingsManager.get_setting("invert_y"),
		func(val: bool): SettingsManager.set_setting("invert_y", val))
	
	_add_toggle(vbox, "Aim Assist", SettingsManager.get_setting("aim_assist"),
		func(val: bool): SettingsManager.set_setting("aim_assist", val))


func _add_section(parent: VBoxContainer, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.3))
	parent.add_child(lbl)
	
	var sep := HSeparator.new()
	parent.add_child(sep)


func _add_slider(parent: VBoxContainer, label_text: String, value: float, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 30)
	slider.value_changed.connect(callback)
	hbox.add_child(slider)
	
	var val_label := Label.new()
	val_label.text = "%d%%" % int(value * 100)
	val_label.custom_minimum_size = Vector2(50, 0)
	val_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(val_label)
	
	slider.value_changed.connect(func(v: float): val_label.text = "%d%%" % int(v * 100))
	
	parent.add_child(hbox)


func _add_toggle(parent: VBoxContainer, label_text: String, value: bool, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)
	
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(callback)
	hbox.add_child(toggle)
	
	parent.add_child(hbox)


func _add_option(parent: VBoxContainer, label_text: String, options: Array, current: int, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)
	
	var option := OptionButton.new()
	for opt in options:
		option.add_item(opt)
	option.selected = current
	option.item_selected.connect(callback)
	option.custom_minimum_size = Vector2(200, 30)
	hbox.add_child(option)
	
	parent.add_child(hbox)
