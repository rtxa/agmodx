#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X CTF"
#define AUTHOR  "rtxA"

#pragma semicolon 1

// TaskIDs
enum (+= 100) {
	TASK_FLAGRESET = 1000,
};

#define MODE_TYPE_NAME "ctf"

#define BLUE_TEAM 1
#define RED_TEAM 2

#define FLAG_SKIN_BLUE 0
#define FLAG_SKIN_RED 1

#define FLAG_SEQ_NOTCARRIED 1
#define FLAG_SEQ_CARRIED 2

#define FLAG_STATUS_NOTCARRIED 0
#define FLAG_STATUS_CARRIED 1

enum FlagStatus {
	SPAWNPOINT = 0,
	CARRIED,
	DROPPED
}

new const INFO_PLAYER_DEATHMATCH[] = "info_player_deathmatch";
new const INFO_PLAYER_BLUE[] = "info_player_team1";
new const INFO_PLAYER_RED[] = "info_player_team2";

new const INFO_FLAG_BLUE[] = "item_flag_team1";
new const INFO_FLAG_RED[] = "item_flag_team2";

new const INFO_CAPTURE_POINT[] = "info_capture_point";

new const FLAG_MODEL[] = "models/ctf/flag.mdl";

new const CTF_SOUNDS[][] = {
	"sound/ctf/youhaveflag.wav",
	"sound/ctf/teamhaveflag.wav",
	"sound/ctf/enemyhaveflag.wav",
	"sound/ctf/bluescores.wav",
	"sound/ctf/blueflagstolen.wav",
	"sound/ctf/blueflagreturned.wav",
	"sound/ctf/redscores.wav",
	"sound/ctf/redflagstolen.wav",
	"sound/ctf/redflagreturned.wav",
};

enum CtfSounds {
	CTF_YOUHAVEFLAG = 0,
	CTF_TEAMHAVEFLAG,
	CTF_ENEMYHAVEFLAG,
	CTF_BLUESCORES,
	CTF_BLUEFLAGSTOLEN,
	CTF_BLUEFLAGRETURNED,
	CTF_REDSCORES,
	CTF_REDFLAGSTOLEN,
	CTF_REDFLAGRETURNED,
}

new const CTF_ML_FLAGCAPTURED[][] = {
	"",
	"CTF_BLUEFLAGCAPTURED",
	"CTF_REDFLAGCAPTURED",
};

new const CTF_ML_SND_TEAMSCORES[][] = {
	"",
	"!CTF_BLUESCORES",
	"!CTF_REDSCORES",
};

new const CTF_ML_FLAGLOST[][] = {
	"",
	"CTF_BLUEFLAGLOST",
	"CTF_REDFLAGLOST"
};

new const CTF_ML_SND_FLAGSTOLEN[][] = {
	"",
	"!CTF_BLUEFLAGSTOLEN",
	"!CTF_REDFLAGSTOLEN"
};

new const CTF_ML_YOUHAVEFLAG[][] = {
	"",
	"CTF_YOUHAVEBLUEFLAG",
	"CTF_YOUHAVEREDFLAG"
};

new const CTF_ML_FLAGRETURNED_PLAYER[][] = {
	"",
	"CTF_BLUEFLAGRETURNED_PLAYER",
	"CTF_REDFLAGRETURNED_PLAYER"
};

new const CTF_ML_FLAGRETURNED[][] = {
	"",
	"CTF_BLUEFLAGRETURNED",
	"CTF_REDFLAGRETURNED"
};

new const CTF_ML_SND_FLAGRETURNED[][] = {
	"",
	"!CTF_BLUEFLAGRETURNED",
	"!CTF_REDFLAGRETURNED",
};

new bool:gIsCtfMode;
new bool:gIsMapCtfNative;

new gBlueScore;
new gRedScore;

new gFlagBlue;
new gFlagRed;
new gBaseBlue;
new gBaseRed;

new gHudCtfMessage;
new gTeamListModels[HL_MAX_TEAMS][HL_MAX_TEAMNAME_LENGTH];

