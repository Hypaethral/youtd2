class_name GameClient extends Node


# GameClient for the game ticks, synchronized with the
# server.
# 
# GameClient ticks 30 times per second (based on
# physics_ticks_per_second config value).
# 
# Peers send actions requested by local player to host.
# Host combines all actions into timeslots and sends
# timeslots to all peers.
# 
# Stops ticking if a timeslot is not ready for current tick.
# 
# The end result is that clients are synchronized.


signal received_first_timeslot()


# NOTE: this value determines how fast timeslot buffer
# lowers when ping decreases. Higher value = faster
# lowering.
const TIMESLOT_BUFFER_SIZE_LOWERING_FACTOR: float = 0.4
const PING_HISTORY_SIZE: int = 10
const TICKS_PER_SECOND: int = 30
const CHECKSUM_PERIOD_TICKS: int = TICKS_PER_SECOND * GameHost.MULTIPLAYER_TURN_LENGTH

# Iroh reconnect: when the transport drops mid-game, the client redials the
# same host (by node id) with exponential backoff. The client keeps a stable
# iroh identity across redials, so the host reissues its original peer id.
const IROH_PEER_FACTORY_PATH: String = "res://src/ui/title_screen/iroh_match/iroh_peer_factory.gd"
const REDIAL_MAX_ATTEMPTS: int = 8
const REDIAL_BASE_DELAY_SEC: float = 0.5
const REDIAL_MAX_DELAY_SEC: float = 15.0
const REDIAL_CONNECT_TIMEOUT_MSEC: int = 5000


var _tick_delta: float
var _current_tick: int = 0
var _turn_length: int
# Timeslot buffer determines how many timeslots to keep in
# buffer. Turns are buffered to avoid getting into
# situations where client runs out of timeslots and has to
# stall until next one arrives.
var _timeslot_buffer_size: float

# A map of timeslots. Need to keep a map in case we receive
# future timeslots before we processed current one.
# {tick -> timeslot}
var _timeslot_map: Dictionary = {}
var _time_when_sent_ping: int = 0
var _ping_history: Array = [0]
var _received_any_timeslots: bool = false
var _paused_by_host: bool = false
# High-water mark: highest tick this client has ever received from the host.
# Sent in each ping so the host can drop every timeslot <= this from its
# per-player send queue. Monotonic + reliable transport means a lost ping
# self-heals (the next ping re-carries the same or a higher mark).
var _max_received_tick: int = -1
# Store checksum data for desync debugging: {tick -> checksum_data_dict}
var _checksum_data_map: Dictionary = {}
# Diagnostic (all connection types): wall-clock msec when the last timeslot
# arrived from the host, and a throttle for the degraded-connection log.
# Used to correlate a transport drop with a preceding traffic lull.
var _last_timeslot_msec: int = 0
var _last_net_log_msec: int = 0
# True while an iroh redial loop is in progress (avoids overlapping loops).
var _redialing: bool = false


@export var _game_host: GameHost
@export var _game_time: GameTime
@export var _hud: HUD
@export var _build_space: BuildSpace
@export var _chat_commands: ChatCommands
@export var _select_unit: SelectUnit


#########################
###     Built-in      ###
#########################

func _ready():
	var tick_rate: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")

	if tick_rate != 30:
		push_error("Physics tick rate got changed by accident. Must be 30 for multiplayer purposes.")

#	NOTE: save this delta and use it instead of the one we
#	get in _physics_process because we need all clients to
#	use the same delta value.
	_tick_delta = 1.0 / tick_rate

	_turn_length = Utils.get_turn_length()
	_timeslot_buffer_size = _turn_length

	multiplayer.server_disconnected.connect(_on_net_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_net_peer_disconnected)
	multiplayer.connection_failed.connect(_on_net_connection_failed)


