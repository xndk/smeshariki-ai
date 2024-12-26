extends AnimationPlayer

@export var animation_name = "RESET"

func _ready():
	play(animation_name)
