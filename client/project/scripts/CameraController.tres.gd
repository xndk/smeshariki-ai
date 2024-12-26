extends Node3D

@export var initial_fov: float = 130
@export var final_fov: float = 60
@export var initial_up_rot: float = 24
@export var final_up_rot: float = -6
@export var final_up_rot_small: float = -12

@onready var cam_spin: Node3D = get_node("SpinControl")
@onready var cam: Camera3D = get_node("SpinControl/Camera3D")
@onready var cam_intersect: ShapeCast3D = get_node("SpinControl/ShapeCast3D")
@onready var director: Node = %Director
var mode: String = ""

@onready var target_rot_x = cam.rotation.y
@onready var current_rot_x = cam.rotation.y
@onready var target_pos = Vector2(randf_range(-8, 8), randf_range(-8, 8))
@onready var current_pos = target_pos
@onready var target_rot_y = initial_up_rot

var target_node = null
var first_time = true
var initial_animation_finished = false
var allowed_to_move = true
var zoom_shift = 0
var is_mashup = false

var initial_blocking_raycast_size = 0.3
var blocking_raycast_size = initial_blocking_raycast_size

func _ready():
	# Initial setup
	cam.fov = initial_fov
	cam_spin.get_node("RimLight").show()
	set_blocking_raycast_size(initial_blocking_raycast_size)
	
	# Intro tween animation (tilt down and zoom in)
	create_tween()\
		.tween_property(cam, "fov", final_fov, 3)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)	
	var initial_tween = create_tween()\
		.tween_property(self, "target_rot_y", final_up_rot, 3)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	await initial_tween.finished
	
	initial_animation_finished = true
	
func mode_specific_setup(new_mode):
	mode = new_mode
	if mode == 'mashup':
		target_pos = Vector2(0, -5)
		current_pos = target_pos
		allowed_to_move = false
		is_mashup = true
	

func _process(delta):
	# Look at target node, if exists
	if (target_node):
		# For bibi, tilt the camera lower
		var tilt = final_up_rot_small if target_node.name == "bibi" else final_up_rot
		cam_look_at(target_node.position, tilt)
		
	# Lerp horizontal rotation (spin)
	current_rot_x = lerp_angle(current_rot_x, target_rot_x, 2 * delta)
	cam_spin.rotation.y = current_rot_x
	
	# Lerp vertical rotation (tilt)
	if initial_animation_finished:
		cam.rotation.x = lerp_angle(cam.rotation.x, deg_to_rad(target_rot_y), 2 * delta)
		cam.fov = final_fov - zoom_shift
	else:
		cam.rotation_degrees.x = target_rot_y
	
	# Lerp position
	current_pos += (target_pos - current_pos) * 3 * delta
	position.x = current_pos.x
	position.z = current_pos.y
	
	# Lerp zoom shift
	zoom_shift -= zoom_shift * 5 * delta
	
func _physics_process(delta):
	var cols = cam_intersect.get_collision_count()
	if cols > 0:
		var blocking_colliders = []
		for col_idx in range(cols):
			var col = cam_intersect.get_collider(col_idx)
			var spin = get_viewport().get_camera_3d().global_rotation.y
			var normal = cam_intersect.get_collision_normal(col_idx).rotated(Vector3(0, 1, 0), -spin)
			if col != target_node:
				blocking_colliders.append({
					'collider': col,
					'normal': normal,
				})
		
		for col in blocking_colliders:
			col.collider.attempt_clear_blocking(col.normal)
			
		# if someone is blocking the view, slowly increase the raycasting radius,
		# otherwise, return it to normal
		if blocking_colliders.size() > 0:
			set_blocking_raycast_size(min(blocking_raycast_size + 1.5 * delta, 4))
		else:
			set_blocking_raycast_size(initial_blocking_raycast_size)


func cam_look_at(pos: Vector3, tilt: float = final_up_rot):
	# Step 1: determine spin control's horizontal rotation
	var spin_control_prev_rot = cam_spin.rotation
	cam_spin.look_at(pos)
	target_rot_x = cam_spin.rotation.y
	cam_spin.rotation = spin_control_prev_rot
	
	# Step 2: determine camera's vertical rotation, if the initial animation has finished
	if initial_animation_finished:
		var camera_prev_rot = cam.rotation
		cam.look_at(pos)
		target_rot_y = tilt
		cam.rotation = camera_prev_rot
		
	# Step 3: point the intersection shapecast
	cam_intersect.look_at(pos)
	cam_intersect.rotation_degrees.x = 90
	cam_intersect.rotation_degrees.z = 0

func turn_to_speaker(node: Node3D):
	var node_2d_pos = Vector2(node.position.x, node.position.z)
	var direction_to_node = (target_pos - node_2d_pos).normalized()
	var distance_to_node = target_pos.distance_to(node_2d_pos)
	var offset = direction_to_node * clamp(distance_to_node, 6, 9)
	var offset_target_pos = node_2d_pos + offset
	
	if allowed_to_move:
		create_tween().tween_property(self, 'target_pos', offset_target_pos, randf_range(1, 2))
	
	if not first_time:
		create_tween().tween_property(self, 'target_rot_x', node.rotation.y, randf_range(1, 2))
		await wait(randf_range(.5, 1.5))
		
	target_node = node
	
func set_blocking_raycast_size(n: float):
	blocking_raycast_size = n
	cam_intersect.shape.radius = blocking_raycast_size

func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)


