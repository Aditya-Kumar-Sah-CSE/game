extends Node
class_name WeaponManager
## Manages weapon inventory, switching, firing, and reloading for the player.

signal weapon_fired(weapon_data: WeaponData)
signal weapon_reloaded(weapon_data: WeaponData)
signal weapon_switched(weapon_data: WeaponData)
signal ammo_changed(current_mag: int, reserve: int)

const AudioSynthesizer = preload("res://scripts/utils/audio_synthesizer.gd")

var _player: PlayerController
var _weapons: Array[Dictionary] = []  # [{data: WeaponData, current_mag: int, reserve: int}]
var _current_index: int = 0
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _is_reloading: bool = false
var _current_spread: float = 0.0

# Weapon visual
var _weapon_mesh: Node3D


func setup(player: PlayerController) -> void:
	_player = player
	_create_default_weapons()
	_equip_current()


func _process(delta: float) -> void:
	# Fire cooldown
	if _fire_cooldown > 0:
		_fire_cooldown -= delta
	
	# Reload timer
	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0:
			_finish_reload()
	
	# Spread recovery
	var data := get_current_data()
	if data:
		_current_spread = move_toward(_current_spread, data.base_spread, data.spread_recovery_rate * delta)
	
	# Weapon switching via scroll
	if Input.is_action_just_pressed("weapon_next"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		switch_weapon(-1)


func try_fire() -> void:
	if _is_reloading:
		return
	if _fire_cooldown > 0:
		return
	if _weapons.is_empty():
		return
	
	var wpn := _weapons[_current_index]
	var data: WeaponData = wpn["data"]
	
	# Check ammo
	if wpn["current_mag"] <= 0:
		# Auto-reload if possible
		if wpn["reserve"] > 0:
			try_reload()
		# Play empty click
		if data.empty_click_sound:
			AudioManager.play_sfx(data.empty_click_sound)
		return
	
	# Fire!
	wpn["current_mag"] -= 1
	_fire_cooldown = data.get_fire_interval()
	
	# Apply spread increase
	_current_spread = minf(_current_spread + data.spread_increase_per_shot, data.max_spread)
	
	# Perform hitscan or spawn projectile
	var spread := data.aim_spread if _player.is_aiming else _current_spread
	_do_hitscan(data, spread)
	
	# Play fire sound
	if data.fire_sound:
		AudioManager.play_sfx(data.fire_sound)
	
	# Muzzle flash
	_spawn_muzzle_flash()
	
	# Record stat
	GameManager.record_shot_fired()
	
	ammo_changed.emit(wpn["current_mag"], wpn["reserve"])
	weapon_fired.emit(data)


func try_reload() -> void:
	if _is_reloading:
		return
	if _weapons.is_empty():
		return
	
	var wpn := _weapons[_current_index]
	var data: WeaponData = wpn["data"]
	
	if wpn["current_mag"] >= data.magazine_size:
		return  # Already full
	if wpn["reserve"] <= 0:
		return  # No reserve ammo
	
	_is_reloading = true
	_reload_timer = data.reload_time
	
	if data.reload_sound:
		AudioManager.play_sfx(data.reload_sound)


func _finish_reload() -> void:
	_is_reloading = false
	
	var wpn := _weapons[_current_index]
	var data: WeaponData = wpn["data"]
	
	var needed: int = data.magazine_size - int(wpn["current_mag"])
	var available: int = mini(needed, int(wpn["reserve"]))
	
	wpn["current_mag"] += available
	wpn["reserve"] -= available
	
	ammo_changed.emit(wpn["current_mag"], wpn["reserve"])
	weapon_reloaded.emit(data)


func switch_weapon(direction: int) -> void:
	if _weapons.size() <= 1:
		return
	if _is_reloading:
		_is_reloading = false  # Cancel reload on switch
	
	_current_index = wrapi(_current_index + direction, 0, _weapons.size())
	_equip_current()


func get_current_data() -> WeaponData:
	if _weapons.is_empty():
		return null
	return _weapons[_current_index]["data"]


func get_current_ammo() -> Dictionary:
	if _weapons.is_empty():
		return {"current": 0, "reserve": 0}
	return {
		"current": _weapons[_current_index]["current_mag"],
		"reserve": _weapons[_current_index]["reserve"]
	}


func add_weapon(data: WeaponData) -> void:
	# Check if already have this weapon (add ammo instead)
	for wpn in _weapons:
		if wpn["data"].weapon_id == data.weapon_id:
			wpn["reserve"] += data.reserve_ammo
			return
	
	_weapons.append({
		"data": data,
		"current_mag": data.magazine_size,
		"reserve": data.reserve_ammo
	})


func add_ammo(weapon_id: String, amount: int) -> void:
	for wpn in _weapons:
		if wpn["data"].weapon_id == weapon_id:
			wpn["reserve"] += amount
			if _weapons[_current_index]["data"].weapon_id == weapon_id:
				ammo_changed.emit(wpn["current_mag"], wpn["reserve"])
			return


func _do_hitscan(data: WeaponData, spread_degrees: float) -> void:
	if not _player or not _player.camera:
		return
	
	var origin := _player.get_aim_origin()
	var forward := _player.get_aim_direction()
	
	# Apply spread
	if spread_degrees > 0:
		var spread_rad := deg_to_rad(spread_degrees)
		var random_spread := Vector2(
			randf_range(-spread_rad, spread_rad),
			randf_range(-spread_rad, spread_rad)
		)
		forward = forward.rotated(_player.camera.global_transform.basis.x, random_spread.y)
		forward = forward.rotated(Vector3.UP, random_spread.x)
	
	var end := origin + forward * data.effective_range
	
	# Raycast
	var space_state := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 | 4  # Environment + Enemy
	query.exclude = [_player.get_rid()]
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]
		var hit_collider: Object = result["collider"]
		var distance := origin.distance_to(hit_pos)
		
		# Spawn impact effect
		_spawn_impact(hit_pos, hit_normal)
		
		# Check if we hit an enemy
		if hit_collider.is_in_group("enemy"):
			var is_headshot := false
			# Simple headshot detection: hit above 80% of enemy height
			if hit_collider is CharacterBody3D:
				var enemy_height := 1.8
				var local_hit_y: float = hit_pos.y - (hit_collider as Node3D).global_position.y
				is_headshot = local_hit_y > enemy_height * 0.8
			
			var damage := data.calculate_damage(distance, is_headshot)
			
			if hit_collider.has_method("take_damage"):
				hit_collider.take_damage(damage, _player.global_position)
			
			GameManager.record_shot_hit(is_headshot)


