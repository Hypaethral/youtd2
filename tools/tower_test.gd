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

	row_offset += 240
	column_offset = 0
	var t1 = Tower.make(159, player, null, false)
	var t2 = Tower.make(159, player, null, false)
	var t3 = Tower.make(159, player, null, false)
	var t4 = Tower.make(159, player, null, false)
	var t5 = Tower.make(159, player, null, false)
	t1._can_be_upgraded = false
	add_child(t1)
	t1.position = Vector2(column_offset, row_offset)
	column_offset += 155
	t2._can_be_upgraded = false
	t2.set_upgrade_indicator_style(Tower.UpgradeIndicatorStyle.DERPY_EXCLAIM)
	add_child(t2)
	t2.position = Vector2(column_offset, row_offset)
	column_offset += 155
	t3._can_be_upgraded = true
	add_child(t3)
	t3.position = Vector2(column_offset, row_offset)
	column_offset += 155
	t4._can_be_upgraded = true
	add_child(t4)
	t4.position = Vector2(column_offset, row_offset)
	column_offset += 155
	t5._can_be_upgraded = true
	add_child(t5)
	t5.position = Vector2(column_offset, row_offset)

	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
