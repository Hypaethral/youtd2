class_name ButtonWithHold extends Button

@export var duration_seconds_of_hold: float

@onready var _visual_indicator: PanelContainer = $PanelContainer

signal done_holding

var _current_duration_seconds: float # maybe duration frames..?
var _is_being_held: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_reset_viz()
	_current_duration_seconds = 0
	self.button_down.connect(self._button_pressed)
	self.button_up.connect(self._button_released)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# delta is a time in seconds
	if (_is_being_held):
		_current_duration_seconds += delta
		print("current hold length (seconds): %s" % _current_duration_seconds)
		# width of panel == timer progress
		
		_visual_indicator.size = Vector2(self.size[0] * (_current_duration_seconds / duration_seconds_of_hold), _visual_indicator.size[1])
		
		if (_current_duration_seconds >= duration_seconds_of_hold):
			done_holding.emit()
			_button_released()
	pass

func _button_pressed():
	_is_being_held = true
	pass

func _reset_viz():
	_visual_indicator.size = Vector2(0,self.size[1])

func _button_released():
	_is_being_held = false
	_reset_viz()
	_current_duration_seconds = 0
	pass
