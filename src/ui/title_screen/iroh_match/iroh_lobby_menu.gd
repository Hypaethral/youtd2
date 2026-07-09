class_name IrohLobbyMenu extends PanelContainer


# Menu for an open Iroh (peer-to-peer) lobby, before the game begins.
# Displays players in the lobby. On the host, shows the connection string
# that joiners must paste, with a button to copy it to the clipboard.


signal start_pressed()
signal back_pressed()


@export var _player_list: ItemList
@export var _match_config_label: RichTextLabel
@export var _connection_string_container: HBoxContainer
@export var _connection_string_line_edit: LineEdit
@export var _start_button: Button


#########################
###       Public      ###
#########################

func set_player_list(player_list: Array[String]):
	_player_list.clear()

	for player in player_list:
		_player_list.add_item(player)

	for i in range(0, _player_list.item_count):
		_player_list.set_item_selectable(i, false)


func display_match_config(match_config: MatchConfig):
	var match_config_string: String = match_config.get_display_string_rich()

	_match_config_label.clear()
	_match_config_label.append_text(match_config_string)


func set_connection_string(value: String):
	_connection_string_line_edit.text = value


func set_connection_string_visible(value: bool):
	_connection_string_container.visible = value


func set_start_button_visible(value: bool):
	_start_button.visible = value


#########################
###     Callbacks     ###
#########################

func _on_back_button_pressed():
	back_pressed.emit()


func _on_start_button_pressed():
	start_pressed.emit()


func _on_copy_button_pressed():
	DisplayServer.clipboard_set(_connection_string_line_edit.text)
