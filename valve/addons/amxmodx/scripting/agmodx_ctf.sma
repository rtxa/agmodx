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
	TASK_RETURNFLAGTOBASE = 1000,
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

new const INFO_PLAYER_DEATHMATCH[] = "info_player_deathmatch";
new const INFO_PLAYER_BLUE[] = "info_player_team1";
new const INFO_PLAYER_RED[] = "info_player_team2";

new const INFO_FLAG_BLUE[] = "item_flag_team1";
new const INFO_FLAG_RED[] = "item_flag_team2";

new const INFO_CAPTURE_POINT[] = "info_capture_point";

new const FLAG_MODEL[] = "models/ctf/flag.mdl";

new const VOX_SOUNDS[][] = { "vox/endgame.wav", "vox/captured.wav", "vox/enemy.wav", "vox/flag.wav", "vox/returned.wav" };

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
new gCvarCapturePoints;
new gCvarFlagReturnTime;
new gCvarFlagDelayTime;

public plugin_precache() {
	register_plugin(PLUGIN, AGMODX_VERSION, AUTHOR);

	gIsCtfMode = IsSelectedMode(MODE_TYPE_NAME);

	if (!gIsCtfMode) {
		StopPlugin();
		return;
	}

	precache_model(FLAG_MODEL);

	for (new i; i < sizeof VOX_SOUNDS; i++)
		precache_sound(VOX_SOUNDS[i]);

	gCvarCtfDebug = create_cvar("sv_ag_ctf_debug", "0");
	gCvarCapturePoints = create_cvar("sv_ag_ctf_capturepoints", "10");
	gCvarFlagReturnTime = create_cvar("sv_ag_ctf_flag_returntime", "30");
	gCvarFlagDelayTime = create_cvar("sv_ag_ctf_flag_delaytime", "3");
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
			team = IsPlayerCarryingFlag(id);
			if (team) {
				SetFlagCarriedByPlayer(id, 0);
				DrawFlagIcon(id, false, team);
			}
		}

		// return flag to base
		ReturnFlagToBase(gFlagBlue);
		ReturnFlagToBase(gFlagRed);
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

ParseEntFromFile(const input[], ent_name[], len, Float:ent_origin[3], Float:ent_angles[3]) {
	// We read in the next order: 1. Entity name (1 arg) 2. Entity origin (3 args) 3. Entity angles (3 args)
	// Input example: "item_flag_team1 973.734131 535.433899 36.031250 -4.268188 86.742554 0.000000"
	new arg[32], pos, argc;
	while (argc <= 6) {
		pos = argparse(input, pos, arg, charsmax(arg));
		if (pos == -1)
			break;
		if (argc == 0) { // READING ENT NAME
			copy(ent_name, len, arg);
		} else if (argc >= 1 && argc <= 3) { // READING ENT ORIGIN
			ent_origin[argc - 1] = str_to_float(arg);
		} else if (argc >= 4 && argc <= 6) { // READING ENT ANGLES
			ent_angles[argc - 4] = str_to_float(arg);
		}
		++argc;
	}

	// we didn't get to read all the arguments, bad parsing
	if (argc < 7)
		return false;
	else
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

	RegisterHam(Ham_Killed, "player", "FwPlayerKilled");

	RemoveNoTeamSpawns();

	SpawnFlag(gFlagBlue);
	SpawnFlag(gFlagRed);
	gBaseBlue = SpawnCapturePoint(gFlagBlue);
	gBaseRed = SpawnCapturePoint(gFlagRed);

	register_touch(INFO_FLAG_BLUE, "player", "FwFlagTouch");
	register_touch(INFO_FLAG_RED, "player", "FwFlagTouch");
	register_touch(INFO_CAPTURE_POINT, "player", "FwCapturePointTouch");

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
	new team = IsPlayerCarryingFlag(sender);
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
		DropFlag(id);
}

