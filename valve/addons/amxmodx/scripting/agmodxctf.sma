#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <hl>
// #include <amxmisc>
// #include <fun>
// #include <xs>
// #include <sqlx>

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

// maybe we can reutilize some entities, but anyway keep it compatible with ag maps...
// cs 1.6 uses info_player_start and info_player_deathmatch for team 1 and 2, and because in ag there is no team 3 and 4...
new const gInfoPlayerBlue[] = "info_player_team1";
new const gInfoPlayerRed[] = "info_player_team2";

new const gItemFlagBlue[] = "item_flag_team1";
new const gItemFlagRed[] = "item_flag_team2";

new const gFlagMdl[] = "models/ctf/flag.mdl";

new gSpawnsBlue[64];
new gSpawnsRed[64];

new gNumSpawnsRed;
new gNumSpawnsBlue;

new Float:gOriginFlagBlue[3];
new Float:gOriginFlagRed[3];
new gFlagBlue;
new gFlagRed;

public plugin_precache() {
	precache_model(gFlagMdl);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_clcmd("dropflag", "CmdDropFlag");

	RegisterHam(Ham_Spawn, "player", "FwPlayerSpawn", true);

	gFlagBlue = SpawnFlag(gOriginFlagBlue, BLUE_TEAM);
	gFlagRed = SpawnFlag(gOriginFlagRed, RED_TEAM);

	register_touch(gItemFlagBlue, "player", "FwBlueFlagTouch");
	register_touch(gItemFlagRed, "player", "FwRedFlagTouch");
}

/*public plugin_cfg() {
	new mode[32];
	get_cvar_string("sv_ag_gamemode", mode, charsmax(mode));

	if (!equal(mode, "ctf"))
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}*/


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

public FwRedFlagTouch(touched, toucher) {
	// attach flag to user, show message that team has pick up the flag
	server_print("RedFlagTouched");

	switch (hl_get_user_team(toucher)) {
		case RED_TEAM: return PLUGIN_HANDLED; // later we have to add that player can return his flag to base or return flag after 30s
		case BLUE_TEAM: AttachFlagToPlayer(toucher, touched);
	}

	return PLUGIN_CONTINUE;
}

public FwBlueFlagTouch(touched, toucher) {
	server_print("BlueFlagTouched");

	switch (hl_get_user_team(toucher)) {
		case BLUE_TEAM: return PLUGIN_HANDLED;
		case RED_TEAM: AttachFlagToPlayer(toucher, touched);
	}

	return PLUGIN_CONTINUE;	
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
	set_pev(flag, pev_angles, 0);
	entity_set_origin(flag, origin);
	drop_to_floor(flag);
}

bool:IsPlayerCarryingFlag(id, team) {
	server_print("IsPlayerCarringFlag");
	new bool:status;
	switch (team) {
		case BLUE_TEAM: status = pev(gFlagRed, pev_aiment) == id ? true :  false;
		case RED_TEAM:  status = pev(gFlagBlue, pev_aiment) == id ? true :  false;
	}

	return status;
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

	if (IsPlayerCarryingFlag(id, team))
		DropFlag(team);

	return PLUGIN_HANDLED;
}

public SpawnFlag(const Float:origin[3], team) {
	new flag = create_entity("info_target");

	entity_set_model(flag, gFlagMdl);
	set_pev(flag, pev_movetype, MOVETYPE_TOSS);
	set_pev(flag, pev_solid, SOLID_TRIGGER);
	set_pev(flag, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(flag, pev_framerate, 1.0);

	switch (team) {
		case BLUE_TEAM: {
			entity_set_origin(flag, gOriginFlagBlue);
			set_pev(flag, pev_classname, gItemFlagBlue);
			set_pev(flag, pev_skin, FLAG_SKIN_BLUE);
			set_ent_rendering(flag, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
		} case RED_TEAM: {
			entity_set_origin(flag, gOriginFlagRed);		
			set_pev(flag, pev_classname, gItemFlagRed);
			set_pev(flag, pev_skin, FLAG_SKIN_RED);
			set_ent_rendering(flag, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30);
		}
	}

	return flag;
}

/* Get data of entities from ag ctf map
 */
public pfn_keyvalue(entid) {	
	new classname[32], key[8], value[42];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);

	new Float:vector[3];
	StrToVec(value, vector);

	if (equal(classname, gInfoPlayerBlue)) { // info_player_team1
		if (equal(key, "origin")) {
			gSpawnsBlue[gNumSpawnsBlue] = CreateCustomEnt(gInfoPlayerBlue);
			entity_set_origin(gSpawnsBlue[gNumSpawnsBlue], vector);
			gNumSpawnsBlue++;
		} else if (equal(key, "angles")) {
			set_pev(gSpawnsBlue[gNumSpawnsBlue - 1], pev_angles, vector);
		}
	} else if (equal(classname, gInfoPlayerRed)) { // info_player_team2
		if (equal(key, "origin")) {
			gSpawnsRed[gNumSpawnsRed] = CreateCustomEnt(gInfoPlayerRed);
			entity_set_origin(gSpawnsRed[gNumSpawnsRed], vector);
			gNumSpawnsRed++;
		} else if (equal(key, "angles")) {
			set_pev(gSpawnsRed[gNumSpawnsRed - 1], pev_angles, vector);
		}
	} else if (equal(classname, gItemFlagBlue)) { // item_flag_team1
		if (equal(key, "origin")) {
			gOriginFlagBlue = vector;
		}
	} else if (equal(classname, gItemFlagRed)) { // item_flag_team2
		if (equal(key, "origin")) {
			gOriginFlagRed = vector;
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
