#include <amxmodx>
#include <engine>
#include <fakemeta>
//#include <hamsandwich>
// #include <amxmisc>
// #include <fun>
// #include <xs>
// #include <sqlx>

#define PLUGIN  "AG Mod X CTF"
#define VERSION "1.0"
#define AUTHOR  "rtxa"

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

new Float:gSpawnsBlue[64][3]; // [num][origin]
new Float:gSpawnsRed[64][3]; // [num][origin]
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

public FwRedFlagTouch() {
	server_print("RedFlagTouched");
}

public FwBlueFlagTouch() {
	server_print("BlueFlagTouched");
}

public CmdDropFlag(id, level, cid) {
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
			set_pev(flag, pev_classname, gItemFlagBlue);
			set_pev(flag, pev_skin, FLAG_BLUESKIN);
			entity_set_origin(flag, gSpawnFlagBlue);
		} case RED_TEAM: {
			set_pev(flag, pev_classname, gItemFlagRed);
			set_pev(flag, pev_skin, FLAG_REDSKIN);
			entity_set_origin(flag, gSpawnFlagRed);		
		}
	}

	return flag;
}

/* Get data of entities from ag ctf map
 */
public pfn_keyvalue(entid) {	
	new classname[16], key[8], value[42];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);

	new Float:origin[3];
	if (equal(classname, gInfoPlayerBlue)) {
		if (equal(key, "origin")) {
			new arg[3][12]; // hold parsed origin
			parse(value, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

			for (new i; i < sizeof arg; i++)
				origin[i] = str_to_float(arg[i]);

			gSpawnsBlue[gNumSpawnsBlue] = origin;
			gNumSpawnsRed++;
		}
	}

	if (equal(classname, gInfoPlayerRed)) {
		if (equal(key, "origin")) {
			new arg[3][12]; // hold parsed origin
			parse(value, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

			for (new i; i < sizeof arg; i++)
				origin[i] = str_to_float(arg[i]);

			gSpawnsRed[gNumSpawnsRed] = origin;
			gNumSpawnsRed++;
		}
	}

	if (equal(classname, gItemFlagBlue)) {
		if (equal(key, "origin")) {
			new arg[3][12]; // hold parsed origin
			parse(value, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

			for (new i; i < sizeof arg; i++)
				origin[i] = str_to_float(arg[i]);

			gSpawnFlagBlue = origin;
		}
	}

	if (equal(classname, gItemFlagRed)) {
		if (equal(key, "origin")) {
			new arg[3][12]; // hold parsed origin
			parse(value, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

			for (new i; i < sizeof arg; i++)
				origin[i] = str_to_float(arg[i]);

			gSpawnFlagRed = origin;
		}
	}
}
