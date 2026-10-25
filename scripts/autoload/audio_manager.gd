extends Node
## AudioManager - Handles all game audio (Autoload Singleton)

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 0.7

var _music_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer

# Pool of SFX players for concurrent sounds
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(_music_player)
	
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
	add_child(_ui_player)
	
	# Create SFX player pool
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(player)
		_sfx_pool.append(player)
	
	_apply_volumes()


func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, 0.3)
		await tween.finished
	
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()


func stop_music(fade_out: float = 0.5) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
		await tween.finished
		_music_player.stop()


func play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> void:
	if stream == null:
		return
	
	# Find an available player from the pool
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume * volume_scale)
			player.play()
			return
	
	# All players busy - reuse the oldest
	_sfx_pool[0].stream = stream
	_sfx_pool[0].volume_db = linear_to_db(sfx_volume * volume_scale)
	_sfx_pool[0].play()


func play_ui_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = linear_to_db(ui_volume)
	_ui_player.play()


func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	if _music_player.playing:
		_music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


func set_ui_volume(vol: float) -> void:
	ui_volume = clampf(vol, 0.0, 1.0)


func _apply_volumes() -> void:
	_music_player.volume_db = linear_to_db(music_volume)
	_ui_player.volume_db = linear_to_db(ui_volume)
