#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hl>
#include <fun>

#define PLUGIN  "AG Mod X CTF"
#define VERSION "1.0"
#define AUTHOR  "rtxa"

#pragma semicolon 1

// TaskIDs
enum (+= 100) {
	TASK_RETURNFLAGTOBASE = 1000,
};

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

#define HL_MAX_TEAMNAME_LENGTH 16

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

new const INFO_CAPTURE_POINT[] = "info_capture_point";

new const FLAG_MODEL[] = "models/ctf/flag.mdl";

new const VOX_SOUNDS[][] = { "vox/endgame.wav", "vox/captured.wav", "vox/enemy.wav", "vox/flag.wav", "vox/returned.wav" };

new gIsMapCtf;

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

new gHudCtfMessage;
new gTeamListModels[HL_MAX_TEAMS][HL_MAX_TEAMNAME_LENGTH];

new gCvarCapturePoints;
new gCvarFlagReturnTime;

IsCtfMode() {
	new mode[32];
	get_cvar_string("sv_ag_gametype", mode, charsmax(mode));

	if (equal(mode, "ctf") && gIsMapCtf)
		return;
	else
		set_fail_state("Map not supported for CTF.");
}

public plugin_precache() {
	precache_model(FLAG_MODEL);

	for (new i; i < sizeof VOX_SOUNDS; i++)
		precache_sound(VOX_SOUNDS[i]);

	gCvarCapturePoints = create_cvar("sv_ag_ctf_capturepoints", "10");
	gCvarFlagReturnTime = create_cvar("sv_ag_ctf_flag_returntime", "30");

	return PLUGIN_CONTINUE;
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	IsCtfMode();

	register_dictionary("agmodxctf.txt");

	register_clcmd("dropitems", "CmdDropFlag");
	register_clcmd("spectate", "CmdSpectate");

	RegisterHam(Ham_Spawn, "player", "FwPlayerSpawn", true);
	RegisterHam(Ham_Killed, "player", "FwPlayerKilled");

	gFlagBlue = SpawnFlag(gOriginFlagBlue, BLUE_TEAM);
	gFlagRed = SpawnFlag(gOriginFlagRed, RED_TEAM);
	gBaseBlue = SpawnCapturePoint(gOriginFlagBlue);
	gBaseRed = SpawnCapturePoint(gOriginFlagRed);

	register_touch(INFO_FLAG_BLUE, "player", "FwFlagTouch");
	register_touch(INFO_FLAG_RED, "player", "FwFlagTouch");
	register_touch(INFO_CAPTURE_POINT, "player", "FwCapturePointTouch");

	gHudCtfMessage = CreateHudSyncObj();
	GetTeamListModels(gTeamListModels, HL_MAX_TEAMS);

	return PLUGIN_CONTINUE;
}

public client_disconnected(id) {
	DropFlag(id, IsPlayerCarryingFlag(id));	
}

public CmdSpectate(id) {
	set_task(0.1, "DropFlagSpec", id);
}

public AddPoints(id, points) {
	new frags = get_user_frags(id) + points;
	set_user_frags(id, frags);

	// show new score
	message_begin(MSG_BROADCAST, get_user_msgid("ScoreInfo"));
	write_byte(id);
	write_short(frags);
	write_short(hl_get_user_deaths(id));
	write_short(0);
	write_short(hl_get_user_team(id));
	message_end();
}

CtfHudMessage(id, const playerMsg[] = "", const teamMsg[] = "", const nonTeamMsg[] = "") {
	new teamName[16];
	hl_get_user_team(id, teamName, charsmax(teamName));
	
	set_hudmessage(255, 255, 255, -1.0, 0.75, 2, 0.03, 5.0, 0.03, 0.5);

	if (!equal(playerMsg, ""))
		ShowSyncHudMsg(id, gHudCtfMessage, "%L", LANG_PLAYER, playerMsg);

	new playersTeam[32], numTeam;
	get_players(playersTeam, numTeam, "ce", teamName);

	new player;
	if (!equal(teamMsg, "")) {
		for (new i; i < numTeam; i++) {
			player = playersTeam[i];
			if (player != id)
				ShowSyncHudMsg(player, gHudCtfMessage, "%L", LANG_PLAYER, teamMsg);
		}
	}

	new players[32], num;
	get_players(players, num, "c");

	if (!equal(nonTeamMsg, "")) {
		for (new i; i < num; i++) {
			player = players[i];

			if (!array_search(player, playersTeam, numTeam))		
				ShowSyncHudMsg(player, gHudCtfMessage, "%L", LANG_PLAYER, nonTeamMsg);
		}
	}
}

