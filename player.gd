# player.gd
extends CharacterBody3D

@export var move_speed := 4.5
@export var sprint_multiplier := 1.6
@export var acceleration := 12.0
@export var friction := 10.0
@export var jump_velocity := 8.0
@export var gravity := 18.0

# --- Shooting / Auto-fire ---
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.25          # seconds between shots
@export var max_target_distance: float = 80.0      # only shoot if enemy is within this range
@export var muzzle_offset: Vector3 = Vector3(0, 1.2, 0)  # spawn a bit above player origin

var _shoot_timer: float = 0.0

var input_dir := Vector3.ZERO
var velocity_h := Vector3.ZERO

func _ready() -> void:
	floor_snap_length = 0.3
	up_direction = Vector3.UP
	add_to_group("player")  # so enemies & spawner can find you

func _get_input_dir() -> Vector3:
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_up"):
		dir.z -= 1.0
	if Input.is_action_pressed("move_down"):
		dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		dir.x += 1.0
	return dir.normalized()

func _physics_process(delta: float) -> void:
	# ---------- Movement ----------
	input_dir = _get_input_dir()

	var target_speed := move_speed
	if Input.is_action_pressed("sprint"):
		target_speed *= sprint_multiplier

	var target_vel := input_dir * target_speed

	# Accelerate or decelerate on the horizontal plane
	var accel := acceleration if target_vel.length() > 0.01 else friction
	var diff := target_vel - velocity_h
	velocity_h += diff.limit_length(accel * delta)

	# Gravity and Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):  # Space by default
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0

	# Combine horizontal + vertical velocity
	velocity.x = velocity_h.x
	velocity.z = velocity_h.z

	move_and_slide()

	# Face movement direction (for top-down or third-person)
	if velocity_h.length() > 0.05:
		look_at(global_transform.origin + Vector3(velocity_h.x, 0, velocity_h.z), Vector3.UP)

	# ---------- Auto-fire ----------
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		var target := _get_nearest_enemy()
		if target != null:
			_shoot_at(target)
			_shoot_timer = shoot_cooldown

# Find nearest enemy within range
func _get_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node3D = null
	var best_d2 := max_target_distance * max_target_distance
	var my_pos := global_transform.origin
	for e in enemies:
		if e == null or !is_instance_valid(e): 
			continue
		var pos := (e as Node3D).global_transform.origin
		var d2 := my_pos.distance_squared_to(pos)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best

# Spawn and launch a bullet toward the given enemy
func _shoot_at(target: Node3D) -> void:
	if bullet_scene == null:
		return
	if target == null or !is_instance_valid(target):
		return

	var start_pos := global_transform.origin + muzzle_offset
	var dir := (target.global_transform.origin - start_pos).normalized()

	var bullet := bullet_scene.instantiate()

	# Add to scene FIRST so global_* setters work without warnings
	get_tree().current_scene.add_child(bullet)

	# Now safely set position/orientation and velocity
	bullet.global_position = start_pos
	bullet.look_at(start_pos + dir, Vector3.UP)
	bullet.velocity = dir * bullet.speed

func die() -> void:
	print("💀 Player died!")
	# Optional: disable movement
	set_physics_process(false)
	# Reset the score when the player dies
	GameManager.score = 0
	GameManager.emit_signal("score_changed", GameManager.score)
	# Optional: play animation, show UI, restart, etc.
	#await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
