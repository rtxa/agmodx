#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X SgBow"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

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

new bool:gIsSelectedMode;

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

stock StopPlugin() {
	new pluginName[32];
	get_plugin(-1, pluginName, sizeof(pluginName));
	pause("d", pluginName);
	return;
}

// To do: use a native to check if ag mod x is on, or to check if normal ag mod is being use
bool:IsSelectedMode() {
	new type[32];
	get_cvar_string("sv_ag_gametype", type, charsmax(type));

	if (equal(type, "sgbow"))
		return true;

	return false;
}

public ReplaceWeapons() {
	new num, ents[128];

	// Replace egon with uranium

	GetAllEntsByClass("weapon_egon", ents, sizeof(ents), num);

	ReplaceAllEntsWith(ents, num, "ammo_gaussclip");

	// Replace mp5 and hornetgun with shotgun

	arrayset(ents, 0, sizeof(ents));
	num = 0;

	GetAllEntsByClass("weapon_9mmAR", ents, sizeof(ents), num);
	GetAllEntsByClass("weapon_hornetgun", ents, sizeof(ents), num);

	ReplaceAllEntsWith(ents, num, "weapon_shotgun");

	// Replace rpg and snarks with crossbow

	arrayset(ents, 0, sizeof(ents));
	num = 0;

	GetAllEntsByClass("weapon_rpg", ents, sizeof(ents), num);
	GetAllEntsByClass("weapon_snark", ents, sizeof(ents), num);

	ReplaceAllEntsWith(ents, num, "weapon_crossbow");
}

public plugin_precache() {
	// maybe add a check to detect ag mod x is on, if it's on, then it means all cvars are registred and safe to use, or in plugins.ini this always has to be after
	gIsSelectedMode = IsSelectedMode();

	if (!gIsSelectedMode) {
		StopPlugin();
		return;
	}

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!gIsSelectedMode) {
		return;
	}

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_gauss", "OnGaussPrimaryAttack_Pre");
	RegisterHamPlayer(Ham_TraceAttack, "OnPlayerTraceAttack_Pre");

	register_clcmd("drop", "CmdDrop");

	ReplaceWeapons();
}

public CmdDrop() {
	return PLUGIN_HANDLED;
}

public OnPlayerTraceAttack_Pre(victim, attacker, Float:damage, Float:direction[3], tr, damagetype) {
	new classname[32];
	pev(attacker, pev_classname, classname, charsmax(classname));

	if (equal(classname, "player")) {
		if (get_user_weapon(attacker) == HLW_GAUSS) {
				return HAM_SUPERCEDE;
		}
	}

	if (equal(classname, "weapon_gauss")) {
			return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public OnGaussPrimaryAttack_Pre(this) {
	return HAM_SUPERCEDE;
}

stock GetAllEntsByClass(const classname[], ents[], size, &num) {
	new idx;
	while (num < size && (ents[num] = find_ent_by_class(idx, classname))) {
		idx = ents[num];
		num++;
	}
}

stock ReplaceAllEntsWith(ents[], num, const classname[]) {
	new Float:origin[3];
	for (new i; i < num; i++) {
		pev(ents[i], pev_origin, origin);
		remove_entity(ents[i]);

		ents[i] = create_entity(classname);
		entity_set_origin(ents[i], origin);
		DispatchSpawn(ents[i]);
	}
}