# NOTE: using _physics_process() because it provides a
# built-in way to do consistent tickrate, independent of
# framerate.
func _physics_process(_delta: float):
#	NOTE: depending on _should_tick() return value, client
#	may tick 0, 1 or multiple times.
	var ticks_during_this_process: int = 0
	while _should_tick(ticks_during_this_process):
		_do_tick()
		ticks_during_this_process += 1

	_log_connection_if_degraded()


#########################
###       Public      ###
#########################

func set_paused_by_host(value: bool):
	_paused_by_host = value


# Send action from client to host
func add_action(action: Action):
	var serialized_action: Dictionary = action.serialize()
	_game_host.receive_action.rpc_id(1, serialized_action)


# Returns current tick number. Used for deterministic
# calculations in multiplayer to avoid float precision issues.
func get_current_tick() -> int:
	return _current_tick


#########################
###   Net diagnostics ###
#########################

func _net_connection_status() -> int:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return peer.get_connection_status()


# Runs every physics frame but logs at most once/second, and only while the
# connection is degraded (uid == -1 or not CONNECTED). Kept outside the tick
# loop because a dropped client stops ticking but _physics_process keeps running.
func _log_connection_if_degraded():
	var now: int = Time.get_ticks_msec()
	if now - _last_net_log_msec < 1000:
		return
	_last_net_log_msec = now

	var uid: int = multiplayer.get_unique_id()
	var status: int = _net_connection_status()
	if uid == -1 or status != MultiplayerPeer.CONNECTION_CONNECTED:
		var since_timeslot: int = now - _last_timeslot_msec
		push_warning("[net] degraded tick=%d uid=%d status=%d %dms_since_timeslot connection_type=%d" % [_current_tick, uid, status, since_timeslot, Globals.get_connect_type()])
#		Safety net in case server_disconnected didn't fire: the redial is
#		guarded so repeated calls are harmless.
		_try_redial_iroh_host()


func _on_net_server_disconnected():
	push_warning("[net] server_disconnected tick=%d uid=%d %dms_since_timeslot" % [_current_tick, multiplayer.get_unique_id(), Time.get_ticks_msec() - _last_timeslot_msec])
	_try_redial_iroh_host()


# Exponential-backoff redial of the iroh host after a dropped connection.
func _try_redial_iroh_host():
	if _redialing:
		return
	if Globals.get_connect_type() != Globals.ConnectionType.IROH:
		return

	var host_string: String = Globals.get_iroh_host_connection_string()
	if host_string.is_empty():
		return

	_redialing = true
	var delay: float = REDIAL_BASE_DELAY_SEC

	for attempt in range(REDIAL_MAX_ATTEMPTS):
		push_warning("[net] iroh redial attempt %d/%d in %.1fs" % [attempt + 1, REDIAL_MAX_ATTEMPTS, delay])
		await get_tree().create_timer(delay).timeout

#		Bail if the connection recovered on its own or we've left the game.
		if !is_inside_tree() || _net_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break

		if await _reconnect_to_host(host_string):
			push_warning("[net] iroh redial succeeded, uid=%d" % multiplayer.get_unique_id())
			_redialing = false
			return

		delay = minf(delay * 2.0, REDIAL_MAX_DELAY_SEC)

	push_warning("[net] iroh redial gave up (or recovered) after up to %d attempts" % REDIAL_MAX_ATTEMPTS)
	_redialing = false


func _reconnect_to_host(host_string: String) -> bool:
	var factory: GDScript = load(IROH_PEER_FACTORY_PATH)
	if factory == null:
		return false

	var client: MultiplayerPeer = factory.make_client(host_string)
	multiplayer.multiplayer_peer = client

#	Poll the new peer's status until it connects, fails, or times out.
	var deadline: int = Time.get_ticks_msec() + REDIAL_CONNECT_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
		var status: int = client.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			return true
		if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return false

	return false


