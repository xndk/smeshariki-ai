extends Node3D

@export var active_during_day = true
@export var active_during_evening = true
@export var active_during_night = true

@onready var director = %Director

func _ready():
	setenv()
	if director:
		director.connect("set_environment", setenv)
			
func setenv():
	if director and director.current_environment:
		match director.current_environment:
			'day':     visible = active_during_day
			'evening': visible = active_during_evening	
			'night':   visible = active_during_night
