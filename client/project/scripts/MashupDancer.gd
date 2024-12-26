extends Node3D

@export var character: String = ""
@export var bpm: float = 120

var animations = [
	preload("res://assets/animations/dance/Dance-01-gamgam1.res"),
	preload("res://assets/animations/dance/Dance-01-gamgam2.res"),
]
var animation_names = [
	'gamgam1', 
	'gamgam2',
]

@onready var target = get_node(character)
@onready var anim_pl: AnimationPlayer = target.get_node('AnimationPlayer')
@onready var director = get_tree().current_scene.get_node("Director")


func _ready():
	if target != null: 
		target.show()
		anim_pl = target.get_node('AnimationPlayer')
		anim_pl.speed_scale = 1.0 / 120 * bpm
		var anim_lib = AnimationLibrary.new()
		for i in range(len(animations)):
			anim_lib.add_animation(animation_names[i], animations[i])
		anim_pl.add_animation_library("dances", anim_lib)
		
	if director:
		director.connect('set_dancer_anim', set_dancer_anim)

func set_dancer_anim(anim_name: String):
	anim_pl.play(str("dances/", anim_name))