CtfTeamHudMessage(team, const teamMsg[], nonTeamMsg[]) {
	set_hudmessage(255, 255, 255, -1.0, 0.75, 2, 0.03, 5.0, 0.03, 0.5);

	new playersTeam[32], numTeam;
	get_players(playersTeam, numTeam, "ce", gTeamListModels[team - 1]);

	if (!equal(teamMsg, ""))
		for (new i; i < numTeam; i++)
			ShowSyncHudMsg(playersTeam[i], gHudCtfMessage, "%L", LANG_PLAYER, teamMsg);

	new players[32], num;
	get_players(players, num, "c");

	new player;
	if (!equal(nonTeamMsg, "")) {
		for (new i; i < num; i++) {
			player = players[i];

			if (!array_search(player, playersTeam, numTeam))		
				ShowSyncHudMsg(player, gHudCtfMessage, "%L", LANG_PLAYER, nonTeamMsg);
		}
	}

}

stock CtfSpeak(id, const playerSpk[] = "", const teamSpk[] = "", const nonTeamSpk[] = "") {
	if (!equal(playerSpk, ""))
		Speak(id, fmt("%L", id, playerSpk));

	new teamName[16];
	hl_get_user_team(id, teamName, charsmax(teamName));

	new playersTeam[32], numTeam;
	get_players(playersTeam, numTeam, "ce", teamName);


	new player;
	if (!equal(teamSpk, "")) {
		for (new i; i < numTeam; i++) {
			player = playersTeam[i];
			if (player != id)
				Speak(player, fmt("%L", player, teamSpk));
		}
	}

	new players[32], num;
	get_players(players, num, "c");

	if (!equal(nonTeamSpk, "")) {
		for (new i; i < num; i++) {
			player = players[i];

			if (!array_search(player, playersTeam, numTeam))		
				Speak(player, fmt("%L", player, nonTeamSpk));
		}
	}
}

stock CtfTeamSpeak(team, const teamSpk[] = "", const nonTeamSpk[] = "") {
	new playersTeam[32], numTeam;
	get_players(playersTeam, numTeam, "ce", gTeamListModels[team - 1]);
	
	new player;
	if (!equal(teamSpk, "")) {
		for (new i; i < numTeam; i++) {
			player = playersTeam[i];
			Speak(player, fmt("%L", player, teamSpk));
		}
	}

	new players[32], num;
	get_players(players, num, "c");

	if (!equal(nonTeamSpk, "")) {
		for (new i; i < num; i++) {
			player = players[i];

			if (!array_search(player, playersTeam, numTeam))		
				Speak(player, fmt("%L", player, nonTeamSpk));
		}
	}
}

stock Speak(id, const speak[]) {
	client_cmd(id, "speak ^"%s^"", speak);
}

public DropFlagSpec(id) {
	if (hl_get_user_spectator(id))
		DropFlag(id, IsPlayerCarryingFlag(id));
}

public FwCapturePointTouch(touched, toucher) {
	switch (IsPlayerCarryingFlag(toucher)) {
		case BLUE_TEAM: {
			if (touched == gBaseRed) {
				ReturnFlagToBase(gFlagBlue);
				AddPoints(toucher, get_pcvar_num(gCvarCapturePoints));
				CtfHudMessage(toucher, "CTF_YOUCAP", "CTF_TEAMCAP", "CTF_THEYCAP");
				CtfSpeak(toucher, "!CTF_YOUCAP", "!CTF_TEAMCAP", "!CTF_THEYCAP");
			}
		} case RED_TEAM: {
			if (touched == gBaseBlue) {
				ReturnFlagToBase(gFlagRed);
				AddPoints(toucher, get_pcvar_num(gCvarCapturePoints));
				CtfHudMessage(toucher, "CTF_YOUCAP", "CTF_TEAMCAP", "CTF_THEYCAP");
				CtfSpeak(toucher, "!CTF_YOUCAP", "!CTF_TEAMCAP", "!CTF_THEYCAP");
			}
		}
	}
}

