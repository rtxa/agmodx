#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <hl>

#define PLUGIN  "AG Mod X CTF"
#define VERSION "1.0"
#define AUTHOR  "rtxa"

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

#define BLUE_TEAM 1
#define RED_TEAM 2

#define FLAG_SKIN_BLUE 0
#define FLAG_SKIN_RED 1

#define FLAG_SEQ_NOTCARRIED 1
#define FLAG_SEQ_CARRIED 2

#define FLAG_STATUS_NOTCARRIED 0
#define FLAG_STATUS_CARRIED 1

new const INFO_PLAYER_BLUE[] = "info_player_team1";
new const INFO_PLAYER_RED[] = "info_player_team2";

new const INFO_FLAG_BLUE[] = "item_flag_team1";
new const INFO_FLAG_RED[] = "item_flag_team2";

new const ITEM_FLAG_BASE[] = "item_flag_base";

new const FLAG_MODEL[] = "models/ctf/flag.mdl";

new gSpawnsBlue[64];
new gSpawnsRed[64];

new gNumSpawnsRed;
new gNumSpawnsBlue;

new Float:gOriginFlagBlue[3];
new Float:gOriginFlagRed[3];
new Float:gAnglesFlagBlue[3];
new Float:gAnglesFlagRed[3];

new gFlagBlue;
new gFlagRed;
new gBaseBlue;
new gBaseRed;

public plugin_precache() {
	precache_model(FLAG_MODEL);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	new mode[32];
	get_cvar_string("sv_ag_gamemode", mode, charsmax(mode));

	if (!equal(mode, "ctf"))
		return;

	register_clcmd("dropflag", "CmdDropFlag");

	RegisterHam(Ham_Spawn, "player", "FwPlayerSpawn", true);

	gFlagBlue = SpawnFlag(gOriginFlagBlue, BLUE_TEAM);
	gFlagRed = SpawnFlag(gOriginFlagRed, RED_TEAM);
	gBaseBlue = SpawnBaseFlag(gOriginFlagBlue);
	gBaseRed = SpawnBaseFlag(gOriginFlagRed);

	register_touch(INFO_FLAG_BLUE, "player", "FwFlagTouch");
	register_touch(INFO_FLAG_RED, "player", "FwFlagTouch");
	register_touch(ITEM_FLAG_BASE, "player", "FwBaseFlagTouch");
}

public FwBaseFlagTouch(touched, toucher) {
	new team = hl_get_user_team(toucher);

	if (IsPlayerCarryingFlag(toucher)) {
		switch (team) {
			case BLUE_TEAM: {
				if (touched == gBaseBlue) {
					ReturnFlagToBase(gFlagRed, gOriginFlagRed);
					client_print(0, print_center, "EL equipo azul capturo la bandera");
				}
			} case RED_TEAM: {
				if (touched == gBaseRed) {
					ReturnFlagToBase(gFlagBlue, gOriginFlagBlue);
					client_print(0, print_center, "El equipo rojo capturo la bandera");
				}
			}
		}
	}
}

public FwPlayerSpawn(id) {
	new spawn, team = hl_get_user_team(id);

	switch (team) {
		case BLUE_TEAM: {
			if ((spawn = FindSpawnForPlayer(BLUE_TEAM)) != 1)
				TeleportToSpawn(id, gSpawnsBlue[spawn]);
			else
				user_kill(id, true);
		} case RED_TEAM: {
			if ((spawn = FindSpawnForPlayer(RED_TEAM)) != -1)
				TeleportToSpawn(id, gSpawnsRed[spawn]);
			else
				user_kill(id, true);				
		}
	}
}

public TeleportToSpawn(id, spawnEnt) {
	new Float:origin[3], Float:angle[3];

	// get origin and angle of spawn
	pev(spawnEnt, pev_origin, origin);
	pev(spawnEnt, pev_angles, angle);

	// teleport it
	entity_set_origin(id, origin);
	set_pev(id, pev_angles, angle);
	set_pev(id, pev_fixangle, 1);
}