new gCvarCtfDebug;
new gCvarCaptureLimit;		// the number of captures before map ends. 
new gCvarCapturePoints;		// the amount of points his teammates get.
new gCvarTeamCapturePoints;	// the amount of points his teammates get.
new gCvarDefendPoints;		// the amount of points the defender gets.
new gCvarStealPoints;		// the amount of points the stealer gets. 
new gCvarCarrierKillPoints; // the amount of points the killer gets.
new gCvarReturnPoints;		// the amount of points the returner gets.
new gCvarFlagReturnTime;	// the time that a dropped flag lays in the world before respawning.
new gCvarFlagDelayTime;		// the time required to allow players to touch a flag after it respawns.

public plugin_precache() {
	register_plugin(PLUGIN, AGMODX_VERSION, AUTHOR);

	gIsCtfMode = IsSelectedMode(MODE_TYPE_NAME);

	if (!gIsCtfMode) {
		StopPlugin();
		return;
	}

	precache_model(FLAG_MODEL);

	for (new i; i < sizeof CTF_SOUNDS; i++)
		precache_generic(CTF_SOUNDS[i]);

	gCvarCtfDebug = create_cvar("sv_ag_ctf_debug", "0");
	gCvarCaptureLimit = create_cvar("sv_ag_ctf_capturelimit", "10");
	gCvarCapturePoints = create_cvar("sv_ag_ctf_capturepoints", "4");
	gCvarTeamCapturePoints = create_cvar("sv_ag_ctf_teamcapturepoints", "1");
	gCvarDefendPoints = create_cvar("sv_ag_ctf_defendpoints", "1");
	gCvarReturnPoints = create_cvar("sv_ag_ctf_returnpoints", "1");
	gCvarStealPoints = create_cvar("sv_ag_ctf_stealpoints", "1");	
	gCvarCarrierKillPoints = create_cvar("sv_ag_ctf_carrierkillpoints", "1");
	gCvarFlagReturnTime = create_cvar("sv_ag_ctf_flag_resettime", "30");
	gCvarFlagDelayTime = create_cvar("sv_ag_ctf_flag_delaytime", "1");
}

public plugin_cfg() {
	hook_cvar_change(get_cvar_pointer("sv_ag_match_running"), "CvarMatchRunningHook");
}

public CvarMatchRunningHook(pcvar, const old_value[], const new_value[]) {
	new num = str_to_num(new_value);

	if (num == 1) {
		// reset team score when match starts
		gBlueScore = gRedScore = 0;
		UpdateTeamScore();

		new team;
		for (new id = 1; id <= MaxClients; id++) {
			if (!is_user_connected(id))
				continue;
			team = Player_IsCarryingFlag(id);
			if (team) {
				SetFlagCarriedByPlayer(id, 0);
				Player_DrawFlagIcon(id, false, team);
			}
		}

		// return flag to base
		Flag_Reset(gFlagBlue);
		Flag_Reset(gFlagRed);
	}
}

stock CreateGameTeamMaster(name[], teamid) {
	new ent = create_entity("game_team_master");
	set_pev(ent, pev_targetname, name);
	DispatchKeyValue(ent, "teamindex", fmt("%i", teamid - 1));
	return ent;
}

// this removes spawns that are not from ctf
RemoveNoTeamSpawns() {
	new ent, master[32];
	while ((ent = find_ent_by_class(ent, INFO_PLAYER_DEATHMATCH))) {
		pev(ent, pev_netname, master, charsmax(master));
		if (!equal(master, "blue") && !equal(master, "red")) {
			remove_entity(ent);
		} 
	}
}

public OnPlayerSpawn(id) {
	client_print(id, print_center, "%l", "CTF_NOTCTFMAP");
}

