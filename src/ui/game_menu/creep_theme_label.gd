extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "[wave amp=50.0 freq=5.0 connected=1][rainbow freq=4 sat=0.8 val=0.8 speed=0.2]" + tr("SETTINGS_CREEP_THEME") + "[/rainbow][/wave]"
