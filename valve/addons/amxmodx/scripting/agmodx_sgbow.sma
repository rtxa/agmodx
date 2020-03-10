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

#define MODE_TYPE_NAME "sgbow"

public plugin_precache() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!IsSelectedMode(MODE_TYPE_NAME)) {
		StopPlugin();
		return;
	}
}

public plugin_init() {
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