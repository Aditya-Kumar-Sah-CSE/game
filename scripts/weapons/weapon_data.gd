extends Resource
class_name WeaponData
## Resource defining weapon properties — data-driven weapon configuration

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_type: WeaponType = WeaponType.HITSCAN

enum WeaponType { HITSCAN, PROJECTILE }

# Damage
@export_group("Damage")
@export var base_damage: float = 25.0
@export var headshot_multiplier: float = 2.0
@export var effective_range: float = 50.0
@export var damage_falloff_start: float = 30.0

# Fire
@export_group("Fire")
@export var fire_rate: float = 10.0  # Rounds per second
@export var auto_fire: bool = true
@export var burst_count: int = 1

# Magazine
@export_group("Magazine")
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 2.0

# Accuracy
@export_group("Accuracy")
@export var base_spread: float = 1.5  # Degrees
@export var aim_spread: float = 0.3
@export var spread_increase_per_shot: float = 0.2
@export var spread_recovery_rate: float = 5.0
@export var max_spread: float = 5.0
@export var recoil_vertical: float = 0.5
@export var recoil_horizontal: float = 0.1

# Projectile (if weapon_type == PROJECTILE)
@export_group("Projectile")
@export var projectile_speed: float = 100.0
@export var bullet_drop: float = 0.0  # Gravity applied to projectile

# Audio
@export_group("Audio")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_click_sound: AudioStream


func get_fire_interval() -> float:
	return 1.0 / fire_rate if fire_rate > 0 else 0.1


func calculate_damage(distance: float, is_headshot: bool) -> float:
	var dmg := base_damage
	
	# Apply distance falloff
	if distance > damage_falloff_start and effective_range > damage_falloff_start:
		var falloff_ratio := clampf(
			(distance - damage_falloff_start) / (effective_range - damage_falloff_start),
			0.0, 1.0
		)
		dmg *= (1.0 - falloff_ratio * 0.5)  # Min 50% damage at max range
	
	# Apply headshot multiplier
	if is_headshot:
		dmg *= headshot_multiplier
	
	return dmg