bool:LoadCtfMapCfgFile() {
	new mapname[32];
	get_mapname(mapname, charsmax(mapname));

	new handle = fopen(fmt("ctf/%s.ctf", mapname), "r");

	if (!handle)
		return false;

	new buffer[128], line = 1;
	while (fgets(handle, buffer, charsmax(buffer))) {
		new ent_name[32], Float:ent_origin[3], Float:ent_angles[3];

		if (!ParseEntFromFile(buffer, ent_name, charsmax(ent_name), ent_origin, ent_angles))
			log_amx("Warning: Bad parsing on line %d from file ^"%s.ctf^". Check if everything is correct.", line, mapname);
		
		// Debug
		//log_amx("[Entity] Name: %s Origin: %f %f %f Angles: %f %f %f", ent_name, ent_origin[0], ent_origin[1], ent_origin[2], ent_angles[0], ent_angles[1], ent_angles[2]);
		
		if (equal(ent_name, INFO_FLAG_BLUE)) {
			gFlagBlue = CreateCustomEnt(ent_name);	
			SetFlagStartOrigin(gFlagBlue, ent_origin);
			SetFlagStartAngles(gFlagBlue, ent_angles);
		} else if (equal(ent_name, INFO_FLAG_RED)) {
			gFlagRed = CreateCustomEnt(ent_name);	
			SetFlagStartOrigin(gFlagRed, ent_origin);
			SetFlagStartAngles(gFlagRed, ent_angles);
		} else if (equal(ent_name, INFO_PLAYER_BLUE) || equal(ent_name, INFO_PLAYER_RED)) {
			new ent = create_entity(INFO_PLAYER_DEATHMATCH);
			set_pev(ent, pev_netname, equal(ent_name, INFO_PLAYER_BLUE) ? "blue" : "red");
			set_pev(ent, pev_origin, ent_origin);
			set_pev(ent, pev_angles, ent_angles);
		} else {
			new ent = create_entity(ent_name);
			if (pev_valid(ent) == 0) {
				log_amx("Warning: Classname ^"%s^" doesn't exists. Check if everything is correct on line %d from file ^"%s.ctf^"", ent_name, line, mapname);
				continue;
			}
			set_pev(ent, pev_origin, ent_origin);
			set_pev(ent, pev_angles, ent_angles);
			DispatchSpawn(ent);
		}

		line++;
	}

	fclose(handle);

	return true;
}

bool:ParseEntFromFile(const input[], ent_name[], len, Float:ent_origin[3], Float:ent_angles[3]) {
	// Input example: "item_flag_team1 973.734131 535.433899 36.031250 -4.268188 86.742554 0.000000"
	new arg[32], pos;

	// 1. Read entity name
	pos = argparse(input, pos, arg, charsmax(arg));
	if (pos == -1) {
		return false;
	}
	copy(ent_name, len, arg);

	// 2. Read entity origin
	for (new i = 0; i < 3; i++) {
		pos = argparse(input, pos, arg, charsmax(arg));
		if (pos == -1) {
			return false;
		}
		ent_origin[i] = str_to_float(arg);
	}

	// 3. Read entity angles
	for (new i = 0; i < 3; i++) {
		pos = argparse(input, pos, arg, charsmax(arg));
		if (pos == -1) {
			return false;
		}
		ent_angles[i] = str_to_float(arg);
	}

	return true;
}

public plugin_init() {
	register_dictionary("agmodx_ctf.txt");
	
	new bool:hasCfgFile = LoadCtfMapCfgFile();

	if (!hasCfgFile && !gIsMapCtfNative) {
		RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", true);
		log_amx("%L", LANG_SERVER, "CTF_NOTCTFMAP");
		return;
	}

	register_clcmd("dropitems", "CmdDropFlag");
	register_clcmd("drop flag", "CmdDropFlag");
	register_clcmd("spectate", "CmdSpectate");

	RegisterHam(Ham_Killed, "player", "OnPlayerKilled");

	RemoveNoTeamSpawns();

	SpawnFlag(gFlagBlue);
	SpawnFlag(gFlagRed);
	gBaseBlue = SpawnCapturePoint(gFlagBlue);
	gBaseRed = SpawnCapturePoint(gFlagRed);

	register_touch(INFO_FLAG_BLUE, "player", "OnFlagTouch");
	register_touch(INFO_FLAG_RED, "player", "OnFlagTouch");
	register_touch(INFO_CAPTURE_POINT, "player", "OnCapturePointTouch");

	register_message(get_user_msgid("SayText"), "MsgSayText");
	register_message(get_user_msgid("ScoreInfo"), "MsgScoreInfo");

	CreateGameTeamMaster("blue", BLUE_TEAM);
	CreateGameTeamMaster("red", RED_TEAM);

	gHudCtfMessage = CreateHudSyncObj();
	GetTeamListModels(gTeamListModels, HL_MAX_TEAMS);
}