// we need to change the random respawn algorithm, we have to check how gamedll do it
// when looking for random spawn, avoid the last spawn until there are no more spawns
FindSpawnForPlayer(team) {
	new rnd, attemps;

	if (team == BLUE_TEAM) {
		do {
			rnd = random(gNumSpawnsBlue);

			if (attemps++ > 10) {
				for (new i; i < gNumSpawnsBlue; i++)
					if (IsSpawnPointValid(gSpawnsBlue[i]))
						return i;
				return -1;
			}
		} while (!IsSpawnPointValid(gSpawnsBlue[rnd]))		
	} else if (team == RED_TEAM) {
		do {
			rnd = random(gNumSpawnsRed);

			if (attemps++ > 10) {
				for (new i; i < gNumSpawnsRed; i++)
					if (IsSpawnPointValid(gSpawnsRed[i]))
						return i;
				return -1;
			}
		} while (!IsSpawnPointValid(gSpawnsRed[rnd]))		
	}

	return rnd;
}

bool:IsSpawnPointValid(spawnEnt) {
	new ent, Float:origin[3];
	pev(spawnEnt, pev_origin, origin);

	while ((ent = find_ent_in_sphere(ent, origin, 10.0)))
		return !IsPlayer(ent) ? true : false;

	return true;
}

public FwFlagTouch(touched, toucher) {
	server_print("FlagTouched");

	new team = hl_get_user_team(toucher);

	if (touched == gFlagBlue) {
		if (team == RED_TEAM) {
			AttachFlagToPlayer(toucher, touched);
			client_print(0, print_center, "Blue flag has been taken!");
		}
	} else if (touched == gFlagRed) {
		if (team == BLUE_TEAM) {
			AttachFlagToPlayer(toucher, touched);
			client_print(0, print_center, "Red flag has been taken!");
		}
	}
}

