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

#define PLUGIN  "AG Mod X Arcade"
#define VERSION "Beta 2.4"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "arcade"

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

new gCvarStartHealth;
new gCvarStartArmor;

public plugin_precache() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!IsSelectedMode(MODE_TYPE_NAME)) {
		StopPlugin();
		return;
	}

	gCvarStartHealth = get_cvar_pointer("sv_ag_start_health");
	gCvarStartArmor = get_cvar_pointer("sv_ag_start_armour");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre");
	register_clcmd("drop", "CmdDrop");
}

public CmdDrop() {
	return PLUGIN_HANDLED;
}

public OnPlayerKilled_Pre(victim, attacker) {
	if (is_user_alive(attacker)) {
		set_user_health(attacker, get_pcvar_num(gCvarStartHealth));
		set_user_armor(attacker, get_pcvar_num(gCvarStartArmor));
		ResetBpAmmo(attacker);
		ResetWeaponClip(attacker);
	}
}

ResetBpAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // only restore backpack ammo set in game_player_equip from the map
			set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_pcvar_num(gCvarStartAmmo[i]), i + 1);
	}
}

ResetWeaponClip(id) {
	new weapon;
	if (get_pcvar_num(gCvarStartWeapons[START_RPG])) {
		if ((weapon = hl_user_has_weapon(id, HLW_RPG)))
			hl_set_weapon_ammo(weapon, 1);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_CROSSBOW])) {
		if ((weapon = hl_user_has_weapon(id, HLW_CROSSBOW)))
			hl_set_weapon_ammo(weapon, 5);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_9MMAR])) {
		if ((weapon = hl_user_has_weapon(id, HLW_MP5)))
			hl_set_weapon_ammo(weapon, 50);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_9MMHANDGUN])) {
		if ((weapon = hl_user_has_weapon(id, HLW_GLOCK)))
			hl_set_weapon_ammo(weapon, 17);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_357])) {
		if ((weapon = hl_user_has_weapon(id, HLW_PYTHON)))
			hl_set_weapon_ammo(weapon, 6);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_SHOTGUN])) {
		if ((weapon = hl_user_has_weapon(id, HLW_SHOTGUN)))
			hl_set_weapon_ammo(weapon, 8);
	}
}