public MsgSayText(msg_id, msg_dest, receiver) {
	new text[191]; // 192 will crash the sv by overflow if someone send a large message with a lot of %l, %w, etc...
	get_msg_arg_string(2, text, charsmax(text)); // get user message

	// Only modify player messages
	if (text[0] != 2)
		return PLUGIN_CONTINUE;

	new sender = get_msg_arg_int(1);

	new str[32];

	// replace all %f with flag status
	new team = Player_IsCarryingFlag(sender);
	formatex(str, charsmax(str), "%s", team > 0 ? gTeamListModels[team - 1] : "");
	replace_string(text, charsmax(text), "%f", hl_get_user_spectator(sender) ? "" : str, false);
	
	// send modified message
	set_msg_arg_string(2, text);
	
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
	if (!gIsCtfMode)
		return PLUGIN_HANDLED;

	DropFlag(id);

	return PLUGIN_CONTINUE;
}

public CmdSpectate(id) {
	set_task(0.1, "DropFlagSpec", id);
}

public AddPoints(id, points) {
	hl_set_user_frags(id, get_user_frags(id) + points);
}

AddPointsToTeammates(teamIndex, points, skipPlayer = 0) {
	new players[MAX_PLAYERS], numPlayers;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	for (new i = 0; i < numPlayers; i++) {
		if (players[i] != skipPlayer && hl_get_user_team(players[i]) == teamIndex) {
			AddPoints(players[i], points);
		}
	}
}


AddPointsToTeamScore(teamIndex, points) {
	if (teamIndex == BLUE_TEAM) {
		gBlueScore += points;
	} else if (teamIndex == RED_TEAM) {
		gRedScore += points;
	}
	return 0;
}