const WEAPON_MODELS: Dictionary = {
	"assault_rifle": "res://assets/models/weapons/AssaultRifle.glb",
	"pistol": "res://assets/models/weapons/Pistol.glb",
	"shotgun": "res://assets/models/weapons/Shotgun.glb",
	"sniper": "res://assets/models/weapons/Sniper.glb"
}


func _spawn_muzzle_flash() -> void:
	if not _player or not _player.weapon_holder:
		return
	
	var flash := Node3D.new()
	flash.name = "MuzzleFlash"
	
	# Cross-quad flash geometry
	for rot in [0.0, 90.0]:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.22, 0.22)
		quad.mesh = qm
		quad.rotation_degrees.z = rot
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.3)
		mat.emission_energy_multiplier = 6.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material_override = mat
		flash.add_child(quad)
	
	# Dynamic OmniLight pulse
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 3.5
	light.omni_range = 8.0
	light.shadow_enabled = false
	flash.add_child(light)
	
	flash.position = Vector3(0, 0, -0.65)
	_player.weapon_holder.add_child(flash)
	
	# Fade and remove
	if _player.is_inside_tree():
		var tween := _player.create_tween()
		tween.set_parallel(true)
		tween.tween_property(light, "light_energy", 0.0, 0.06)
		tween.tween_property(flash, "scale", Vector3.ZERO, 0.06)
		tween.chain().tween_callback(flash.queue_free)
	else:
		flash.queue_free()


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if not _player or not _player.is_inside_tree():
		return
	
	var impact_root := Node3D.new()
	impact_root.global_position = pos
	_player.get_tree().current_scene.add_child(impact_root)
	
	# Spark burst along normal
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	spark.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.15)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	impact_root.add_child(spark)
	
	# Scorch ring decal
	var decal := MeshInstance3D.new()
	var dm := QuadMesh.new()
	dm.size = Vector2(0.2, 0.2)
	decal.mesh = dm
	
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	decal.material_override = dmat
	
	if normal.length_squared() > 0.01:
		if absf(normal.dot(Vector3.UP)) < 0.99:
			decal.look_at(pos + normal, Vector3.UP)
		else:
			decal.look_at(pos + normal, Vector3.RIGHT)
	decal.position += normal * 0.01
	impact_root.add_child(decal)
	
	var tween := impact_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_property(dmat, "albedo_color:a", 0.0, 0.8)
	tween.chain().tween_callback(impact_root.queue_free)


