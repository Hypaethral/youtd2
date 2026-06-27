extends ItemBehavior


var multiboard: MultiboardValues


func load_triggers(triggers: BuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	multiboard = MultiboardValues.new(1)
	var attack_speed_increase_label: String = tr("RWPC")
	multiboard.set_key(0, attack_speed_increase_label)

func on_attack(event: Event):
	var target_id = event.get_target().get_uid()
	var carrier = item.get_carrier()

	# Convert stored value to integer percent (0–100)
	var bonus = int(item.user_real * 100.0)

	var delta: int = 0

	if item.user_int == target_id:
		# Same target: ramp up attack speed bonus
		if bonus < 100 && bonus + 2 > 100:
			delta = 100 - bonus
			bonus = 100
		elif bonus < 100:
			delta = 2
			bonus += 2
		else:
			delta = 0
	else:
		# Target switched: decay/scale bonus based on level
		item.user_int = target_id

		var prev_bonus = bonus

		var scale = 50 + carrier.get_level()

		# deterministic integer scaling:
		# bonus = bonus * scale / 100
		bonus = (bonus * scale) / 100

		delta = bonus - prev_bonus

	# commit state once
	item.user_real = float(bonus) / 100.0

	if delta != 0:
		carrier.modify_property(
			ModificationType.enm.MOD_ATTACKSPEED,
			float(delta) / 100.0
		)

func on_create():
	item.user_real = 0.00
	item.user_int = 0


func on_drop():
# 	Remove bonus
	item.get_carrier().modify_property(ModificationType.enm.MOD_ATTACKSPEED, -item.user_real)


func on_pickup():
#	Add bonus
	item.get_carrier().modify_property(ModificationType.enm.MOD_ATTACKSPEED, item.user_real)


func on_tower_details() -> MultiboardValues:
	var attack_speed_bonus_text: String = Utils.format_percent(item.user_real, 0)
	multiboard.set_value(0, attack_speed_bonus_text)

	return multiboard
