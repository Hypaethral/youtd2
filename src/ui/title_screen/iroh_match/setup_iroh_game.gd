class_name SetupIrohGame extends Node


# Handles logic for creating and joining Iroh (peer-to-peer) matches.
# Iroh is a QUIC-based MultiplayerPeer that prefers direct p2p connections
# and automatically falls back to public relays when a direct path can't
# be established. Copy-pasted from SetupLanGame - the only real differences
# are that peers are identified by a base64 "connection string" (node id)
# instead of an IP address, and that connecting is asynchronous (errors surface
# via multiplayer.connection_failed instead of a synchronous Error return).


const SERVER_PEER_ID: int = 1
const IROH_PEER_FACTORY_PATH: String = "res://src/ui/title_screen/iroh_match/iroh_peer_factory.gd"


var _current_match_config: MatchConfig = null


@export var _title_screen: TitleScreen
@export var _iroh_connect_menu: IrohConnectMenu
@export var _iroh_lobby_menu: IrohLobbyMenu
@export var _create_iroh_match_menu: CreateIrohMatchMenu

var _peer_id_to_player_name_map: Dictionary = {}


#########################
###     Built-in      ###
#########################

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


#########################
###      Private      ###
#########################

func _update_player_list_in_lobby_menu():
	var peer_id_list: Array = multiplayer.get_peers()
	var local_peer_id: int = multiplayer.get_unique_id()
	peer_id_list.append(local_peer_id)

	var player_list: Array[String] = []

	for peer_id in peer_id_list:
		var fallback_string: String = "Player %d" % peer_id
		var player_name: String = _peer_id_to_player_name_map.get(peer_id, fallback_string)
		player_list.append(player_name)

	_iroh_lobby_menu.set_player_list(player_list)


# All peers (including the host itself) call this f-n to
# tell the host their player names. The host later passes
# this info to all peers.
@rpc("any_peer", "call_local", "reliable")
func _give_local_player_name_to_host(player_name: String):
	var peer_id: int = multiplayer.get_remote_sender_id()
	_peer_id_to_player_name_map[peer_id] = player_name

	_receive_player_name_map_from_host.rpc(_peer_id_to_player_name_map)


@rpc("authority", "call_local", "reliable")
func _receive_player_name_map_from_host(player_name_map: Dictionary):
	_peer_id_to_player_name_map = player_name_map

#	NOTE: need to update displayed player list to show
#	updated player names
	_update_player_list_in_lobby_menu()


@rpc("authority", "call_local", "reliable")
func _receive_match_config_from_host(match_config_bytes: PackedByteArray):
	_current_match_config = MatchConfig.convert_from_bytes(match_config_bytes)
	_iroh_lobby_menu.display_match_config(_current_match_config)


# This check is needed because SetupLanGame and SetupIrohGame both
# connect to the same global multiplayer.* signals. Each controller
# ignores signals unless the active MultiplayerPeer is its own type.
# NOTE: use string-based is_class() rather than "is IrohServer" so that
# this script has no compile-time dependency on the (native-only) iroh
# GDExtension - see iroh_peer_factory.gd.
func _multiplayer_peer_is_iroh() -> bool:
	var multiplayer_peer: MultiplayerPeer = multiplayer.get_multiplayer_peer()

	if multiplayer_peer == null:
		return false

	var peer_is_iroh: bool = multiplayer_peer.is_class("IrohServer") or multiplayer_peer.is_class("IrohClient")

	return peer_is_iroh


# Loads the factory that wraps the iroh GDExtension classes. Returns null
# (and shows a popup) if the plugin isn't installed. Only ever reached
# from the create/join handlers, which are unreachable on platforms where
# the extension is unavailable (the entry button is hidden there).
func _get_peer_factory() -> GDScript:
	if !ClassDB.class_exists("IrohServer"):
		Utils.show_popup_message(self, tr("GENERIC_ERROR_TITLE"), tr("SETUP_IROH_ERROR_PLUGIN_MISSING"))

		return null

	var factory: GDScript = load(IROH_PEER_FACTORY_PATH)

	return factory


#########################
###     Callbacks     ###
#########################

func _on_connected_to_server():
	if !_multiplayer_peer_is_iroh():
		return

	var local_player_name: String = Settings.get_setting(Settings.PLAYER_NAME)
	_give_local_player_name_to_host.rpc_id(SERVER_PEER_ID, local_player_name)


