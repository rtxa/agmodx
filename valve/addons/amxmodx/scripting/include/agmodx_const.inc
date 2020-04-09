#if defined _agmodx_const_included
	#endinput
#endif
#define _agmodx_const_included

// array size of some gamemode cvars
#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11 
#define SIZE_DMGWEAPONS 16

#define SIZE_BANWEAPONS 14
#define SIZE_AMMOENTS 9

// index array
enum _:AgStartWeapons {
	START_357,
	START_9MMAR,
	START_9MMHANDGUN,
	START_CROSSBOW,
	START_CROWBAR,
	START_EGON,
	START_GAUSS,
	START_HGRENADE,
	START_HORNETGUN,
	START_RPG,
	START_SATCHEL,
	START_SHOTGUN,
	START_SNARK,
	START_TRIPMINE
}

// cvars names
stock const gAgStartWeapons[SIZE_WEAPONS][] = {
	"sv_ag_start_357",
	"sv_ag_start_9mmar",
	"sv_ag_start_9mmhandgun",
	"sv_ag_start_crossbow",
	"sv_ag_start_crowbar",
	"sv_ag_start_gauss",
	"sv_ag_start_egon",
	"sv_ag_start_hgrenade",
	"sv_ag_start_hornetgun",
	"sv_ag_start_rpg",
	"sv_ag_start_satchel",
	"sv_ag_start_shotgun",
	"sv_ag_start_snark",
	"sv_ag_start_tripmine",
};

// cvars names
stock const gAgStartAmmo[SIZE_AMMO][] = {
	"sv_ag_start_ammo_shotgun",
	"sv_ag_start_ammo_9mm",
	"sv_ag_start_ammo_m203",
	"sv_ag_start_ammo_357",
	"sv_ag_start_ammo_gauss",
	"sv_ag_start_ammo_rpg",
	"sv_ag_start_ammo_crossbow",
	"sv_ag_start_ammo_tripmine",
	"sv_ag_start_ammo_satchel",
	"sv_ag_start_ammo_hgrenade",
	"sv_ag_start_ammo_snark",
};

// cvars names
stock const gAgBanWeapons[SIZE_BANWEAPONS][] = {
	"sv_ag_ban_357",
	"sv_ag_ban_9mmar",
	"sv_ag_ban_9mmhandgun",
	"sv_ag_ban_crossbow",
	"sv_ag_ban_crowbar",
	"sv_ag_ban_gauss",
	"sv_ag_ban_egon",
	"sv_ag_ban_hgrenade",
	"sv_ag_ban_hornetgun",
	"sv_ag_ban_rpg",
	"sv_ag_ban_satchel",
	"sv_ag_ban_shotgun",
	"sv_ag_ban_snark",
	"sv_ag_ban_tripmine",	
};	

// cvars names
stock const gAgBanAmmo[SIZE_AMMOENTS][] = {
	"sv_ag_ban_ammo_357",		
	"sv_ag_ban_ammo_9mm",
	"sv_ag_ban_ammo_9mm",	
	"sv_ag_ban_ammo_9mm",		
	"sv_ag_ban_ammo_m203",	
	"sv_ag_ban_ammo_crossbow",	
	"sv_ag_ban_ammo_gauss",	
	"sv_ag_ban_ammo_rpg",		
	"sv_ag_ban_ammo_shotgun"	
};

// countdown sounds
stock const gCountSnd[][] = {
	"barney/ba_bring", // zero
	"fvox/one", 
	"fvox/two", 
	"fvox/three", 
	"fvox/four", 
	"fvox/five", 
	"fvox/six", 
	"fvox/seven", 
	"fvox/eight", 
	"fvox/nine"
};

stock const gMpDmgWeapons[][] = {
	"mp_dmg_crowbar",
	"mp_dmg_glock",
	"mp_dmg_357",
	"mp_dmg_mp5",
	"mp_dmg_shotgun",
	"mp_dmg_xbow_scope",
	"mp_dmg_xbow_noscope",
	"mp_dmg_rpg",
	"mp_dmg_gauss_primary",
	"mp_dmg_gauss_secondary",
	"mp_dmg_egon",
	"mp_dmg_hornet",
	"mp_dmg_hgrenade",
	"mp_dmg_satchel",
	"mp_dmg_tripmine",
	"mp_dmg_m203",
}

stock const gAgDmgWeapons[][] = {
	"sv_ag_dmg_crowbar",
	"sv_ag_dmg_glock",
	"sv_ag_dmg_357",
	"sv_ag_dmg_mp5",
	"sv_ag_dmg_shotgun",
	"sv_ag_dmg_crossbow",
	"sv_ag_dmg_bolts",
	"sv_ag_dmg_rpg",
	"sv_ag_dmg_gauss",
	"sv_ag_dmg_gauss_secondary",
	"sv_ag_dmg_egon_wide",
	"sv_ag_dmg_hornet",
	"sv_ag_dmg_hgrenade",
	"sv_ag_dmg_satchel",
	"sv_ag_dmg_tripmine",
	"sv_ag_dmg_m203",
}

stock const gBeepSnd[] = "fvox/beep";
