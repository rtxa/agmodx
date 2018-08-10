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

#define FLAG_BLUESKIN 0
#define FLAG_REDSKIN 1

enum _:FlagSequences {
	FLAG_ONGROUND,
	FLAG_NOTCARRIED,
	FLAG_CARRIED
}

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

new Float:gSpawnFlagBlue[3];
new Float:gSpawnFlagRed[3];

public plugin_precache() {
	precache_model(gFlagMdl);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_clcmd("dropflag", "CmdDropFlag");

	RegisterHam(Ham_Spawn, "player", "FwPlayerSpawn", true);

	SpawnFlag(gSpawnFlagBlue, BLUE_TEAM);
	SpawnFlag(gSpawnFlagRed, RED_TEAM);

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

public FwPlayerSpawn(id) {
	new team = hl_get_user_team(id);
	new spawn;
	server_print("Team %i", team);

	if (team == BLUE_TEAM) {
		if ((spawn = FindSpawnForPlayer(BLUE_TEAM)) >= 0)
			TeleportToSpawn(id, gSpawnsBlue[spawn]);
		else
			user_kill(id, true);
	} else if (team == RED_TEAM)
		if ((spawn = FindSpawnForPlayer(RED_TEAM)) >= 0)
			TeleportToSpawn(id, gSpawnsRed[spawn]);
		else
			user_kill(id, true);
			
	return HAM_IGNORED;
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

public FwRedFlagTouch() {
	// attach flag to user, show message that team has pick up the flag
	server_print("RedFlagTouched");
}

public FwBlueFlagTouch() {
	server_print("BlueFlagTouched");
}

public CmdDropFlag(id, level, cid) {
	server_print("numspawn blue: %i red: %i", gNumSpawnsBlue, gNumSpawnsRed);
	return PLUGIN_HANDLED;
}

public SpawnFlag(const Float:origin[3], team) {
	new flag = create_entity("info_target");

	entity_set_model(flag, gFlagMdl);
	set_pev(flag, pev_movetype, MOVETYPE_TOSS);
	set_pev(flag, pev_solid, SOLID_TRIGGER);
	set_pev(flag, pev_sequence, FLAG_NOTCARRIED);
	set_pev(flag, pev_framerate, 1.0);

	switch (team) {
		case BLUE_TEAM: {
			entity_set_origin(flag, gSpawnFlagBlue);
			set_pev(flag, pev_classname, gItemFlagBlue);
			set_pev(flag, pev_skin, FLAG_BLUESKIN);
			set_ent_rendering(flag, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
		} case RED_TEAM: {
			entity_set_origin(flag, gSpawnFlagRed);		
			set_pev(flag, pev_classname, gItemFlagRed);
			set_pev(flag, pev_skin, FLAG_REDSKIN);
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
			gSpawnFlagBlue = vector;
		}
	} else if (equal(classname, gItemFlagRed)) { // item_flag_team2
		if (equal(key, "origin")) {
			gSpawnFlagRed = vector;
		}
	}
}

CreateCustomEnt(const classname[]) {
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, classname);
	return ent;
}

// the parsed string is in this format "500.000 128.050 300.2"
Float:StrToVec(const string[], Float:vector[3]) {
	new arg[3][12]; // hold parsed vector
	parse(string, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

	for (new i; i < sizeof arg; i++)
		vector[i] = str_to_float(arg[i]);
}
