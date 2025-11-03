extends CharacterBody3D

@export var move_speed := 4.5
@export var sprint_multiplier := 1.6
@export var acceleration := 12.0
@export var friction := 10.0
@export var jump_velocity := 8.0
@export var gravity := 18.0

var input_dir := Vector3.ZERO
var velocity_h := Vector3.ZERO

func _ready() -> void:
	floor_snap_length = 0.3
	up_direction = Vector3.UP

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
	input_dir = _get_input_dir()
	var target_speed := move_speed
	if Input.is_action_pressed("sprint"):
		target_speed *= sprint_multiplier

	var target_vel := input_dir * target_speed

	# Accelerate / decelerate on the horizontal plane
	var accel := acceleration if target_vel.length() > 0.01 else friction
	var diff := target_vel - velocity_h
	velocity_h += diff.limit_length(accel * delta)

	# Gravity & Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):  # Space by default
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0

	# Combine horizontal and vertical velocity
	velocity.x = velocity_h.x
	velocity.z = velocity_h.z

	move_and_slide()

	# Face movement direction
	if velocity_h.length() > 0.05:
		look_at(global_transform.origin + Vector3(velocity_h.x, 0, velocity_h.z), Vector3.UP)
