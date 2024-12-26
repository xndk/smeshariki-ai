extends Node3D

@export var follow_target = false
@export var rotate_on_beat = false
@export var initial_color: Color = Color.WHITE

@onready var director = get_tree().current_scene.get_node("Director")
@onready var light_base_energy = $light.light_energy
@onready var light_base_opacity = $meshhold/mesh.mesh.material.albedo_color.a

var target_node = null

var lightshine_sounds = [
	preload("res://assets/sounds/lightshine2.wav"),
	preload("res://assets/sounds/lightshine3.wav"),
	preload("res://assets/sounds/lightshine4.wav"),
	preload("res://assets/sounds/lightshine5.wav"),
	preload("res://assets/sounds/lightshine6.wav"),
	preload("res://assets/sounds/lightshine7.wav"),
]
	
func _ready():
	_setup()
	
func _setup():
	randomize()
	director = get_tree().current_scene.get_node("Director")
	set_color(initial_color)
	reset_rotation()
	if director != null:
		director.connect("turn_to_speaker", _set_target)
		if rotate_on_beat:
			director.connect("song_beat", _on_beat)
			rand_rotate()
		if follow_target:
			intro_anim()
	
func _set_target(target: Node3D):
	target_node = target

func _on_beat(_idx):
	if rotate_on_beat: rand_rotate()
	
func _process(_delta):
	if follow_target and target_node:
		var pos = Vector3(target_node.position.x, 0, target_node.position.z)
		if pos.x != position.x or pos.z != position.z: look_at(pos)
		else: reset_rotation()

func set_color(color: Color, opacity: float = 0):
	$meshhold/mesh.mesh.material.albedo_color.h = color.h
	$meshhold/mesh.mesh.material.albedo_color.s = color.s
	$meshhold/mesh.mesh.material.albedo_color.v = color.v
	if opacity > 0: $meshhold/mesh.mesh.material.albedo_color.a = opacity
	$light.light_color = color
	
func set_power(p: float):
	$light.light_energy = light_base_energy * p
	$meshhold/mesh.mesh.material.albedo_color.a = light_base_opacity * p
	
func rand_rotate():
	var new_rotation_degrees = Vector3(-90 + randf_range(-25, 25), randf_range(-25, 25), 0)
	create_tween().tween_property(self, 'rotation_degrees', new_rotation_degrees, randf_range(0.05, 0.25))
	set_color(random_party_color(), randf())
	
func reset_rotation():
	rotation_degrees = Vector3(-90, 0, 0)
	
func intro_anim():
	$sfx.stream = lightshine_sounds.pick_random()
	set_power(0)
	await wait(1)
	
	if director and director.episode_data.type == 'mashup':
		$sfx.play()
		create_tween().tween_method(set_power, 0.0, 1.0, .25).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	

func wait (seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	remove_child(timer)

func random_party_color():
	return Color.from_hsv(randf(), 1, 1)
