class_name IrohConnectMenu extends PanelContainer


signal join_pressed()
signal cancel_pressed()
signal create_pressed()


@export var _connection_string_edit: LineEdit


#########################
###       Public      ###
#########################

func get_entered_connection_string() -> String:
	return _connection_string_edit.text.strip_edges()


#########################
###     Callbacks     ###
#########################

func _on_cancel_button_pressed():
	cancel_pressed.emit()


func _on_create_button_pressed():
	create_pressed.emit()


func _on_join_button_pressed():
	join_pressed.emit()
