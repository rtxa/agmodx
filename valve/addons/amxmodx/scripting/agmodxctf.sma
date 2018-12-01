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

new bool:gEnableCtf;
new bool:gIsMapCtf;

new gBlueScore;
new gRedScore;

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

new gCvarCtfDebug;
new gCvarCapturePoints;
new gCvarFlagReturnTime;

bool:IsCtfMode() {
	new type[32];
	get_cvar_string("sv_ag_gametype", type, charsmax(type));

	if (!equal(type, "ctf"))
		return false;
	else if (!gIsMapCtf)
		set_fail_state("Map not supported for CTF.");

	return true;
}

public plugin_precache() {
	precache_model(FLAG_MODEL);

	for (new i; i < sizeof VOX_SOUNDS; i++)
		precache_sound(VOX_SOUNDS[i]);

	gCvarCtfDebug = create_cvar("sv_ag_ctf_debug", "0");
	gCvarCapturePoints = create_cvar("sv_ag_ctf_capturepoints", "10");
	gCvarFlagReturnTime = create_cvar("sv_ag_ctf_flag_returntime", "30");
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	gEnableCtf = IsCtfMode();

	if (!gEnableCtf)
		return PLUGIN_HANDLED;

	register_dictionary("agmodxctf.txt");

	register_clcmd("dropitems", "CmdDropFlag");
	register_clcmd("spectate", "CmdSpectate");

	RegisterHam(Ham_Spawn, "player", "FwPlayerSpawnPost", true);
	RegisterHam(Ham_Killed, "player", "FwPlayerKilled");

	gFlagBlue = SpawnFlag(gOriginFlagBlue, BLUE_TEAM);
	gFlagRed = SpawnFlag(gOriginFlagRed, RED_TEAM);
	gBaseBlue = SpawnCapturePoint(gOriginFlagBlue, BLUE_TEAM);
	gBaseRed = SpawnCapturePoint(gOriginFlagRed, RED_TEAM);

	register_touch(INFO_FLAG_BLUE, "player", "FwFlagTouch");
	register_touch(INFO_FLAG_RED, "player", "FwFlagTouch");
	register_touch(INFO_CAPTURE_POINT, "player", "FwCapturePointTouch");


	register_message(get_user_msgid("ScoreInfo"), "MsgScoreInfo");

	gHudCtfMessage = CreateHudSyncObj();
	GetTeamListModels(gTeamListModels, HL_MAX_TEAMS);

	return PLUGIN_CONTINUE;
}

// i want to show only flag capture points in scoreboard, but
// teamscore function from gamedll is not overridden the team points (sum of all players frags) correctly 
// this is the best solution i could found by the moment
public MsgScoreInfo() {
	UpdateTeamScore();
}

UpdateTeamScore(id = 0) {
	hl_set_teamscore(gTeamListModels[BLUE_TEAM - 1], gBlueScore, id);	
	hl_set_teamscore(gTeamListModels[RED_TEAM - 1], gRedScore, id);	
}


public client_disconnected(id) {
	if (!gEnableCtf)
		return PLUGIN_HANDLED;

	DropFlag(id, IsPlayerCarryingFlag(id));

	return PLUGIN_CONTINUE;
}

public CmdSpectate(id) {
	set_task(0.1, "DropFlagSpec", id);
}

public AddPoints(id, points) {
	static scoreInfo;

	if (!scoreInfo)
		scoreInfo = get_user_msgid("ScoreInfo");

	new frags = get_user_frags(id) + points;
	set_user_frags(id, frags);
	
	// show new score
	message_begin(MSG_BROADCAST, scoreInfo);
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
		case BLUE_TEAM: { // Captured Blue Team flag
			if (touched == gBaseRed) {
				ReturnFlagToBase(gFlagBlue);

				new points = get_pcvar_num(gCvarCapturePoints);
				AddPoints(toucher, points);
				gRedScore += points;
				UpdateTeamScore();

				CtfHudMessage(toucher, "CTF_YOUCAP", "CTF_TEAMCAP", "CTF_THEYCAP");
				CtfSpeak(toucher, "!CTF_YOUCAP", "!CTF_TEAMCAP", "!CTF_THEYCAP");
			}
		} case RED_TEAM: { // Captured Red Team flag
			if (touched == gBaseBlue) {
				ReturnFlagToBase(gFlagRed);

				new points = get_pcvar_num(gCvarCapturePoints);
				AddPoints(toucher, points);
				gBlueScore += points;
				UpdateTeamScore();

				CtfHudMessage(toucher, "CTF_YOUCAP", "CTF_TEAMCAP", "CTF_THEYCAP");
				CtfSpeak(toucher, "!CTF_YOUCAP", "!CTF_TEAMCAP", "!CTF_THEYCAP");
			}
		}
	}
}