public FwPlayerKilled(victim, attacker) {
	DropFlag(victim, IsPlayerCarryingFlag(victim));
}

public FwPlayerSpawn(id) {
	new spawn, team = hl_get_user_team(id);

	switch (team) {
		case BLUE_TEAM: {
			if ((spawn = FindSpawnForPlayer(BLUE_TEAM)) != -1)
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
		} while (!IsSpawnPointValid(gSpawnsBlue[rnd]));	
	} else if (team == RED_TEAM) {
		do {
			rnd = random(gNumSpawnsRed);

			if (attemps++ > 10) {
				for (new i; i < gNumSpawnsRed; i++)
					if (IsSpawnPointValid(gSpawnsRed[i]))
						return i;
				return -1;
			}
		} while (!IsSpawnPointValid(gSpawnsRed[rnd]));
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

	// block pick up when flag is in the air
	if (fm_distance_to_floor(touched) != 0.0)
		return PLUGIN_HANDLED;
	else if (!is_user_alive(toucher))
		return PLUGIN_HANDLED;

	new team = hl_get_user_team(toucher);

	if (touched == gFlagBlue) {
		if (team == RED_TEAM)
			TakeFlag(toucher, touched);
	} else if (touched == gFlagRed) {
		if (team == BLUE_TEAM)
			TakeFlag(toucher, touched);
	}
	return PLUGIN_HANDLED;
}

AttachFlagToPlayer(id, ent) {
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, id);
	set_pev(ent, pev_sequence, FLAG_SEQ_CARRIED);
	set_pev(ent, pev_solid, SOLID_NOT);
}

ReturnFlagToBase(ent) {
	server_print("ReturnFlagToBase");
	
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_aiment, 0);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_solid, SOLID_TRIGGER);

	if (ent == gFlagBlue) {
		CtfTeamHudMessage(RED_TEAM, "CTF_EFLAGBACK", "CTF_FLAGBACK");
		CtfTeamSpeak(RED_TEAM, "!CTF_EFLAGBACK", "!CTF_FLAGBACK");
		entity_set_origin(ent, gOriginFlagBlue);	
		set_pev(ent, pev_angles, gAnglesFlagBlue);
	} else if (ent == gFlagRed) {
		CtfTeamHudMessage(BLUE_TEAM, "CTF_EFLAGBACK", "CTF_FLAGBACK");
		CtfTeamSpeak(BLUE_TEAM, "!CTF_EFLAGBACK", "!CTF_FLAGBACK");
		entity_set_origin(ent, gOriginFlagRed);
		set_pev(ent, pev_angles, gAnglesFlagRed);
	}

	drop_to_floor(ent);
}

IsPlayerCarryingFlag(id) {
	server_print("IsPlayerCarringFlag");

	if (pev(gFlagBlue, pev_aiment) == id)
		return BLUE_TEAM;
	else if (pev(gFlagRed, pev_aiment) == id)
		return RED_TEAM;
	else
		return 0;
}

public TakeFlag(id, ent) {
	remove_task(ent + TASK_RETURNFLAGTOBASE);
	AttachFlagToPlayer(id, ent);
	CtfHudMessage(id, "CTF_YOUGOTFLAG", "CTF_GOTFLAG", "CTF_EGOTFLAG");
	CtfSpeak(id, "!CTF_YOUGOTFLAG", "!CTF_GOTFLAG", "!CTF_EGOTFLAG");
}

public TaskReturnFlagToBase(taskid) {
	new ent = taskid - TASK_RETURNFLAGTOBASE;
	ReturnFlagToBase(ent);
}

