extends CanvasLayer
class_name TouchControls
## Mobile touch controls: virtual joystick, fire/aim/reload/jump/crouch buttons.

signal joystick_input(direction: Vector2)
signal camera_drag(delta: Vector2)
signal fire_pressed(pressed: bool)
signal aim_pressed(pressed: bool)
signal reload_pressed()
signal jump_pressed()
signal crouch_pressed()
signal sprint_pressed(pressed: bool)
signal weapon_switch_pressed()
signal pause_pressed()

var _player: PlayerController

# Joystick state
var _joystick_active: bool = false
var _joystick_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 80.0
var _joystick_knob_pos: Vector2 = Vector2.ZERO

# Camera drag state
var _camera_touch_index: int = -1
var _camera_last_pos: Vector2 = Vector2.ZERO

# UI elements
var _joystick_bg: Control
var _joystick_knob: Control
var _fire_btn: Button
var _aim_btn: Button
var _reload_btn: Button
var _jump_btn: Button
var _crouch_btn: Button
var _weapon_btn: Button
var _pause_btn: Button


func _ready() -> void:
	layer = 11
	
	if not GameManager.is_mobile:
		visible = false
		return
	
	_build_controls()


func setup_player(player: PlayerController) -> void:
	_player = player


func _build_controls() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	
	var opacity: float = SettingsManager.get_setting("touch_controls_opacity")
	
	# Left side - Virtual Joystick
	_joystick_bg = _create_circle_control(Vector2(150, 450), 80, Color(1, 1, 1, 0.15))
	root.add_child(_joystick_bg)
	
	_joystick_knob = _create_circle_control(Vector2(150, 450), 30, Color(1, 1, 1, 0.4))
	root.add_child(_joystick_knob)
	
	# Right side - Action buttons
	var btn_size := Vector2(80, 80)
	var right_x := 1100.0
	var bottom_y := 500.0
	
	# Fire button (large, right side)
	_fire_btn = _create_action_button("FIRE", Vector2(right_x + 80, bottom_y - 80), Vector2(100, 100), Color(0.8, 0.2, 0.1, opacity))
	root.add_child(_fire_btn)
	
	# Aim button
	_aim_btn = _create_action_button("AIM", Vector2(right_x - 20, bottom_y - 20), btn_size, Color(0.2, 0.5, 0.8, opacity))
	root.add_child(_aim_btn)
	
	# Reload button
	_reload_btn = _create_action_button("R", Vector2(right_x + 100, bottom_y - 180), Vector2(60, 60), Color(0.6, 0.6, 0.2, opacity))
	root.add_child(_reload_btn)
	
	# Jump button
	_jump_btn = _create_action_button("↑", Vector2(right_x - 20, bottom_y - 160), Vector2(60, 60), Color(0.3, 0.7, 0.3, opacity))
	root.add_child(_jump_btn)
	
	# Crouch button
	_crouch_btn = _create_action_button("↓", Vector2(right_x - 20, bottom_y + 60), Vector2(60, 60), Color(0.5, 0.3, 0.7, opacity))
	root.add_child(_crouch_btn)
	
	# Weapon switch
	_weapon_btn = _create_action_button("⟳", Vector2(20, 300), Vector2(60, 60), Color(0.5, 0.5, 0.5, opacity))
	root.add_child(_weapon_btn)
	
	# Pause button (top right)
	_pause_btn = _create_action_button("⏸", Vector2(1200, 20), Vector2(50, 50), Color(0.5, 0.5, 0.5, opacity))
	root.add_child(_pause_btn)
	
	# Connect buttons
	_fire_btn.button_down.connect(func(): _set_fire(true))
	_fire_btn.button_up.connect(func(): _set_fire(false))
	_aim_btn.button_down.connect(func(): _set_aim(true))
	_aim_btn.button_up.connect(func(): _set_aim(false))
	_reload_btn.pressed.connect(func(): Input.action_press("reload"); Input.action_release("reload"))
	_jump_btn.pressed.connect(func(): Input.action_press("jump"); Input.action_release("jump"))
	_crouch_btn.pressed.connect(func(): Input.action_press("crouch"); Input.action_release("crouch"))
	_weapon_btn.pressed.connect(func(): Input.action_press("weapon_next"); Input.action_release("weapon_next"))
	_pause_btn.pressed.connect(func(): Input.action_press("pause"); Input.action_release("pause"))


func _input(event: InputEvent) -> void:
	if not GameManager.is_mobile or not visible:
		return
	
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	var left_half := screen_width * 0.35
	
	if event.pressed:
		if event.position.x < left_half and _joystick_touch_index == -1:
			# Start joystick
			_joystick_touch_index = event.index
			_joystick_center = event.position
			_joystick_active = true
			_joystick_bg.position = _joystick_center - Vector2(_joystick_radius, _joystick_radius)
			_joystick_knob.position = _joystick_center - Vector2(30, 30)
		elif event.position.x > left_half and _camera_touch_index == -1:
			# Only start camera if not touching a button
			if not _is_over_button(event.position):
				_camera_touch_index = event.index
				_camera_last_pos = event.position
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_joystick_active = false
			_joystick_knob.position = _joystick_bg.position + Vector2(_joystick_radius - 30, _joystick_radius - 30)
			if _player:
				_player.mobile_move_input = Vector2.ZERO
		elif event.index == _camera_touch_index:
			_camera_touch_index = -1
			if _player:
				_player.mobile_camera_input = Vector2.ZERO


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		var offset := event.position - _joystick_center
		var clamped := offset
		if offset.length() > _joystick_radius:
			clamped = offset.normalized() * _joystick_radius
		
		_joystick_knob.position = _joystick_center + clamped - Vector2(30, 30)
		
		var input_vec := clamped / _joystick_radius
		if _player:
			_player.mobile_move_input = Vector2(input_vec.x, input_vec.y)
	
	elif event.index == _camera_touch_index:
		var delta := event.position - _camera_last_pos
		_camera_last_pos = event.position
		if _player:
			_player.mobile_camera_input = delta


func _set_fire(pressed: bool) -> void:
	if _player:
		_player.mobile_fire_pressed = pressed


func _set_aim(pressed: bool) -> void:
	if _player:
		_player.mobile_aim_pressed = pressed


func _is_over_button(pos: Vector2) -> bool:
	for btn in [_fire_btn, _aim_btn, _reload_btn, _jump_btn, _crouch_btn, _weapon_btn, _pause_btn]:
		if btn and Rect2(btn.global_position, btn.size).has_point(pos):
			return true
	return false


func _create_circle_control(pos: Vector2, radius: float, color: Color) -> Control:
	var ctrl := ColorRect.new()
	ctrl.size = Vector2(radius * 2, radius * 2)
	ctrl.position = pos - Vector2(radius, radius)
	ctrl.color = color
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ctrl


func _create_action_button(text: String, pos: Vector2, btn_size: Vector2, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = btn_size
	btn.add_theme_font_size_override("font_size", 16)
	btn.modulate = color + Color(0.3, 0.3, 0.3, 0)
	return btn
