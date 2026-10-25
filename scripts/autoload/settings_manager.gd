extends Node
## SettingsManager - Game settings management (Autoload Singleton)

signal settings_changed()

var _settings: Dictionary = {
	"graphics_quality": 1,  # 0=Low, 1=Medium, 2=High
	"render_scale": 1.0,
	"shadows_enabled": true,
	"particles_enabled": true,
	"vsync": true,
	"fps_limit": 60,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"ui_volume": 0.7,
	"camera_sensitivity_x": 0.3,
	"camera_sensitivity_y": 0.2,
	"invert_y": false,
	"aim_assist": true,
	"vibration": true,
	"show_fps": false,
	"touch_controls_opacity": 0.6,
	"touch_controls_scale": 1.0
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_settings()


func get_setting(key: String) -> Variant:
	return _settings.get(key, null)


func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_apply_setting(key, value)
	_save_settings()
	settings_changed.emit()


func get_all_settings() -> Dictionary:
	return _settings.duplicate()


func apply_quality_preset(level: int) -> void:
	match level:
		0:  # Low
			set_setting("graphics_quality", 0)
			set_setting("render_scale", 0.75)
			set_setting("shadows_enabled", false)
			set_setting("particles_enabled", false)
			set_setting("fps_limit", 30)
		1:  # Medium
			set_setting("graphics_quality", 1)
			set_setting("render_scale", 1.0)
			set_setting("shadows_enabled", true)
			set_setting("particles_enabled", true)
			set_setting("fps_limit", 30)
		2:  # High
			set_setting("graphics_quality", 2)
			set_setting("render_scale", 1.0)
			set_setting("shadows_enabled", true)
			set_setting("particles_enabled", true)
			set_setting("fps_limit", 60)


func _apply_settings() -> void:
	for key in _settings:
		_apply_setting(key, _settings[key])


func _apply_setting(key: String, value: Variant) -> void:
	match key:
		"music_volume":
			AudioManager.set_music_volume(value)
		"sfx_volume":
			AudioManager.set_sfx_volume(value)
		"ui_volume":
			AudioManager.set_ui_volume(value)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
		"fps_limit":
			Engine.max_fps = value
		"render_scale":
			get_viewport().scaling_3d_scale = value
		"show_fps":
			pass  # Handled by HUD


func _save_settings() -> void:
	var config := ConfigFile.new()
	for key in _settings:
		config.set_value("settings", key, _settings[key])
	config.save("user://settings.cfg")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	
	for key in _settings:
		if config.has_section_key("settings", key):
			_settings[key] = config.get_value("settings", key)
