GLOBAL_LIST_EMPTY(computer_networks)

/datum/computer_network
	var/network_id
	var/network_key

	var/list/devices = list()
	var/list/devices_by_tag = list()

	var/list/mainframes = list()
	var/list/mainframes_by_role = list()

	var/datum/extension/network_device/router/router

	var/network_features_enabled = NETWORK_ALL_FEATURES
	var/intrusion_detection_enabled
	var/intrusion_detection_alarm
	var/list/banned_nids = list()
	var/global/list/all_software_categories
	var/list/chat_channels = list()

/datum/computer_network/New(var/new_id)
	if(!new_id)
		new_id = "network[random_id(type, 100,999)]"
	network_id = new_id
	GLOB.computer_networks[network_id] = src

/datum/computer_network/Destroy()
	for(var/datum/extension/network_device/D in devices)
		D.disconnect()
	QDEL_NULL(chat_channels)
	devices = null
	mainframes = null
	. = ..()

/datum/computer_network/proc/add_device(datum/extension/network_device/D)
	if(D.network_id != network_id)
		return FALSE
	if(D.key != network_key)
		return FALSE
	if(D in devices)
		return TRUE
	D.network_tag = get_unique_tag(D.network_tag)
	devices |= D
	devices_by_tag[D.network_tag] = D
	if(istype(D, /datum/extension/network_device/mainframe))
		var/datum/extension/network_device/mainframe/M = D
		mainframes |= M
		for(var/role in M.roles)
			LAZYDISTINCTADD(mainframes_by_role[role], M)
		add_log("Mainframe ONLINE with roles: [english_list(M.roles)]", D.network_tag)
	return TRUE

/datum/computer_network/proc/remove_device(datum/extension/network_device/D)
	devices -= D
	devices_by_tag -= D.network_tag
	if(D in mainframes)
		var/datum/extension/network_device/mainframe/M = D
		mainframes -= M
		for(var/role in mainframes_by_role)
			LAZYREMOVE(mainframes_by_role[role], M)
		add_log("Mainframe OFFLINE with roles: [english_list(M.roles)]", M.network_tag)
	if(D == router)
		router = null
		for(var/datum/extension/network_device/router/R in devices)
			router = R
			add_log("Router offline, falling back to router '[R.network_tag]'", R.network_tag)
			break
		if(!router)
			add_log("Router offline, network shutting down", D.network_tag)
			qdel(src)
	return TRUE

/datum/computer_network/proc/get_unique_tag(nettag)
	while(get_device_by_tag(nettag))
		nettag += "-[sequential_id(nettag)]"
	return nettag

/datum/computer_network/proc/update_device_tag(datum/extension/network_device/D, old_tag, new_tag)
	devices_by_tag -= old_tag
	devices_by_tag[new_tag] = D

/datum/computer_network/proc/set_router(datum/extension/network_device/D)
	router = D
	network_key = router.key
	change_id(router.network_id)
	devices |= D
	add_log("New main router set", router.network_tag)

/datum/computer_network/proc/check_connection(datum/extension/network_device/D, specific_action)
	if(!router)
		return FALSE
	var/obj/machinery/M = router.holder
	if(istype(M) && !M.operable())
		return FALSE
	if(specific_action && !(network_features_enabled & specific_action))
		return FALSE
	return ARE_Z_CONNECTED(get_z(router.holder), get_z(D.holder))

/datum/computer_network/proc/get_signal_strength(datum/extension/network_device/D)
	if(!check_connection(D))
		return 0
	var/broadcast_strength = router.get_broadcast_strength()
	var/distance = get_dist(get_turf(router.holder), get_turf(D.holder))
	var/receiver_strength = D.connection_type
	return (broadcast_strength * receiver_strength) - distance

/datum/computer_network/proc/get_device_by_tag(nettag)
	return devices_by_tag[nettag]

/datum/computer_network/proc/change_id(new_id)
	if(new_id == network_id)
		return
	for(var/datum/extension/network_device/D in devices)
		if(D.network_id != new_id)
			D.network_id = new_id
	GLOB.computer_networks -= network_id
	add_log("Network ID was changed from '[network_id]' to '[new_id]'")
	network_id = new_id
	GLOB.computer_networks[network_id] = src

/datum/computer_network/proc/enable_network_feature(feature)
	network_features_enabled |= feature

/datum/computer_network/proc/disable_network_feature(feature)
	network_features_enabled &= ~feature

/datum/computer_network/proc/update_mainframe_roles(datum/extension/network_device/mainframe/M)
	if(!(M in mainframes))
		return FALSE
	
	for(var/role in mainframes_by_role)
		LAZYREMOVE(mainframes_by_role[role], M)
	for(var/role in M.roles)
		LAZYDISTINCTADD(mainframes_by_role[role], M)
		
	add_log("Mainframe roles updated, now: [english_list(M.roles)]", M.network_tag)

/datum/computer_network/proc/get_os_by_nid(nid)
	for(var/datum/extension/network_device/D in devices)
		if(D.address == uppertext(nid))
			var/datum/extension/interactive/ntos/os = get_extension(D.holder, /datum/extension/interactive/ntos)
			if(!os)
				var/atom/A = D.holder
				os = get_extension(A.loc, /datum/extension/interactive/ntos)
			return os

/datum/computer_network/proc/get_router_z()
	if(router)
		return get_z(router.holder)

// TODO: Some way to set what network it should be, based on map vars or overmap vars
/proc/get_local_network_at(turf/T)
	for(var/id in GLOB.computer_networks)
		var/datum/computer_network/net = GLOB.computer_networks[id]
		if(net.router && ARE_Z_CONNECTED(get_z(net.router.holder), get_z(T)))
			return net