stock CtfHudMessage(id, const playerMsg[] = "", const teamMsg[] = "", const nonTeamMsg[] = "") {
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

/**
 * @brief Sends team-specific and non-team-specific HUD messages in a Capture the Flag scenario.
 *
 * This function sets up a HUD message with the specified color and parameters and sends it to players
 * based on their team affiliation. The team-specific message is sent to players in the specified team,
 * while the non-team-specific message is sent to players who do not belong to that team.
 *
 * @param team The team number for which the team-specific message will be sent.
 * @param teamMsg The translation key for the team-specific message to be displayed (optional).
 * @param nonTeamMsg The translation key for the non-team-specific message to be displayed (optional).
 *
 * @note The messages should be translation keys that can be used to retrieve the localized message from a translation file.
 */
stock CtfTeamHudMessage(team, const teamMsg[], nonTeamMsg[]) {
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

/**
 * Sends different messages to all connected players based on team affiliation.
 *
 * @param id 			The ID of the player sending the messages.
 * @param playerMsg 	The message to be sent to the player specified by 'id'.
 * @param teamMsg 		The message to be sent to players in the same team as the player specified by 'id'.
 * @param enemyTeam 	The team ID of enemy players.
 * @param enemyMsg 		The message to be sent to players in the enemy team.
 * @param nonTeamMsg 	The message to be sent to players not in the same team or enemy team.
 */
Speak_All(id, const playerMsg[], const teamMsg[], enemyTeam, const enemyMsg[], const nonTeamMsg[]) {
	new playerTeam = hl_get_user_team(id);
	new listenerTeam;

	for (new plr = 1; plr <= MaxClients; plr++) {
		if (!is_user_connected(plr)) {
			continue;
		}
		listenerTeam = hl_get_user_team(plr);
		if (plr == id) {
			Speak(plr, fmt("%l", playerMsg));
		} else if (playerTeam == listenerTeam) {
			Speak(plr, fmt("%l", teamMsg));
		} else if (enemyTeam == listenerTeam) {
			Speak(plr, fmt("%l", enemyMsg));
		} else {
			Speak(plr, fmt("%l", nonTeamMsg));
		}
	}
}

stock Speak(id, const speak[]) {
	if (id == 0) {
		for (new plr = 1; plr <= MaxClients; plr++) {
			client_cmd(plr, "speak ^"%s^"", speak);
		}
	}
	client_cmd(id, "speak ^"%s^"", speak);
}

stock AreTeamMates(firstPlayer, secondPlayer) {
	return hl_get_user_team(firstPlayer) == hl_get_user_team(secondPlayer);
}

public DropFlagSpec(id) {
	if (hl_get_user_spectator(id))
		DropFlag(id);
}

GetCapturePointTeam(ent) {
	if (ent == gBaseBlue) {
		return BLUE_TEAM;
	} else if (ent == gBaseRed) {
		return RED_TEAM;
	}
	return 0;
}

public OnCapturePointTouch(touched, toucher) {
	if (!Player_IsCarryingFlag(toucher)) {
		return;
	}

	// Player is trying to capture the flag, let's do some checks
	new toucherTeam = hl_get_user_team(toucher);
	new capturePointTeam =  GetCapturePointTeam(touched);

	// You can't capture the flag on someone else's base
	if (toucherTeam != capturePointTeam) {
		return;
	}

	// Capture isn't allowed when your team flag is being carried or dropped
	if (!Flag_IsOnSpawnPoint(GetFlagEntity(toucherTeam))) {
		return;
	}

	new flagStealedEnt = GetFlagCarriedByPlayer(toucher);
	new flagStealedTeam = Flag_GetTeam(flagStealedEnt);

	Player_DrawFlagIcon(toucher, false, flagStealedTeam);
	SetFlagCarriedByPlayer(toucher, 0);
	Flag_Reset(flagStealedEnt);

	AddPoints(toucher, get_pcvar_num(gCvarCapturePoints));
	AddPointsToTeammates(toucherTeam, get_pcvar_num(gCvarTeamCapturePoints), toucher);
	AddPointsToTeamScore(toucherTeam, 1);
	UpdateTeamScore();

	// Check if we have reached the capture limit, if so start intermission
	if (gBlueScore >= get_pcvar_num(gCvarCaptureLimit) || gRedScore >= get_pcvar_num(gCvarCaptureLimit)) {
		StartIntermissionMode();
	}

	client_print(0, print_center, "%l", CTF_ML_FLAGCAPTURED[flagStealedTeam], toucher);
	client_print(0, print_console, "%l", CTF_ML_FLAGCAPTURED[flagStealedTeam], toucher);
	log_amx("%l", CTF_ML_FLAGCAPTURED[flagStealedTeam], toucher);

	Speak(0, fmt("%l", CTF_ML_SND_TEAMSCORES[toucherTeam]));
}

public OnPlayerKilled(victim, attacker) {
	if (Player_IsCarryingFlag(victim)) {
		// Give points to attacker for killing flag stealer
		if (IsPlayer(attacker) && !AreTeamMates(attacker, victim)) {
			AddPoints(attacker, get_pcvar_num(gCvarCarrierKillPoints));
		}

		new classname[32];
		pev(attacker, pev_classname, classname, charsmax(classname));

		// Deaths caused by a trigger_hurt (Possible falling in some unaccesible area)
		// will return the flag to base
		if (equal(classname, "trigger_hurt")) {
			SetFlagCarriedByPlayer(victim, 0);
			Flag_Reset(GetFlagCarriedByPlayer(victim));
			return HAM_IGNORED;
		}

		DropFlag(victim);

		return HAM_IGNORED;
	}
	
	// Bonus attacker for defending his flag from the enemy
	// Only if the enemy is close to the flag within a radius of 192 units
	if (IsPlayer(attacker) && victim != attacker && !AreTeamMates(attacker, victim)) {
		new flag = GetFlagEntity(hl_get_user_team(attacker));
		if (entity_range(victim, flag) < 192.0) {
			AddPoints(attacker, get_pcvar_num(gCvarDefendPoints));
		}
	}

	return HAM_IGNORED;
}

GetFlagEntity(teamindex) {
	if (teamindex == BLUE_TEAM) {
		return gFlagBlue;
	} else if (teamindex == RED_TEAM) {
		return gFlagRed;
	}
	return 0;
}

GetFlagCarriedByPlayer(id) {
	return pev(id, pev_iuser4);
}

SetFlagCarriedByPlayer(id, ent) {
	set_pev(id, pev_iuser4, ent);
}

public OnFlagTouch(touched, toucher) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("FlagTouched");

	if (Flag_GetNextTouch(touched) >= get_gametime())
		return PLUGIN_HANDLED;

	if (!is_user_alive(toucher))
		return PLUGIN_HANDLED;

	new playerTeam = hl_get_user_team(toucher);
	new flagTeam = Flag_GetTeam(touched);

	if (flagTeam == playerTeam) {
		// Give points for returning your flag
		if (!Flag_IsOnSpawnPoint(touched)) {
			remove_task(touched + TASK_FLAGRESET);
			Flag_Reset(touched);
			AddPoints(toucher, get_pcvar_num(gCvarReturnPoints));

			// alert/notify players that flag has return to base
			client_print(0, print_center, "%l", CTF_ML_FLAGRETURNED_PLAYER[playerTeam], toucher);
			client_print(0, print_console, "%l", CTF_ML_FLAGRETURNED_PLAYER[playerTeam], toucher);
			log_amx("%l", CTF_ML_FLAGRETURNED_PLAYER[playerTeam], toucher);
		}
	}

	if (flagTeam != playerTeam) {
		// Give points for stealing the flag from spawn point
		if (Flag_IsOnSpawnPoint(touched)) {
			AddPoints(toucher, get_pcvar_num(gCvarStealPoints));
		}
		Player_TakeFlag(toucher, touched);

		client_print(0, print_center, "%l", CTF_ML_YOUHAVEFLAG[flagTeam], toucher);
		client_print(0, print_console, "%l", CTF_ML_YOUHAVEFLAG[flagTeam], toucher);
		log_amx("%l", CTF_ML_YOUHAVEFLAG[flagTeam], toucher);

		// Alert flag sound:
		// Player who pick the flag: ctf/youhavetheflag.wav
		// Team who's flag has been stolen: ctf/enemyhaveflag.wav
		// Team which player has the flag: ctf/teamhaveflag.wav
		// Spectators/Non-team: ctf/blueflagstolen.wav
		Speak_All(toucher, "!CTF_YOUHAVEFLAG", "!CTF_TEAMHAVEFLAG", flagTeam, "!CTF_ENEMYHAVEFLAG", CTF_ML_SND_FLAGSTOLEN[flagTeam]);
	}
	

	return PLUGIN_CONTINUE;
}

Flag_AttachToPlayer(id, ent) {
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, id);
	set_pev(ent, pev_sequence, FLAG_SEQ_CARRIED);
	set_pev(ent, pev_solid, SOLID_NOT);
}

