extends Control
## Main Menu controller — handles button presses, continue logic, and scene transitions.


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MAIN_MENU)
	
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/ContinueButton.pressed.connect(_on_continue)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)
	
	# Style the title
	var title: Label = $VBox/Title
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	
	var subtitle: Label = $VBox/Subtitle
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# Style buttons
	for btn_name in ["PlayButton", "ContinueButton", "SettingsButton", "QuitButton"]:
		var btn: Button = $VBox.get_node(btn_name)
		btn.add_theme_font_size_override("font_size", 20)
	
	# Show/hide continue based on save data
	$VBox/ContinueButton.visible = SaveManager.has_save()
	
	# Version label
	$VersionLabel.add_theme_font_size_override("font_size", 14)
	$VersionLabel.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	
	# Hide quit on mobile (Android back button handles it)
	if GameManager.is_mobile:
		$VBox/QuitButton.visible = false


func _on_play() -> void:
	# Start fresh campaign - go to level selection / first level
	get_tree().change_scene_to_file("res://scenes/main/level_select.tscn")


func _on_continue() -> void:
	# Load saved progress and go to level selection
	get_tree().change_scene_to_file("res://scenes/main/level_select.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/main/settings_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
