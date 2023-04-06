/obj/item/clothing/suit/armor/uss
	name = "USS Combat Vest"
	desc = "Standard Issue armor vest for USS operatives. This one has added Storage pouches."
	icon_state = ICON_STATE_WORLD
	icon = 'icons/clothing/suit/armor/uss.dmi'
	armor = list(
		ARMOR_MELEE = ARMOR_MELEE_KNIVES,
		ARMOR_BULLET = ARMOR_BALLISTIC_RESISTANT,
		ARMOR_LASER = ARMOR_LASER_HANDGUNS,
		ARMOR_ENERGY = ARMOR_ENERGY_SMALL,
		ARMOR_BOMB = ARMOR_BOMB_PADDED
		)
	starting_accessories = list(/obj/item/clothing/accessory/storage/pouches/large)