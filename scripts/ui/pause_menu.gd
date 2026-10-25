extends CanvasLayer
class_name PauseMenu
## Pause menu overlay with resume, restart, settings, and quit options.


var _panel: PanelContainer


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_build_menu()
	
	GameManager.state_changed.connect(_on_state_changed)


func _build_menu() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	
	# Center panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 350)
	center.add_child(_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Buttons
	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(250, 50)
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)
	
	var restart_btn := Button.new()
	restart_btn.text = "RESTART MISSION"
	restart_btn.custom_minimum_size = Vector2(250, 50)
	restart_btn.pressed.connect(_on_restart)
	vbox.add_child(restart_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(250, 50)
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUIT GAME"
	quit_btn.custom_minimum_size = Vector2(250, 50)
	quit_btn.pressed.connect(func(): get_tree().quit())
	if GameManager.is_mobile:
		quit_btn.visible = false
	vbox.add_child(quit_btn)


func _on_resume() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)


func _on_restart() -> void:
	GameManager.restart_mission()


func _on_main_menu() -> void:
	GameManager.return_to_menu()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = (new_state == GameManager.GameState.PAUSED)