Flag_GetTeam(ent) {
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (equal(classname, INFO_FLAG_BLUE))
		return BLUE_TEAM;
	else if (equal(classname, INFO_FLAG_RED)) 
		return RED_TEAM;
	else
		return -1;
}

SetFlagStartOrigin(ent, Float:origin[3]) {
	set_pev(ent, pev_vuser1, origin);
}

SetFlagStartAngles(ent, Float:angles[3]) {
	set_pev(ent, pev_vuser2, angles);
}

GetFlagStartOrigin(ent, Float:origin[3]) {
	pev(ent, pev_vuser1, origin);
}

GetFlagStartAngles(ent, Float:angles[3]) {
	pev(ent, pev_vuser2, angles);
}

Flag_SetNextTouch(ent, Float:time) {
	set_pev(ent, pev_fuser1, get_gametime() + time);
}

Float:Flag_GetNextTouch(ent) {
	return entity_get_float(ent, EV_FL_fuser1);
}

Flag_Reset(ent) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("Flag_Reset");
	
	new Float:origin[3], Float:angles[3];
	GetFlagStartOrigin(ent, origin);
	GetFlagStartAngles(ent, angles);

	create_teleport_splash(ent);

	entity_set_origin(ent, origin);
	set_pev(ent, pev_angles, angles);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_aiment, 0);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_solid, SOLID_TRIGGER);

	Flag_SetStatus(ent, FlagStatus:SPAWNPOINT);

	entity_set_size(ent, Float:{ 4.0, 4.0, 0.0 }, Float:{ 4.0, 4.0, 72.0 });

	create_teleport_splash(ent);

	Flag_SetNextTouch(ent, get_pcvar_float(gCvarFlagDelayTime));
}

Player_IsCarryingFlag(id) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("IsPlayerCarringFlag");

	if (pev(gFlagBlue, pev_aiment) == id)
		return BLUE_TEAM;
	else if (pev(gFlagRed, pev_aiment) == id)
		return RED_TEAM;
	else
		return 0;
}

stock bool:Flag_IsCarried(ent) {
	return pev(ent, pev_aiment) != 0;
}

stock bool:Flag_IsDropped(ent) {
	return Flag_GetStatus() == FlagStatus:DROPPED;
}

stock FlagStatus:Flag_GetStatus(ent) {
	return FlagStatus:pev(ent, pev_iuser1);
}

stock Flag_SetStatus(ent, FlagStatus:status) {
	set_pev(ent, pev_iuser1, status);
}