func _create_default_weapons() -> void:
	# Assault Rifle
	var ar := WeaponData.new()
	ar.weapon_id = "assault_rifle"
	ar.weapon_name = "AR-7 Vanguard"
	ar.base_damage = 25.0
	ar.headshot_multiplier = 2.0
	ar.fire_rate = 10.0
	ar.auto_fire = true
	ar.magazine_size = 30
	ar.reserve_ammo = 120
	ar.reload_time = 2.0
	ar.base_spread = 1.5
	ar.aim_spread = 0.3
	ar.spread_increase_per_shot = 0.2
	ar.spread_recovery_rate = 5.0
	ar.max_spread = 5.0
	ar.effective_range = 50.0
	ar.damage_falloff_start = 30.0
	ar.fire_sound = AudioSynthesizer.create_gunshot()
	ar.reload_sound = AudioSynthesizer.create_reload_click()
	ar.empty_click_sound = AudioSynthesizer.create_reload_click()
	add_weapon(ar)
	
	# Pistol
	var pistol := WeaponData.new()
	pistol.weapon_id = "pistol"
	pistol.weapon_name = "P9 Shadow"
	pistol.base_damage = 30.0
	pistol.headshot_multiplier = 2.5
	pistol.fire_rate = 4.0
	pistol.auto_fire = false
	pistol.magazine_size = 12
	pistol.reserve_ammo = 48
	pistol.reload_time = 1.5
	pistol.base_spread = 1.0
	pistol.aim_spread = 0.2
	pistol.spread_increase_per_shot = 0.5
	pistol.spread_recovery_rate = 8.0
	pistol.max_spread = 4.0
	pistol.effective_range = 30.0
	pistol.damage_falloff_start = 15.0
	pistol.fire_sound = AudioSynthesizer.create_gunshot(22050, 0.18)
	pistol.reload_sound = AudioSynthesizer.create_reload_click()
	pistol.empty_click_sound = AudioSynthesizer.create_reload_click()
	add_weapon(pistol)


func _equip_current() -> void:
	# Clear old weapon visual
	if _weapon_mesh and is_instance_valid(_weapon_mesh):
		_weapon_mesh.queue_free()
		_weapon_mesh = null
	
	var data := get_current_data()
	if data == null:
		return
	
	var model_path: String = WEAPON_MODELS.get(data.weapon_id, "")
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var inst: Node3D = scene.instantiate()
			_weapon_mesh = inst
			match data.weapon_id:
				"assault_rifle":
					inst.scale = Vector3(0.45, 0.45, 0.45)
					inst.rotation_degrees = Vector3(0, 90, 0)
					inst.position = Vector3(0, -0.04, -0.12)
				"pistol":
					inst.scale = Vector3(0.25, 0.25, 0.25)
					inst.rotation_degrees = Vector3(0, 90, 0)
					inst.position = Vector3(0, -0.02, -0.05)
				"shotgun":
					inst.scale = Vector3(0.18, 0.18, 0.18)
					inst.rotation_degrees = Vector3(0, 90, 0)
					inst.position = Vector3(0, -0.04, -0.12)
				"sniper":
					inst.scale = Vector3(0.5, 0.5, 0.5)
					inst.rotation_degrees = Vector3(0, 90, 0)
					inst.position = Vector3(0, -0.04, -0.18)
				_:
					inst.scale = Vector3(0.4, 0.4, 0.4)
					inst.rotation_degrees = Vector3(0, 90, 0)
	
	# Procedural fallback
	if _weapon_mesh == null:
		var mesh_inst := MeshInstance3D.new()
		var wpn_mesh := BoxMesh.new()
		match data.weapon_id:
			"assault_rifle":
				wpn_mesh.size = Vector3(0.06, 0.08, 0.7)
			"pistol":
				wpn_mesh.size = Vector3(0.04, 0.1, 0.25)
			"shotgun":
				wpn_mesh.size = Vector3(0.06, 0.08, 0.8)
			"sniper":
				wpn_mesh.size = Vector3(0.05, 0.07, 1.0)
			_:
				wpn_mesh.size = Vector3(0.06, 0.08, 0.5)
		mesh_inst.mesh = wpn_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.15, 0.15)
		mat.metallic = 0.8
		mat.roughness = 0.3
		mesh_inst.material_override = mat
		_weapon_mesh = mesh_inst
	
	if _player and _player.weapon_holder:
		_player.weapon_holder.add_child(_weapon_mesh)
	
	var ammo := get_current_ammo()
	ammo_changed.emit(ammo["current"], ammo["reserve"])
	weapon_switched.emit(data)
