extends Node2D

@onready var anim = get_node("anim")
@onready var topic_elem = get_node("Clapper1/topic")
@onready var progress_elem = get_node("Clapper1/progress")

func set_topic(topic):
	if topic == null: return
	topic_elem.text = "Тема: " + topic
	
func set_progress(progress, max_progress):
	if progress == null or max_progress == null: return
	progress_elem.max_value = max_progress
	progress_elem.value = progress
	
func start():
	anim.play("start")
	get_node("/root/Global").clapper_transition()
	
func end():
	anim.play("end")