stock bool:Flag_IsOnSpawnPoint(ent) {
	return Flag_GetStatus(ent) == FlagStatus:SPAWNPOINT;
}

stock Player_DrawFlagIcon(id, bool:status, team) {
	static StatusIcon;

	if (!StatusIcon)
		StatusIcon = get_user_msgid("StatusIcon");

	new r, g, b, sprite[32];
	
	if (team == RED_TEAM) {
		r = 230;
		copy(sprite, charsmax(sprite), "dmg_rad");
	} else if (team == BLUE_TEAM) {
		b = 230;
		copy(sprite, charsmax(sprite), "dmg_shock");
	}
	message_begin(MSG_ONE, StatusIcon, .player = id);
	write_byte(status);
	write_string(sprite);
	write_byte(r);
	write_byte(g);
	write_byte(b);
	message_end();
}

public Player_TakeFlag(id, ent) {
	remove_task(ent + TASK_FLAGRESET);
	Flag_AttachToPlayer(id, ent);
	SetFlagCarriedByPlayer(id, ent);
	Flag_SetStatus(ent, FlagStatus:CARRIED);
	Player_DrawFlagIcon(id, true, Flag_GetTeam(ent));
}

public Task_FlagReset(taskid) {
	new ent = taskid - TASK_FLAGRESET;

	// Notify players that the flag has return on its own 
	new flagTeam = Flag_GetTeam(ent);
	client_print(0, print_center, "%l", CTF_ML_FLAGRETURNED[flagTeam]);
	client_print(0, print_console, "%l", CTF_ML_FLAGRETURNED[flagTeam]);
	log_amx("%l", CTF_ML_FLAGRETURNED[flagTeam]);
	Speak(0, fmt("%l", CTF_ML_SND_FLAGRETURNED[flagTeam]));

	Flag_Reset(ent);
}

public DropFlag(id) {
	new ent = GetFlagCarriedByPlayer(id);
	SetFlagCarriedByPlayer(id, 0);
	Player_DrawFlagIcon(id, false, Flag_GetTeam(ent));

	if (!ent)
		return;

	remove_task(ent + TASK_FLAGRESET);
	set_task(get_pcvar_float(gCvarFlagReturnTime), "Task_FlagReset", ent + TASK_FLAGRESET);


	set_pev(ent, pev_aiment, 0);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_angles, 0);

	Flag_SetStatus(ent, FlagStatus:DROPPED);

	if (is_user_alive(id)) { // drop it where player points
		new Float:velocity[3];
		velocity_by_aim(id, 400, velocity);
		set_pev(ent, pev_velocity, velocity);
	} else { // release it from player's position
		new Float:origin[3];
		pev(id, pev_origin, origin);
		entity_set_origin(ent, origin);
		set_pev(ent, pev_flags, FL_FLY);
	}

	entity_set_size(ent, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0}); // collisions will work as expected with no size (strange)

	// Give some time to the flag to fly, otherwise it'll be picked up by us again
	Flag_SetNextTouch(ent, 0.5);
	set_pev(ent, pev_solid, SOLID_TRIGGER);

	new flagTeam = Flag_GetTeam(ent);

	// Notify players that the player has lost the flag
	client_print(0, print_center, "%l", CTF_ML_FLAGLOST[flagTeam], id);
	client_print(0, print_console, "%l", CTF_ML_FLAGLOST[flagTeam], id);
	log_amx("%l", CTF_ML_FLAGLOST[flagTeam], id);
}

public CmdDropFlag(id, level, cid) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("CmdDropFlag");

	DropFlag(id);

	return PLUGIN_HANDLED;
}

SpawnFlag(ent) {
	new Float:origin[3], Float:angles[3];
	GetFlagStartOrigin(ent, origin);
	GetFlagStartAngles(ent, angles);
	
	entity_set_model(ent, FLAG_MODEL);
	entity_set_size(ent, Float:{ 4.0, 4.0, 0.0 }, Float:{ 4.0, 4.0, 72.0 });

	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_angles, angles);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_framerate, 1.0);

	Flag_SetStatus(ent, FlagStatus:SPAWNPOINT);

	// when flag is on ground, set a new start origin
	drop_to_floor(ent);
	pev(ent, pev_origin, origin);
	SetFlagStartOrigin(ent, origin);

	switch (Flag_GetTeam(ent)) {
		case BLUE_TEAM: {
			set_pev(ent, pev_skin, FLAG_SKIN_BLUE);
			set_ent_rendering(ent, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 30);
		}
		case RED_TEAM: {
			set_pev(ent, pev_skin, FLAG_SKIN_RED);
			set_ent_rendering(ent, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 30);
		}
	}
}