func _on_net_peer_disconnected(peer_id: int):
	push_warning("[net] peer_disconnected peer=%d tick=%d uid=%d status=%d %dms_since_timeslot" % [peer_id, _current_tick, multiplayer.get_unique_id(), _net_connection_status(), Time.get_ticks_msec() - _last_timeslot_msec])


func _on_net_connection_failed():
	push_warning("[net] connection_failed tick=%d" % _current_tick)


@rpc("authority", "call_local", "reliable")
func receive_alive_check():
	_game_host.receive_alive_check_response.rpc_id(1)


# Receive timeslot sent by host to this client and receive
# turn length
# 
# NOTE: this f-n needs to handle cases where timeslots
# are received out of order.
@rpc("authority", "call_local", "reliable")
func receive_timeslots(timeslot_list: Dictionary):
	if !_received_any_timeslots:
		_received_any_timeslots = true
		received_first_timeslot.emit()

#	NOTE: it's important to skip old ticks, host can send
#	old ticks if it hasn't received ack from client yet due
#	to network/logic delay. If we don't skip old ticks, then
#	_timeslot_map would grow forever.
#	NOTE: sort keys to ensure deterministic iteration order for multiplayer sync
	var sorted_timeslot_keys: Array = timeslot_list.keys()
	sorted_timeslot_keys.sort()
	for tick in sorted_timeslot_keys:
		_max_received_tick = max(_max_received_tick, int(tick))
		if tick < _current_tick:
			continue

		_timeslot_map[tick] = timeslot_list[tick]
	_last_timeslot_msec = Time.get_ticks_msec()


@rpc("authority", "call_local", "reliable")
func receive_pong():
	var time_when_received_pong: int = Time.get_ticks_msec()
	var ping_time: int = time_when_received_pong - _time_when_sent_ping

	_ping_history.append(ping_time)
	if _ping_history.size() > PING_HISTORY_SIZE:
		_ping_history.pop_front()

	var ping_average: float = _get_ping_average()
	_hud.set_ping_time(ping_average)

	var ping_max: float = _get_ping_max()
	_update_timeslot_buffer_size(ping_max)

	_game_host.receive_ping_time_for_player.rpc_id(1, ping_time)


@rpc("authority", "call_local", "reliable")
func set_enet_player_names(player_name_map: Dictionary):
	Globals._enet_peer_id_to_player_name = player_name_map

# NOTE: arg must be Array instead of Array[String]. RPC
# calls have typing issues
@rpc("authority", "call_local", "reliable")
func set_lagging_players(lagging_player_list: Array):
	var players_are_lagging: bool = lagging_player_list.size() > 0

	_hud.set_waiting_for_lagging_players_indicator_player_list(lagging_player_list)
	_hud.set_waiting_for_lagging_players_indicator_visible(players_are_lagging)

# Receive desync notification from server and send back stored checksum data
@rpc("authority", "call_local", "reliable")
func receive_desync_notification(tick: int):
	push_error("!!! DESYNC NOTIFICATION received from server for tick %d !!!" % tick)

	if _checksum_data_map.has(tick):
		var checksum_data: Dictionary = _checksum_data_map[tick]
		_game_host.receive_checksum_data_from_client.rpc_id(1, tick, checksum_data)
	else:
		push_error("  ERROR: No stored checksum data for tick %d" % tick)

# notification from the authority to drop a given player.  Typically a result of lagging players,
# but the lagging players list will be reset *separately* once the host recovers from the wait loop 
@rpc("authority", "call_local", "reliable")
func receive_drop_player_notification(id: int):
	push_warning("dropping player by id %s" % id)
	PlayerManager.drop_player(id)

#########################
###      Private      ###
#########################