public DropFlag(id, team) {
	new ent;
	if (team == BLUE_TEAM)
		ent = gFlagBlue;
	else if (team == RED_TEAM)
		ent = gFlagRed;
	else
		return;

	CtfTeamHudMessage(team, "CTF_ELOSTFLAG", "CTF_LOSTFLAG");

	remove_task(ent + TASK_RETURNFLAGTOBASE);
	set_task(get_pcvar_float(gCvarFlagReturnTime), "TaskReturnFlagToBase", ent + TASK_RETURNFLAGTOBASE);

	new Float:velocity[3];
	velocity_by_aim(id, 400, velocity);

	set_pev(ent, pev_angles, 0);
	set_pev(ent, pev_velocity, velocity);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_aiment, 0);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
}

public CmdDropFlag(id, level, cid) {
	server_print("CmdDropFlag");
	DropFlag(id, IsPlayerCarryingFlag(id));

	return PLUGIN_HANDLED;
}

public SpawnFlag(const Float:origin[3], team) {
	new ent = create_entity("info_target");

	entity_set_model(ent, FLAG_MODEL);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_framerate, 1.0);

	entity_set_size(ent, Float:{ 4.0, 4.0, 0.0 }, Float:{ 4.0, 4.0, 72.0 });

	switch (team) {
		case BLUE_TEAM: {
			entity_set_origin(ent, gOriginFlagBlue);
			set_pev(ent, pev_classname, INFO_FLAG_BLUE);
			set_pev(ent, pev_skin, FLAG_SKIN_BLUE);
			set_ent_rendering(ent, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
			set_pev(ent, pev_angles, gAnglesFlagBlue);
		} case RED_TEAM: {
			entity_set_origin(ent, gOriginFlagRed);		
			set_pev(ent, pev_classname, INFO_FLAG_RED);
			set_pev(ent, pev_skin, FLAG_SKIN_RED);
			set_ent_rendering(ent, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30);
			set_pev(ent, pev_angles, gAnglesFlagRed);
		}
	}

	return ent;
}

// we need a base for the flag so players can score points when they capture...
public SpawnCapturePoint(const Float:origin[3]) {
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, INFO_CAPTURE_POINT);
	
	entity_set_model(ent, FLAG_MODEL);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	entity_set_origin(ent, origin);
	set_pev(ent, pev_effects, EF_NODRAW);
	entity_set_size(ent, Float:{ -8.0, -8.0, 0.0 }, Float:{ 8.0, 8.0, 8.0 });

	return ent;
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
			gSpawnsBlue[gNumSpawnsBlue] = create_entity("info_player_deathmatch");
			entity_set_origin(gSpawnsBlue[gNumSpawnsBlue], vector);
			gNumSpawnsBlue++;
		} else if (equal(key, "angles")) {
			set_pev(gSpawnsBlue[gNumSpawnsBlue - 1], pev_angles, vector);
		}
	} else if (equal(classname, INFO_PLAYER_RED)) { // info_player_team2
		if (equal(key, "origin")) {
			gSpawnsRed[gNumSpawnsRed] = create_entity("info_player_deathmatch");
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
		gIsMapCtf = true;
	}
}

stock CreateCustomEnt(const classname[]) {
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, classname);
	return ent;
}

public GetTeamListModels(output[][], size) {
	new teamlist[192];
	get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));

	new nIdx, nLen = (1 + copyc(output[nIdx], size, teamlist, ';'));

	while (nLen < strlen(teamlist) && ++nIdx < HL_MAX_TEAMS)
		nLen += (1 + copyc(output[nIdx], size, teamlist[nLen], ';'));
}

// the parsed string is in this format "x y z" e.g "128 0 256"
Float:StrToVec(const string[], Float:vector[3]) {
	new arg[3][12]; // hold parsed vector
	parse(string, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

	for (new i; i < sizeof arg; i++)
		vector[i] = str_to_float(arg[i]);
}

bool:array_search(value, array[], size) {
	new bool:match;
	for (new i; i < size; i++)
		if (array[i] == value)
			match = true; 
	return match;
}