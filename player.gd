# player.gd
extends CharacterBody3D

# -------- Movement / Physics (yours) --------
@export var move_speed := 4.5
@export var sprint_multiplier := 1.6
@export var acceleration := 12.0
@export var friction := 10.0
@export var jump_velocity := 8.0
@export var gravity := 18.0

# -------- Shooting / Auto-fire (yours) --------
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.25
@export var max_target_distance: float = 80.0
@export var muzzle_offset: Vector3 = Vector3(0, 1.2, 0)

# -------- Shotgun (E key) (yours) --------
@export var shotgun_pellets: int = 100
@export var shotgun_spread_deg: float = 360.0
@export var shotgun_cooldown: float = 0.8
@export var shotgun_vertical_jitter_deg: float = 2.5

# -------- Animation (new) --------
# Put an AnimationTree on the Player node, set its "Anim Player" to the model's AnimationPlayer,
# and create a StateMachine with states named to match these.
@export var idle_anim_name: String = "Idle"
@export var walk_anim_name: String = "Walk"
@export_range(0.0, 1.0, 0.01) var walk_threshold_speed: float = 0.10  # switch to Walk when horizontal speed > this

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

var _shoot_timer: float = 0.0
var input_dir := Vector3.ZERO
var velocity_h := Vector3.ZERO

func _ready() -> void:
	floor_snap_length = 0.3
	up_direction = Vector3.UP
	add_to_group("player")

	# Ensure "shotgun" exists (so E just works)
	if not InputMap.has_action("shotgun"):
		InputMap.add_action("shotgun")
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		InputMap.action_add_event("shotgun", ev)

	# ---- Animation init (new) ----
	if anim_tree:
		anim_tree.active = true
		# Start in Idle if present
		if state_machine and idle_anim_name != "":
			state_machine.travel(idle_anim_name)

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

	# ---------- Animation switching (new) ----------
	if anim_tree and state_machine:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var desired := idle_anim_name
		if horizontal_speed > walk_threshold_speed:
			desired = walk_anim_name
		if state_machine.get_current_node() != desired:
			state_machine.travel(desired)

	# ---------- Firing ----------
	_shoot_timer -= delta

	# Shotgun takes priority and does NOT need a target
	if _shoot_timer <= 0.0 and Input.is_action_pressed("shotgun"):
		_shoot_shotgun_facing()
		_shoot_timer = shotgun_cooldown
	elif _shoot_timer <= 0.0:
		# Normal auto-fire only if there is a target
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

# Spawn and launch a bullet toward the given enemy (single)
func _shoot_at(target: Node3D) -> void:
	if bullet_scene == null or target == null or !is_instance_valid(target):
		return

	var start_pos := global_transform.origin + muzzle_offset
	var dir := (target.global_transform.origin - start_pos).normalized()

	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = start_pos
	bullet.look_at(start_pos + dir, Vector3.UP)
	bullet.velocity = dir * bullet.speed

# Shotgun: spread from the player's facing direction (no targeting)
func _shoot_shotgun_facing() -> void:
	if bullet_scene == null or shotgun_pellets <= 0:
		return

	var start_pos := global_transform.origin + muzzle_offset
	# Player forward is -Z in Godot
	var base_dir := (-global_transform.basis.z).normalized()

	var pellets := shotgun_pellets
	var spread := shotgun_spread_deg
	if pellets == 1:
		_spawn_bullet(start_pos, base_dir)
		return

	var step := spread / float(pellets - 1)
	var start_angle := -spread * 0.5

	for i in range(pellets):
		var yaw_deg := start_angle + step * i
		var yaw_rad := deg_to_rad(yaw_deg)

		# Rotate around Y (horizontal spread)
		var dir := (Basis(Vector3.UP, yaw_rad) * base_dir).normalized()

		# Add tiny pitch jitter for a more natural cone
		if shotgun_vertical_jitter_deg > 0.0:
			var pitch_rad := deg_to_rad(randf_range(-shotgun_vertical_jitter_deg, shotgun_vertical_jitter_deg))
			var axis := dir.cross(Vector3.UP).normalized()
			if axis.length() > 0.0001:
				dir = (Basis(axis, pitch_rad) * dir).normalized()

		_spawn_bullet(start_pos, dir)

func _spawn_bullet(start_pos: Vector3, dir: Vector3) -> void:
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = start_pos
	bullet.look_at(start_pos + dir, Vector3.UP)
	bullet.velocity = dir * bullet.speed

func die() -> void:
	print("💀 Player died!")
	set_physics_process(false)
	GameManager.score = 0
	GameManager.emit_signal("score_changed", GameManager.score)
	get_tree().reload_current_scene()