# NOTE: buffer value rises instantly but lowers gradually.
# This is to prevent abrupt changes in input latency.
func _update_timeslot_buffer_size(ping_time_ms: float):
	var ping_time_sec: float = ping_time_ms / 1000.0
	var new_size: float = ping_time_sec / _tick_delta

	if new_size < _timeslot_buffer_size:
		_timeslot_buffer_size = lerp(_timeslot_buffer_size, new_size, TIMESLOT_BUFFER_SIZE_LOWERING_FACTOR)
	else:
		_timeslot_buffer_size = new_size

	if _timeslot_buffer_size < _turn_length:
		_timeslot_buffer_size = _turn_length


func _should_tick(ticks_during_this_process: int) -> bool:
# 	NOTE: need to limit ticks per process to not disrupt
# 	timing of _physics_process() too much
	var too_many_ticks: bool = ticks_during_this_process > Constants.MAX_UPDATE_TICKS_PER_PHYSICS_TICK
	if too_many_ticks:
		return false
	
#	If current tick needs a timeslot and client hasn't
#	received timeslot from host yet, client has to wait
	var need_timeslot: bool = _current_tick % _turn_length == 0
	var have_timeslot: bool = _timeslot_map.has(_current_tick)
	if need_timeslot && !have_timeslot:
		return false

#	NOTE: keep size of timeslot buffer within certain value.
#	If too many timeslots are buffered, client fast forward
#	to catch up to host.
	if !_timeslot_map.is_empty():
		var timeslot_ticks: Array = _timeslot_map.keys()
		timeslot_ticks.sort()
		var latest_timeslot_tick: int = timeslot_ticks.back()
		var ticks_to_latest_timeslot: int = latest_timeslot_tick - _current_tick
		var buffer_is_too_big: bool = ticks_to_latest_timeslot > _timeslot_buffer_size
		
		if buffer_is_too_big:
			return true

#	If don't need to fast forward, tick at regular pace (1
#	tick per process() call or more if custom game speed is
#	set)
	var update_tick_count: int = min(Globals.get_update_ticks_per_physics_tick(), Constants.MAX_UPDATE_TICKS_PER_PHYSICS_TICK)
	var should_tick: bool = ticks_during_this_process < update_tick_count

	return should_tick


func _do_tick():
	var need_timeslot: bool = _current_tick % _turn_length == 0
	var have_timeslot: bool = _timeslot_map.has(_current_tick)
	
	if need_timeslot && !have_timeslot:
		return

	if need_timeslot:
		var timeslot: Array = _timeslot_map[_current_tick]
		_timeslot_map.erase(_current_tick)

		for action in timeslot:
			_execute_action(action)

		var time_to_send_checksum: bool = _current_tick % CHECKSUM_PERIOD_TICKS == 0
		if time_to_send_checksum:
			var checksum: PackedByteArray = _calculate_game_state_checksum()
			_game_host.receive_timeslot_checksum.rpc_id(1, _current_tick, checksum)

	_update_state()
	_current_tick += 1


func _calculate_game_state_checksum():
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)

	var game_state: PackedByteArray = PackedByteArray()

	# Store all values for desync debugging
	var checksum_data: Dictionary = {
		"players": [],
		"towers": [],
	}

	var player_list: Array[Player] = PlayerManager.get_player_list()

	for player in player_list:
		var total_damage: int = floori(player.get_total_damage())
