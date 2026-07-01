extends Node

@export var _camera_controller: CameraController

const THIS_MANY = 10
var tower_ids = []
const SHOW_UPGRADE_INDICATORS = true
const STYLE_INDICATOR = Tower.UpgradeIndicatorStyle.DERPY_EXCLAIM

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player = Player.make(1,1,"foo")

	var row_offset = 0
	var column_offset = 0
	for i in range(THIS_MANY):
		if (i != 0 && i % 2 == 0):
			column_offset = 0
			row_offset += 240

		var rand_tower_id = -1
		while rand_tower_id == -1 || tower_ids.has(rand_tower_id):
			rand_tower_id = randi_range(1, 620)

		tower_ids.append(rand_tower_id)

		for s in Tower.UpgradeIndicatorStyle.values():
			var t = Tower.make(rand_tower_id, player, null, false)
			t._can_be_upgraded = true
			t.set_upgrade_indicator_style(s)
			add_child(t)
			t.position = Vector2(column_offset, row_offset)
			column_offset += 155
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