func _on_connection_failed():
	if !_multiplayer_peer_is_iroh():
		return

	var error_text: String = ""
	var iroh_peer: MultiplayerPeer = multiplayer.get_multiplayer_peer()
	if iroh_peer != null and iroh_peer.is_class("IrohClient"):
		error_text = iroh_peer.call("connection_error")

	Utils.show_popup_message(self, tr("GENERIC_ERROR_TITLE"), tr("SETUP_IROH_ERROR_FAILED_CLIENT").format({ERROR = error_text}))
	push_error("SETUP_IROH_ERROR_FAILED_CLIENT with %s" % error_text)

	multiplayer.multiplayer_peer = null

	_title_screen.switch_to_tab(TitleScreen.Tab.IROH_CONNECT_MENU)


func _on_peer_connected(peer_id: int):
	if !_multiplayer_peer_is_iroh():
		return

# 	When a new peer connects, host(server) will tell the
# 	newly connected peer the names of all of the players.
	if multiplayer.is_server():
		_receive_player_name_map_from_host.rpc_id(peer_id, _peer_id_to_player_name_map)
		var match_config_bytes: PackedByteArray = _current_match_config.convert_to_bytes()
		_receive_match_config_from_host.rpc_id(peer_id, match_config_bytes)

	_update_player_list_in_lobby_menu()


func _on_peer_disconnected(_id: int):
	if !_multiplayer_peer_is_iroh():
		return

	_update_player_list_in_lobby_menu()


func _on_create_iroh_match_menu_create_pressed():
	var factory: GDScript = _get_peer_factory()
	if factory == null:
		return

	_current_match_config = _create_iroh_match_menu.get_match_config()

	var server: MultiplayerPeer = factory.make_server()
	multiplayer.set_multiplayer_peer(server)

	_title_screen.switch_to_tab(TitleScreen.Tab.IROH_LOBBY)
	_iroh_lobby_menu.display_match_config(_current_match_config)
	_iroh_lobby_menu.set_connection_string(server.call("connection_string"))
	_iroh_lobby_menu.set_connection_string_visible(true)
	_iroh_lobby_menu.set_start_button_visible(true)

	var local_player_name: String = Settings.get_setting(Settings.PLAYER_NAME)
	_give_local_player_name_to_host.rpc_id(SERVER_PEER_ID, local_player_name)

	_update_player_list_in_lobby_menu()


func _on_iroh_connect_menu_create_pressed():
	_title_screen.switch_to_tab(TitleScreen.Tab.CREATE_IROH_MATCH)


func _on_iroh_lobby_menu_start_pressed():
	var is_host: bool = multiplayer.is_server()
	if !is_host:
		Utils.show_popup_message(self, tr("GENERIC_ERROR_TITLE"), tr("SETUP_LAN_ERROR_ONLY_HOST_CAN_START"))

		return

	var difficulty: Difficulty.enm = _current_match_config.get_difficulty()
	var game_length: int = _current_match_config.get_game_length()
	var game_mode: GameMode.enm = _current_match_config.get_game_mode()
	var team_mode: TeamMode.enm = _current_match_config.get_team_mode()
	var origin_seed: int = randi()

#	NOTE: build the authoritative peer list on the host (peer
#	1) and pass it to all clients.
	var peer_id_list: Array = [1]
	peer_id_list.append_array(multiplayer.get_peers())
	peer_id_list.sort()

	_title_screen.start_game.rpc(PlayerMode.enm.MULTIPLAYER, game_length, game_mode, difficulty, team_mode, origin_seed, Globals.ConnectionType.IROH, peer_id_list, _peer_id_to_player_name_map)


func _on_iroh_connect_menu_join_pressed():
	var connection_string: String = _iroh_connect_menu.get_entered_connection_string()

	if connection_string.is_empty():
		Utils.show_popup_message(self, tr("GENERIC_ERROR_TITLE"), tr("SETUP_IROH_ERROR_MISSING_CONNECTION_STRING"))

		return

	var factory: GDScript = _get_peer_factory()
	if factory == null:
		return

#	NOTE: remember the host's connection string so GameClient can redial
#	the same host if the connection drops mid-game.
	Globals.set_iroh_host_connection_string(connection_string)

	var client: MultiplayerPeer = factory.make_client(connection_string)
	multiplayer.set_multiplayer_peer(client)

	_title_screen.switch_to_tab(TitleScreen.Tab.IROH_LOBBY)

	_iroh_lobby_menu.set_connection_string_visible(false)
	_iroh_lobby_menu.set_start_button_visible(false)


# NOTE: both server and clients need to close the
# connection when leaving lobby menu
func _on_iroh_lobby_menu_back_pressed():
	multiplayer.multiplayer_peer.close()