public FwPlayerKilled(victim, attacker) {
	DropFlag(victim, IsPlayerCarryingFlag(victim));
}

public FwPlayerSpawnPost(id) {
	new ent = FindPlayerTeamSpawn(id);
	
	if (ent)
		TeleportToSpawn(id, ent);
	else
		user_kill(id, true);
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

FindPlayerTeamSpawn(id) {
	new team, rndIdx, attempts;
	team = hl_get_user_team(id);

	switch (team) {
		case BLUE_TEAM: {
			do {
				rndIdx = random(gNumSpawnsBlue);

				if (attempts++ > 10) {
					for (new i; i < gNumSpawnsBlue; i++)
						if (IsSpawnPointValid(id, gSpawnsBlue[i]))
							return gSpawnsBlue[i];
					return 0;
				}
			} while (!IsSpawnPointValid(id, gSpawnsBlue[rndIdx]));
			return gSpawnsBlue[rndIdx];
		}
		case RED_TEAM: {
			do {
				rndIdx = random(gNumSpawnsRed);

				if (attempts++ > 10) {
					for (new i; i < gNumSpawnsRed; i++)
						if (IsSpawnPointValid(id, gSpawnsRed[i]))
							return gSpawnsRed[i];
					return 0;
				}
			} while (!IsSpawnPointValid(id, gSpawnsRed[rndIdx]));
			return gSpawnsRed[rndIdx];
		}
		default: {
		 	return 0;
		}
	}
	return 0;
}

bool:IsSpawnPointValid(id, spawnEnt) {
	new ent, Float:origin[3];
	pev(spawnEnt, pev_origin, origin);

	while ((ent = find_ent_in_sphere(ent, origin, 10.0)))
		if (IsPlayer(ent) && ent != id)
			return false;

	return true;
}

public FwFlagTouch(touched, toucher) {
	if (get_pcvar_num(gCvarCtfDebug))
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
	if (get_pcvar_num(gCvarCtfDebug))
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
	if (get_pcvar_num(gCvarCtfDebug))
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
	if (get_pcvar_num(gCvarCtfDebug))
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
public SpawnCapturePoint(const Float:origin[3], team) {
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, INFO_CAPTURE_POINT);
	
	entity_set_model(ent, FLAG_MODEL);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_framerate, 1.0);

	entity_set_size(ent, Float:{ -8.0, -8.0, 0.0 }, Float:{ 8.0, 8.0, 8.0 });
	set_ent_rendering(ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 90);

	switch (team) {
		case BLUE_TEAM: {
			set_pev(ent, pev_skin, FLAG_SKIN_BLUE);
			entity_set_origin(ent, gOriginFlagBlue);
			set_pev(ent, pev_angles, gAnglesFlagBlue);
		} case RED_TEAM: {
			entity_set_origin(ent, gOriginFlagRed);		
			set_pev(ent, pev_skin, FLAG_SKIN_RED);
			set_pev(ent, pev_angles, gAnglesFlagRed);
		}
	}

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

stock hl_set_teamscore(teamName[], points, id = 0) {
	static teamScore;

	if (!teamScore)
		teamScore = get_user_msgid("TeamScore");

	message_begin(id == 0 ? MSG_BROADCAST : MSG_ONE, teamScore, _, id);
	write_string(teamName);
	write_short(points); // capture points
	write_short(0); // score is only for flags captures, so deaths is always 0
	message_end();
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