public FwCapturePointTouch(touched, toucher) {
	switch (IsPlayerCarryingFlag(toucher)) {
		case BLUE_TEAM: { // Captured Blue Team flag
			if (touched == gBaseRed) {
				DrawFlagIcon(toucher, false, BLUE_TEAM);
				SetFlagCarriedByPlayer(toucher, 0);
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
				DrawFlagIcon(toucher, false, RED_TEAM);
				SetFlagCarriedByPlayer(toucher, 0);
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
	new ent = GetFlagCarriedByPlayer(victim);
	if (!ent)
		return HAM_IGNORED;

	new classname[32];
	if (pev_valid(attacker)) {
		pev(attacker, pev_classname, classname, charsmax(classname));
	}

	if (equal(classname, "trigger_hurt")) {
		SetFlagCarriedByPlayer(victim, 0);
		ReturnFlagToBase(ent);
	} else {
		DropFlag(victim);
	}

	return HAM_IGNORED;
}

GetFlagCarriedByPlayer(id) {
	return pev(id, pev_iuser4);
}

SetFlagCarriedByPlayer(id, ent) {
	set_pev(id, pev_iuser4, ent);
}

public FwFlagTouch(touched, toucher) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("FlagTouched");

	if (GetFlagNextTouch(touched) >= get_gametime())
		return PLUGIN_HANDLED;

	if (!is_user_alive(toucher))
		return PLUGIN_HANDLED;

	new team = hl_get_user_team(toucher);

	if (touched == gFlagBlue) {
		if (team == RED_TEAM)
			TakeFlag(toucher, touched);
	} else if (touched == gFlagRed) {
		if (team == BLUE_TEAM)
			TakeFlag(toucher, touched);
	}
	return PLUGIN_CONTINUE;
}

AttachFlagToPlayer(id, ent) {
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, id);
	set_pev(ent, pev_sequence, FLAG_SEQ_CARRIED);
	set_pev(ent, pev_solid, SOLID_NOT);
}

GetFlagTeam(ent) {
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

SetFlagNextTouch(ent, Float:time) {
	set_pev(ent, pev_fuser1, get_gametime() + time);
}

Float:GetFlagNextTouch(ent) {
	return entity_get_float(ent, EV_FL_fuser1);
}

ReturnFlagToBase(ent) {
	if (get_pcvar_num(gCvarCtfDebug))
		server_print("ReturnFlagToBase");
	
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

	entity_set_size(ent, Float:{ 4.0, 4.0, 0.0 }, Float:{ 4.0, 4.0, 72.0 });

	create_teleport_splash(ent);

	SetFlagNextTouch(ent, get_pcvar_float(gCvarFlagDelayTime));

	// notify players that flag has return to base
	new team;
	switch (GetFlagTeam(ent)) {
		case BLUE_TEAM: team = RED_TEAM;
		case RED_TEAM: team = BLUE_TEAM;
	}
	
	CtfTeamHudMessage(team, "CTF_EFLAGBACK", "CTF_FLAGBACK");
	CtfTeamSpeak(team, "!CTF_EFLAGBACK", "!CTF_FLAGBACK");
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

stock DrawFlagIcon(id, bool:status, team) {
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

public TakeFlag(id, ent) {
	remove_task(ent + TASK_RETURNFLAGTOBASE);
	AttachFlagToPlayer(id, ent);
	SetFlagCarriedByPlayer(id, ent);
	DrawFlagIcon(id, true, GetFlagTeam(ent));
	CtfHudMessage(id, "CTF_YOUGOTFLAG", "CTF_GOTFLAG", "CTF_EGOTFLAG");
	CtfSpeak(id, "!CTF_YOUGOTFLAG", "!CTF_GOTFLAG", "!CTF_EGOTFLAG");
}

public TaskReturnFlagToBase(taskid) {
	new ent = taskid - TASK_RETURNFLAGTOBASE;
	ReturnFlagToBase(ent);
}

public DropFlag(id) {
	new ent = GetFlagCarriedByPlayer(id);
	SetFlagCarriedByPlayer(id, 0);
	DrawFlagIcon(id, false, GetFlagTeam(ent));

	if (!ent)
		return;

	remove_task(ent + TASK_RETURNFLAGTOBASE);
	set_task(get_pcvar_float(gCvarFlagReturnTime), "TaskReturnFlagToBase", ent + TASK_RETURNFLAGTOBASE);


	set_pev(ent, pev_aiment, 0);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_sequence, FLAG_SEQ_NOTCARRIED);
	set_pev(ent, pev_angles, 0);

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

	SetFlagNextTouch(ent, get_pcvar_float(gCvarFlagDelayTime));
	set_pev(ent, pev_solid, SOLID_TRIGGER);

	CtfTeamHudMessage(GetFlagTeam(ent), "CTF_ELOSTFLAG", "CTF_LOSTFLAG");
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

	// when flag is on ground, set a new start origin
	drop_to_floor(ent);
	pev(ent, pev_origin, origin);
	SetFlagStartOrigin(ent, origin);

	switch (GetFlagTeam(ent)) {
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

bool:array_search(value, array[], size) {
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