// we need a base for the flag so players can score points when they capture...
SpawnCapturePoint(flagEnt) {
	new Float:origin[3], Float:angles[3];
	GetFlagStartOrigin(flagEnt, origin);
	GetFlagStartAngles(flagEnt, angles);
	
	new ent = create_entity("info_target");
	set_pev(ent, pev_classname, INFO_CAPTURE_POINT);

	entity_set_model(ent, FLAG_MODEL);
	entity_set_size(ent, Float:{ -8.0, -8.0, 0.0 }, Float:{ 8.0, 8.0, 8.0 });
	set_ent_rendering(ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 90);

	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_angles, angles);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_skin, pev(flagEnt, pev_skin));
	set_pev(ent, pev_framerate, 1.0);

	return ent;
}

/* Get data of entities from ag ctf map
 */
public pfn_keyvalue(ent) {
	if (!gIsCtfMode)
		return PLUGIN_CONTINUE;

	new classname[32], key[16], value[64];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);

	new Float:vector[3];
	StrToVec(value, vector);

	static customEnt;

	// Because these entities are not implemented in HL, we need to recreate them
	// 1. Let's spawn a generic entity (info_target) or a similar one.
	if (equal(key, "classname")) {
		if (equal(value, INFO_PLAYER_BLUE) || equal(value, INFO_PLAYER_RED)) {
			customEnt = create_entity(INFO_PLAYER_DEATHMATCH);
		} else if (equal(value, INFO_FLAG_BLUE)) {
			gFlagBlue = CreateCustomEnt(INFO_FLAG_BLUE);
		} else if (equal(value, INFO_FLAG_RED)) {
			gFlagRed = CreateCustomEnt(INFO_FLAG_RED);
		}
	}

	// 2. Then we fill their properties as we read them, until we move to the next entity.
	if (equal(classname, INFO_PLAYER_BLUE)) { // info_player_team1
		if (equal(key, "origin")) {
			entity_set_origin(customEnt, vector);
			set_pev(customEnt, pev_netname, "blue");
		} else if (equal(key, "angles")) {
			set_pev(customEnt, pev_angles, vector);
		}
	} else if (equal(classname, INFO_PLAYER_RED)) { // info_player_team2
		if (equal(key, "origin")) {
			entity_set_origin(customEnt, vector);
			set_pev(customEnt, pev_netname, "red");
		} else if (equal(key, "angles")) {
			set_pev(customEnt, pev_angles, vector);
		}
	} else if (equal(classname, INFO_FLAG_BLUE)) { // item_flag_team1
		if (equal(key, "origin")) {
			SetFlagStartOrigin(gFlagBlue, vector);
		} else if (equal(key, "angles")) {
			SetFlagStartAngles(gFlagBlue, vector);
		}
	} else if (equal(classname, INFO_FLAG_RED)) { // item_flag_team2
		if (equal(key, "origin")) {
			SetFlagStartOrigin(gFlagRed, vector);
		} else if (equal(key, "angles")) {
			SetFlagStartAngles(gFlagRed, vector);
		}
		gIsMapCtfNative = true;
	}
	return PLUGIN_CONTINUE;
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

// the parsed string is in this format "x y z" e.g "128 0 256"
Float:StrToVec(const string[], Float:vector[3]) {
	new arg[3][12]; // hold parsed vector
	parse(string, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

	for (new i; i < sizeof arg; i++)
		vector[i] = str_to_float(arg[i]);
}

stock bool:array_search(value, array[], size) {
	new bool:match;
	for (new i; i < size; i++)
		if (array[i] == value)
			match = true; 
	return match;
}

stock create_teleport_splash(ent) {
	new Float:origin[3];
	pev(ent, pev_origin, origin);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_TELEPORT); 
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2]));
	message_end();

	return 1;
}

stock StartIntermissionMode() {
	new ent = create_entity("game_end");
	if (is_valid_ent(ent))
		ExecuteHamB(Ham_Use, ent, 0, 0, 1.0, 0.0);
}