#		NOTE: hash centiunit accumulators directly (not floori of
#		the divided float) so sub-unit divergence cannot hide.
		var gold_farmed: int = player.get_gold_farmed_centi()
		var gold: int = player.get_gold_centi()
		var tomes: int = player.get_tomes()
		var lives: int = player.get_team().get_lives_centi()
		var level: int = player.get_team().get_level()

		game_state.append(total_damage)
		game_state.append(gold_farmed)
		game_state.append(gold)
		game_state.append(tomes)
		game_state.append(lives)
		game_state.append(level)

		checksum_data["players"].append({
			"id": player.get_id(),
			"name": player.get_player_name(),
			"total_damage": total_damage,
			"gold_farmed": gold_farmed,
			"gold": gold,
			"tomes": tomes,
			"lives": lives,
			"level": level,
		})

	# Include tower state to catch tower-related desyncs
	# NOTE: tower_list is already sorted by UID in Utils.get_tower_list()
	var tower_list: Array[Tower] = Utils.get_tower_list()
	for tower in tower_list:
		var tower_uid: int = tower.get_uid()
		var tower_id: int = tower.get_id()
		var tower_level: int = tower.get_level()
		var tower_exp: int = tower.get_exp_centi()

		game_state.append(tower_uid)
		game_state.append(tower_id)
		game_state.append(tower_level)
		game_state.append(tower_exp)

		var tower_data: Dictionary = {
			"uid": tower_uid,
			"id": tower_id,
			"level": tower_level,
			"exp": tower_exp,
			"owner_id": tower.get_player().get_id(),
			"items": [],
		}

		# Include item state to catch item-related desyncs
		var item_list: Array[Item] = tower.get_item_container().get_item_list()
		Utils.sort_objects_for_multiplayer(item_list)

		for item in item_list:
			var item_id: int = item.get_id()
			var item_uid: int = item.get_uid()
			var item_charges: int = item.get_charges()
			var item_user_int: int = item.user_int
			var item_user_int2: int = item.user_int2
			var item_user_int3: int = item.user_int3
			var item_user_real: int = floori(item.user_real)
			var item_user_real2: int = floori(item.user_real2)
			var item_user_real3: int = floori(item.user_real3)

			game_state.append(item_id)
			game_state.append(item_uid)
			game_state.append(item_charges)
			game_state.append(item_user_int)
			game_state.append(item_user_int2)
			game_state.append(item_user_int3)
			game_state.append(item_user_real)
			game_state.append(item_user_real2)
			game_state.append(item_user_real3)

			tower_data["items"].append({
				"uid": item_uid,
				"id": item_id,
				"charges": item_charges,
				"user_int": item_user_int,
				"user_int2": item_user_int2,
				"user_int3": item_user_int3,
				"user_real": item_user_real,
				"user_real2": item_user_real2,
				"user_real3": item_user_real3,
			})

		checksum_data["towers"].append(tower_data)

	ctx.update(game_state)

	var checksum: PackedByteArray = ctx.finish()

	# Store checksum data for this tick
	_checksum_data_map[_current_tick] = checksum_data

	# Clean up old checksum data (keep last 10 ticks)
	# NOTE: sort keys to ensure deterministic iteration order for multiplayer sync
	var ticks_to_remove: Array = []
	var sorted_checksum_ticks: Array = _checksum_data_map.keys()
	sorted_checksum_ticks.sort()
	for tick in sorted_checksum_ticks:
		if tick < _current_tick - CHECKSUM_PERIOD_TICKS * 10:
			ticks_to_remove.append(tick)
	for tick in ticks_to_remove:
		_checksum_data_map.erase(tick)

	return checksum


