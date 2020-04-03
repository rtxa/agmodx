#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>
#include <agmodx_const>

#define PLUGIN  "AG Mod X LTS"
#define VERSION "Beta 2.1"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "lts"

#define TASK_SENDVICTIMTOSPEC 1499
#define TASK_STARTMATCH 1599
#define TASK_SENDTOSPEC 1699

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

// gameplay cvars
new gNumTeams;
new gTeamsName[HL_MAX_TEAMS][HL_TEAMNAME_LENGTH];

// arena vars
new gStartMatchTime; 
new gHudShowMatch;

// ag hud color
new gHudRed, gHudGreen, gHudBlue;

public plugin_precache() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!IsSelectedMode(MODE_TYPE_NAME)) {
		StopPlugin();
		return;
	}

	new pHudColor = get_cvar_pointer("sv_ag_hud_color");

	new color[32];
	get_pcvar_string(pHudColor, color, charsmax(color));
	GetStrColor(color, gHudRed, gHudGreen, gHudBlue);
	
	// keep ag hud color updated
	hook_cvar_change(pHudColor, "CvarHudColorHook");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	GetTeamListModels(gTeamsName, HL_MAX_TEAMS, gNumTeams);

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", true);
	RegisterHam(Ham_Use, "func_healthcharger", "FwChargersUse");
	RegisterHam(Ham_Use, "func_recharge", "FwChargersUse");


	register_clcmd("drop", "CmdDrop");
	register_clcmd("spectate", "CmdSpectate");

	gHudShowMatch = CreateHudSyncObj();

	StartMatchLts();
}

public client_disconnected(id) {
	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);
}

public CmdDrop() {
	return PLUGIN_HANDLED;
}

public CmdSpectate() {
	// notready function has to be added
	return PLUGIN_HANDLED;
}

public FwChargersUse() {
	// block chargers
	return HAM_SUPERCEDE;
}

public OnPlayerSpawn_Pre(id) {
	// if player has to spec, don't let him spawn...
	if (task_exists(TASK_SENDVICTIMTOSPEC + id))
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public client_kill() {
	return PLUGIN_HANDLED;
}

public SendToSpec(taskid) {
	new id = taskid - TASK_SENDTOSPEC;
	if (is_user_connected(id))
		hl_set_user_spectator(id, true);
}

public SendVictimToSpec(taskid) {
	new id = taskid - TASK_SENDVICTIMTOSPEC;
	if (is_user_connected(id)) {
		if (!is_user_alive(id) || is_user_bot(id)) {
			hl_set_user_spectator(id, true);
		}
	}
}

public OnPlayerKilled_Post(victim, attacker) {
	set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	if (!PlayerKilledHimself(victim, attacker))
		player_teleport_splash(victim);
	EndMatchLts();
}

/* 
* Last Team Standing Mode
*/
public StartMatchLts() {
	// don't send to spec victims when a match is going to start
	for (new id = 1; id <= MaxClients; id++)
		remove_task(id + TASK_SENDVICTIMTOSPEC);

	// wait for more players...
	if (get_playersnum() < 2 || !IsThereEnoughPlayers()) { // i should add a message displaying there aren't enough player in one team to start...
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
		return;
	} else { // start countdown
		gStartMatchTime = 4;
		LtsMatchCountdown();
	}
}

public LtsMatchCountdown() {
	gStartMatchTime--;

	PlayNumSound(0, gStartMatchTime);

	if (gStartMatchTime == 0) {
		new players[32], numPlayers, player;
		get_players(players, numPlayers);

		ResetMap();

		for (new i; i < numPlayers; i++) {
			player = players[i];
			if (hl_get_user_spectator(player))
				hl_set_user_spectator(player, false);
			else
				hl_user_spawn(player);
		}

		remove_task(TASK_STARTMATCH);

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_START", gStartMatchTime);

	set_task(1.0, "LtsMatchCountdown", TASK_STARTMATCH);
}

SetGodModeAlives() {
	new players[MAX_PLAYERS], numPlayers;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	for (new i; i < numPlayers; i++)
		set_user_godmode(players[i], true);
}

// team index starting from 1
// if return false, it means there are 2 teams with alives player yet, or all is dead
// if returns true, means only one team is alive (in this case, the winner)
GetLastTeamStanding() {
	if (gNumTeams < 2)
		return 0;

	new team, alives;

	new matches;
	for (new i = 1; i <= gNumTeams; i++) {
		alives = ag_get_team_alives(i);
		if (alives > 0) {
			team = i;
			matches++;
		}
	}

	return matches == 1 ? team : 0;
}

// check if there is enough players (at leats 1 per team) to start the match
IsThereEnoughPlayers() {
	if (gNumTeams < 2)
		return 0;

	new matches;
	for (new i = 1; i <= gNumTeams; i++) {
		new numPlayers = ag_get_team_numplayers(i, gTeamsName);
		if (numPlayers > 0) {
			matches++;
		}
	}

	return matches >= gNumTeams ? true : false;
}

public EndMatchLts() {
	if (task_exists(TASK_STARTMATCH))
		return; // this has already been triggered, so ignore.

	if (GetNumAlives() == 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_DRAW");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
		return;
	}

	new team = GetLastTeamStanding();
	
	if (team) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER_TEAM", gTeamsName[team - 1]);
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	} 
}

public client_putinserver(id) {
	set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid some scoreboard glitchs
}

stock bool:PlayerKilledHimself(victim, attacker) {
	return (!IsPlayer(attacker) || victim == attacker); // attacker can be worldspawn if player dies by fall
}

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	EndMatchLts();
	return PLUGIN_HANDLED;
}

stock player_teleport_splash(id) {
	if (!is_user_connected(id))
		return 0;

	new origin[3];
	get_user_origin(id, origin);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_TELEPORT);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2]);
	message_end();

	return 1;
}

public CvarHudColorHook(pcvar, const old_value[], const new_value[]) {
	GetStrColor(new_value, gHudRed, gHudGreen, gHudBlue);
}
