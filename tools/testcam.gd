#extends Camera2D
#
#@export var pan_speed := 600.0
#@export var zoom_speed := 0.1
#@export var min_zoom := 0.2
#@export var max_zoom := 3.0
#@export var drag_button := MOUSE_BUTTON_LEFT
#@export var drag_sensitivity := 0.01
#var dragging := false
#var last_mouse_pos := Vector2.ZERO
#
#
#func _ready():
	#make_current()
#
#func _process(delta):
	#pass
#
#func _unhandled_input(event):
	#if event is InputEventMouseButton:
		#if event.button_index == drag_button:
			#dragging = event.pressed
			#last_mouse_pos = event.position
#
	#elif event is InputEventMouseMotion and dragging:
		#var delta = event.position - last_mouse_pos
		#global_position -= delta * zoom * drag_sensitivity
		#last_mouse_pos = event.position
	#handle_zoom(event)
#
#func handle_zoom(event):
	#if event is InputEventMouseButton:
		#if event.pressed:
			#if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				#zoom *= 1.1
			#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				#zoom *= 0.9