# NOTE: need to implement this with a match statement
# because action is a plain Dictionary passed via RPC. Doing
# this via dynamic dispatch is not possible because it's not
# possible to pass custom classes through RPC. Also, some
# execute()'s require extra args like "map" which is a
# further obstruction.
func _execute_action(action: Dictionary):
	var player_id: int = action[Action.Field.PLAYER_ID] as int
	var player: Player = PlayerManager.get_player(player_id)

	if player == null:
		push_error("player is null")
		
		return

	var action_type: Action.Type = action[Action.Field.TYPE]

	match action_type:
		Action.Type.IDLE: return
		Action.Type.CHAT: ActionChat.execute(action, player, _hud, _chat_commands)
		Action.Type.BUILD_TOWER: ActionBuildTower.execute(action, player, _build_space)
		Action.Type.UPGRADE_TOWER: ActionUpgradeTower.execute(action, player, _select_unit)
		Action.Type.TRANSFORM_TOWER: ActionTransformTower.execute(action, player)
		Action.Type.SELL_TOWER: ActionSellTower.execute(action, player, _build_space)
		Action.Type.SELECT_BUILDER: ActionSelectBuilder.execute(action, player)
		Action.Type.TOGGLE_AUTOCAST: ActionToggleAutocast.execute(action, player)
		Action.Type.CONSUME_ITEM: ActionConsumeItem.execute(action, player)
		Action.Type.DROP_ITEM: ActionDropItem.execute(action, player)
		Action.Type.MOVE_ITEM: ActionMoveItem.execute(action, player)
		Action.Type.SWAP_ITEMS: ActionSwapItems.execute(action, player)
		Action.Type.AUTOFILL: ActionAutofill.execute(action, player)
		Action.Type.TRANSMUTE: ActionTransmute.execute(action, player)
		Action.Type.RESEARCH_ELEMENT: ActionResearchElement.execute(action, player)
		Action.Type.ROLL_TOWERS: ActionRollTowers.execute(action, player)
		Action.Type.START_NEXT_WAVE: ActionStartNextWave.execute(action, player)
		Action.Type.AUTOCAST: ActionAutocast.execute(action, player)
		Action.Type.FOCUS_TARGET: ActionFocusTarget.execute(action, player)
		Action.Type.CHANGE_BUFFGROUP: ActionChangeBuffgroup.execute(action, player)
		Action.Type.SELECT_WISDOM_UPGRADES: ActionSelectWisdomUpgrades.execute(action, player)
		Action.Type.SELECT_UNIT: ActionSelectUnit.execute(action, player)
		Action.Type.SORT_ITEM_STASH: ActionSortItemStash.execute(action, player)


func _update_state():
#	NOTE: the pause is implemented this way so that all game
#	objects/timers are paused but chat commands are still
#	processed so that /unpause command can go through. Note
#	that game host still continues to tick and send
#	timeslots.
	if _paused_by_host:
		return

	_game_time.update(_tick_delta)

#	NOTE: use separate groups so that update() calls are
#	ordered by type. This makes gameplay logic more
#	consistent.
	var timer_list: Array = GroupManager.get_ordered("manual_timers")
	var creep_list: Array = GroupManager.get_ordered("creeps")
	var projectile_list: Array = GroupManager.get_ordered("projectiles")
	var tower_list: Array = GroupManager.get_ordered("towers")
	var node_list: Array = []
	node_list.append_array(timer_list)
	node_list.append_array(creep_list)
	node_list.append_array(projectile_list)
	node_list.append_array(tower_list)

# 	NOTE: need to check is_inside_tree() because nodes may
# 	get removed during iteration. For example, timer_list is
# 	obtained once before iteration starts. Then timer A
# 	triggers an explosion which kills a creep which carries
# 	timer B. Timer B is now outside tree but still inside
# 	timer_list!
	for node in node_list:
#		NOTE: is_instance_valid() must come first - the others
#		can't be called on a freed instance. GroupManager already
#		filters freed nodes, but guard defensively here too.
		var should_update: bool = is_instance_valid(node) && node.is_inside_tree() && !node.is_queued_for_deletion()
		if !should_update:
			continue

		node.update(_tick_delta)


func _get_ping_average() -> float:
	var sum: float = 0

	for ping in _ping_history:
		sum += ping

	var ping_average: float = sum / _ping_history.size()

	return ping_average


func _get_ping_max() -> float:
	var ping_max: float = 0

	for ping in _ping_history:
		ping_max = max(ping_max, ping)

	return ping_max


#########################
###     Callbacks     ###
#########################

# Periodically send a ping from client to host. This ping is
# used to calculate ping time. It also carries the highest tick
# this client has received, letting the host drop every timeslot
# up to that mark from its per-player send queue.
func _on_ping_timer_timeout():
	_time_when_sent_ping = Time.get_ticks_msec()
	_game_host.receive_ping.rpc_id(1, _max_received_tick)
