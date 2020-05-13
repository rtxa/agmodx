#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>
#include <agmodx_const>

#define PLUGIN  "AG Mod X Instagib"
#define VERSION "Beta 2.2"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "instagib"

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

	RemoveGamePlayerEquip();
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
/*
* Removes game player equipment of the map
*/
bool:RemoveGamePlayerEquip() {
	new ent;
	while ((ent = find_ent_by_class(ent, "game_player_equip"))) {
		// ignore the ones with use flag, they don't give weapons to all players
		if (!(pev(ent, pev_spawnflags) & SF_PLAYEREQUIP_USEONLY)) {
			remove_entity(ent);
			return true;
		}
	}
	return false;
}