AttachFlagToPlayer(id, flag) {
	set_pev(flag, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(flag, pev_aiment, id);
	set_pev(flag, pev_sequence, FLAG_SEQ_CARRIED);
	set_pev(flag, pev_solid, SOLID_NOT);
}

ReturnFlagToBase(flag, const Float:origin[3]) {
	server_print("ReturnFlagToBase");
	set_pev(flag, pev_aiment, 0);
	set_pev(flag, pev_movetype, MOVETYPE_TOSS);
	set_pev(flag, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(flag, pev_solid, SOLID_TRIGGER);
	if (flag == gFlagBlue)
		set_pev(flag, pev_angles, gAnglesFlagBlue);
	else if (flag == gFlagRed)
		set_pev(flag, pev_angles, gAnglesFlagRed);
	entity_set_origin(flag, origin);
	drop_to_floor(flag);
}

bool:IsPlayerCarryingFlag(id) {
	server_print("IsPlayerCarringFlag");

	if (pev(gFlagBlue, pev_aiment) == id || pev(gFlagRed, pev_aiment) == id)
		return true;
	else
		return false;
}

// until i make a function to drop the flag, just return it to the base...
public DropFlag(team) {
	if (team == BLUE_TEAM)
		ReturnFlagToBase(gFlagRed, gOriginFlagRed);
	else if (team == RED_TEAM)
		ReturnFlagToBase(gFlagBlue, gOriginFlagBlue);
}

public CmdDropFlag(id, level, cid) {
	server_print("CmdDropFlag");

	new team = hl_get_user_team(id);

	if (IsPlayerCarryingFlag(id))
		DropFlag(team);

	return PLUGIN_HANDLED;
}

public SpawnFlag(const Float:origin[3], team) {
	new flag = create_entity("info_target");

	entity_set_model(flag, FLAG_MODEL);
	set_pev(flag, pev_movetype, MOVETYPE_TOSS);
	set_pev(flag, pev_solid, SOLID_TRIGGER);
	set_pev(flag, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(flag, pev_framerate, 1.0);

	new Float:mins[3] = { 4.0, 4.0, 0.0 };
	new Float:maxs[3] = { 4.0, 4.0, 72.0 };
	entity_set_size(flag, mins, maxs);

	switch (team) {
		case BLUE_TEAM: {
			entity_set_origin(flag, gOriginFlagBlue);
			set_pev(flag, pev_classname, INFO_FLAG_BLUE);
			set_pev(flag, pev_skin, FLAG_SKIN_BLUE);
			set_ent_rendering(flag, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
			set_pev(flag, pev_angles, gAnglesFlagBlue);
		} case RED_TEAM: {
			entity_set_origin(flag, gOriginFlagRed);		
			set_pev(flag, pev_classname, INFO_FLAG_RED);
			set_pev(flag, pev_skin, FLAG_SKIN_RED);
			set_ent_rendering(flag, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30);
			set_pev(flag, pev_angles, gAnglesFlagRed);
		}
	}

	return flag;
}

// we need a base for the flag so players can score points when they capture...
public SpawnBaseFlag(const Float:origin[3]) {
	new base = create_entity("info_target");
	set_pev(base, pev_classname, ITEM_FLAG_BASE);
	
	entity_set_model(base, FLAG_MODEL);
	set_pev(base, pev_movetype, MOVETYPE_TOSS);
	set_pev(base, pev_solid, SOLID_TRIGGER);
	entity_set_origin(base, origin);
	set_pev(base, pev_effects, EF_NODRAW);

	new Float:mins[3] = { -8.0, -8.0, 0.0 };
	new Float:maxs[3] = { 8.0, 8.0, 8.0 };
	entity_set_size(base, mins, maxs);

	return base;
}

/* Get data of entities from ag ctf map
 */
public pfn_keyvalue(entid) {	
	new classname[32], key[8], value[42];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);

	new Float:vector[3];
	StrToVec(value, vector);

	if (equal(classname, INFO_PLAYER_BLUE)) { // info_player_team1
		if (equal(key, "origin")) {
			gSpawnsBlue[gNumSpawnsBlue] = CreateCustomEnt(INFO_PLAYER_BLUE);
			entity_set_origin(gSpawnsBlue[gNumSpawnsBlue], vector);
			gNumSpawnsBlue++;
		} else if (equal(key, "angles")) {
			set_pev(gSpawnsBlue[gNumSpawnsBlue - 1], pev_angles, vector);
		}
	} else if (equal(classname, INFO_PLAYER_RED)) { // info_player_team2
		if (equal(key, "origin")) {
			gSpawnsRed[gNumSpawnsRed] = CreateCustomEnt(INFO_PLAYER_RED);
			entity_set_origin(gSpawnsRed[gNumSpawnsRed], vector);
			gNumSpawnsRed++;
		} else if (equal(key, "angles")) {
			set_pev(gSpawnsRed[gNumSpawnsRed - 1], pev_angles, vector);
		}
	} else if (equal(classname, INFO_FLAG_BLUE)) { // item_flag_team1
		if (equal(key, "origin")) {
			gOriginFlagBlue = vector;
		} else if (equal(key, "angles")) {
			gAnglesFlagBlue = vector;
		}
	} else if (equal(classname, INFO_FLAG_RED)) { // item_flag_team2
		if (equal(key, "origin")) {
			gOriginFlagRed = vector;
		} else if (equal(key, "angles")) {
			gAnglesFlagRed = vector;
		}
	}
}

CreateCustomEnt(const classname[]) {
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, classname);
	return ent;
}

// the parsed string is in this format "x y z" e.g "128 0 256"
Float:StrToVec(const string[], Float:vector[3]) {
	new arg[3][12]; // hold parsed vector
	parse(string, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

	for (new i; i < sizeof arg; i++)
		vector[i] = str_to_float(arg[i]);
}
