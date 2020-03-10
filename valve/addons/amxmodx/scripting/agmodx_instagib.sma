#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X Instagib"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "instagib"

// array size of some gamemode cvars
#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11 

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
new const gAgStartWeapons[SIZE_WEAPONS][] = {
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
new const gAgStartAmmo[SIZE_AMMO][] = {
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

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

public plugin_precache() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!IsSelectedMode(MODE_TYPE_NAME)) {
		StopPlugin();
		return;
	}

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	RegisterHamPlayer(Ham_Killed, "OnPlayerKilled_Pre");
	RegisterHamPlayer(Ham_TakeDamage, "OnPlayerTakeDamage_Pre");

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_gauss", "OnGaussPrimaryAttack_Pre", true);

	register_clcmd("drop", "CmdDrop");
}

public CmdDrop() {
	return PLUGIN_HANDLED;
}

public OnGaussPrimaryAttack_Pre(this) {
	set_ent_data_float(this, "CBasePlayerWeapon", "m_flNextPrimaryAttack", 1.0);
	return HAM_SUPERCEDE;
}

public OnPlayerTakeDamage_Pre(victim, inflictor, attacker, Float:damage, damagetype) {
	if (attacker != 0)
		SetHamParamFloat(4, 1000.0);
	return HAM_IGNORED;
}

public OnPlayerKilled_Pre(victim, attacker) {
	if (is_user_alive(attacker)) {
		ResetBpAmmo(attacker);
	}
}

ResetBpAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // only restore backpack ammo set in game_player_equip from the map
			set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_pcvar_num(gCvarStartAmmo[i]), i + 1);
	}
}
