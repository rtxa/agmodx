#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx>
#include <agmodx_stocks>
#include <agmodx_const>

#define PLUGIN  "AG Mod X Arena"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "arena"

// TaskIDs
enum (+=100) {
	TASK_SENDVICTIMTOSPEC = 1499,
	TASK_COUNTDOWN,
	TASK_WAITINGPLAYERS,
	TASK_ENDMATCH,
	TASK_SENDTOSPEC
};

#define HUD_MATCH_POS_Y 0.2

#define ARRAY_NOMATCHES -1 // i use this with ArrayFindValue

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

// arena vars
new Array:gArenaQueue;

new stock bool:gIsNotReady[MAX_PLAYERS + 1];

new bool:gMatchStarted;
new gMatchWinner;
new gMatchWinnerName[32];

new gFirstPlayer;
new gSecondPlayer;

new gStartMatchTime; 
new gHudShowMatch;

// ag hud color
new gHudRed, gHudGreen, gHudBlue;

public plugin_precache() {
	register_plugin(PLUGIN, AGMODX_VERSION, AUTHOR);

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
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", true);

	register_clcmd("drop", "CmdDrop");
	register_clcmd("spectate", "CmdSpectate");
	register_clcmd("ready", "CmdReady");
	register_clcmd("notready", "CmdNotReady");

	gHudShowMatch = CreateHudSyncObj();
	gArenaQueue = ArrayCreate();

	DisableVote("agstart", "OnVoteNotAllowed");
	DisableVote("agpause", "OnVoteNotAllowed");
	DisableVote("agallow", "OnVoteNotAllowed");

	// blocks player score reset from the core
	set_cvar_num("sv_ag_core_block_spec", 1);

	Arena_WaitingPlayers();
}

public OnVoteNotAllowed(id) {
	console_print(id, "%l", "VOTE_NOTALLOWED_GAMEMODE");
	return false;
}

public plugin_end() {
	ArrayDestroy(gArenaQueue);
}

public CmdDrop() {
	return PLUGIN_HANDLED;
}

public CmdSpectate() {
	// notready function has to be added
	return PLUGIN_HANDLED;
}

public CmdReady(id) {
	// player is already in ready state, ignore
	if (!gIsNotReady[id]) {
		return PLUGIN_HANDLED;
	}

	gIsNotReady[id] = false;
	console_print(id, "%l", "NOTREADY_OFF");

	// update arena list now, otherwise player will be added to the waiting list
	// when a new round is about to start, making him wait more longer than expected
	Arena_UpdatePlayerList();

	return PLUGIN_HANDLED;
}

public CmdNotReady(id) {
	// player is already in not ready state, ignore
	if (gIsNotReady[id]) {
		return PLUGIN_HANDLED;
	}

	new isPlayerSelected = id == gFirstPlayer || id == gSecondPlayer;

	if (isPlayerSelected && task_exists(TASK_COUNTDOWN)) {
		// can't change to not ready when player has been selected to play a match
		console_print(id, "%l", "NOTREADY_INVALIDATE");
		return PLUGIN_HANDLED;
	}
	
	// finally, set player to not ready mode state
	gIsNotReady[id] = true;
	console_print(id, "%l", "NOTREADY_ON");

	return PLUGIN_HANDLED;
}

public OnPlayerSpawn_Pre(id) {
	if (HasVictimToSpec(id))
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
		hl_set_user_spectator(id, true);
	}
}

HasVictimToSpec(id) {
	return task_exists(TASK_SENDVICTIMTOSPEC + id);
}

public OnPlayerKilled_Post(victim, attacker) {		
	// if it pass the checks, then we are sure the winner is the attacker
	gMatchWinner = attacker;

	if (GetNumAlives() == 0) {
		gMatchWinner = 0;
	} else if (victim == attacker || !IsPlayer(attacker)) { // player killed himself or by the world
		if (gFirstPlayer == victim)
			gMatchWinner = gSecondPlayer;
		else if (gSecondPlayer == victim) {
			gMatchWinner = gFirstPlayer;
		}
	}

	// send looser to the end of the queue
	ArrayDeleteCell(gArenaQueue, victim);
	ArrayPushCell(gArenaQueue, victim);

	set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	if (!task_exists(TASK_ENDMATCH))
		set_task(3.0, "Arena_EndMatch", TASK_ENDMATCH);
}

/**
 * Gets the number of players playing arena
 * @note Not ready players aren't included
 */
Arena_GetNumPlayers() {
	new players[MAX_PLAYERS], numPlayers;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeHLTV);

	new num = 0;
	new id = 0;
	for (new i = 0; i < numPlayers; i++) {
		id = players[i];
		if (!gIsNotReady[id]) {
			num++;
		}
	}

	return num;
}

public Arena_WaitingPlayers() {
	// Wait for more players...
	if (Arena_GetNumPlayers() < 2) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, HUD_MATCH_POS_Y, 0, 2.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		set_task(5.0, "Arena_WaitingPlayers", TASK_WAITINGPLAYERS);
		return;
	}

	Arena_UpdatePlayerList();

	// get the players so we can show their name
	gFirstPlayer = ArrayGetCell(gArenaQueue, 0);
	gSecondPlayer = ArrayGetCell(gArenaQueue, 1);

	gMatchWinner = 0;

	gStartMatchTime = 3;
	Arena_CountDown();
}

public Arena_StartMatch() {
	gMatchStarted = true;

	ClearSyncHud(0, gHudShowMatch);

	// Send to spec to all, except the winner
	// A player who has won the previous match and is now not ready can still be alive
	SendAlivesToSpec(gFirstPlayer);

	// Spawn players
	if (hl_get_user_spectator(gFirstPlayer))
		hl_set_user_spectator(gFirstPlayer, false);
	else
		hl_user_spawn(gFirstPlayer);

	hl_set_user_spectator(gSecondPlayer, false);

	ResetMap();
}

public Arena_CountDown() {
	// If any of the match players have disconnect, start to look for new players again
	if (!is_user_connected(gFirstPlayer) || !is_user_connected(gSecondPlayer)) {
		ClearSyncHud(0, gHudShowMatch);
		if (!task_exists(TASK_WAITINGPLAYERS))
			set_task(3.0, "Arena_WaitingPlayers", TASK_WAITINGPLAYERS);
		return;
	}

	PlayNumSound(0, gStartMatchTime);

	if (gStartMatchTime == 0) {
		Arena_StartMatch();
		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, HUD_MATCH_POS_Y, 0, 3.0, 10.0, 0.2, 0.5); 
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_STARTARENA", gFirstPlayer, gSecondPlayer, gStartMatchTime);

	set_task(1.0, "Arena_CountDown", TASK_COUNTDOWN);

	gStartMatchTime--;
}

public Arena_EndMatch() {
	if (task_exists(TASK_WAITINGPLAYERS))
		return;

	gMatchStarted = false;

	set_task(3.0, "Arena_WaitingPlayers", TASK_WAITINGPLAYERS); // start new match after win match

	if (!gMatchWinner) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, HUD_MATCH_POS_Y, 0, 3.0, 4.0, 0.2, 0.2); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_NOWINNER");
		return;
	}
	
	if (is_user_connected(gMatchWinner)) {
		get_user_name(gMatchWinner, gMatchWinnerName, charsmax(gMatchWinnerName)); 
		set_user_godmode(gMatchWinner, true); // give inmmunity to player after win
	}

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, HUD_MATCH_POS_Y, 0, 3.0, 4.0, 0.2, 0.2);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER", gMatchWinnerName);

}

/* This add new players to the queue and removes the disconnected players.
 */
public Arena_UpdatePlayerList() {
	new bool:isPlayerOnArray = false;
	new idx = 0;
	for (new id = 1; id <= MaxClients; id++) { 
		idx = ArrayFindValue(gArenaQueue, id);
		isPlayerOnArray = idx != ARRAY_NOMATCHES;
	
		// Remove disconnected or not ready players from count if any
		if (!is_user_connected(id) || is_user_hltv(id) || gIsNotReady[id]) {
			if (isPlayerOnArray) {
				ArrayDeleteItem(gArenaQueue, idx);
			}
			continue;
		}

		// Put him in the queue if he isn't already in it
		if (!isPlayerOnArray) {
			ArrayPushCell(gArenaQueue, id);
		}
	}
}

ArrayDeleteCell(Array:handle, value) {
	new idx = ArrayFindValue(handle, value);
	if (idx != ARRAY_NOMATCHES)
		ArrayDeleteItem(handle, idx);
}

public client_putinserver(id) {
	set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid scoreboard glitchs
	Arena_UpdatePlayerList();
}

public client_disconnected(id) {
	// Reset flags and remove pending tasks when player leaves
	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);
	gIsNotReady[id] = false;

	if (gMatchWinner == id) {
		get_user_name(id, gMatchWinnerName, charsmax(gMatchWinnerName));
	}
}

// aca esta el bug, hay q usar el gMatchStarted, cuando se desocneca el player y aun sigue vivo
public client_remove(id) {
	Arena_UpdatePlayerList();

	if (task_exists(TASK_COUNTDOWN)) {
		// player to start match have disconnect, so cancel the countdown
		if (id == gFirstPlayer || id == gSecondPlayer) {
			gFirstPlayer = gSecondPlayer = 0;
			return;
		}
	}

	if (gMatchStarted) {
		if (!task_exists(TASK_ENDMATCH)) {
			if (gMatchWinner == id) {
				gMatchWinner = 0;
			}
			if (GetNumAlives() < 2) {
				SetGodModeAlives();
				set_task(3.0, "Arena_EndMatch", TASK_ENDMATCH);
			}
		}
	}
}

SetGodModeAlives() {
	new players[MAX_PLAYERS], numPlayers;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	for (new i; i < numPlayers; i++)
		set_user_godmode(players[i], true);
}

/**
 * This will send to spectate mode to anyone alive
 * @note You can specify a player to not be send to spec
 */
SendAlivesToSpec(ignoredPlayer = 0) {
	new players[MAX_PLAYERS], num;
	get_players_ex(players, num, GetPlayers_ExcludeDead);
	new player;
	for (new i = 0; i < num; i++) {
		player = players[i];
		if (player != ignoredPlayer) {
			hl_set_user_spectator(player);
		}
	}
}

public CvarHudColorHook(pcvar, const old_value[], const new_value[]) {
	GetStrColor(new_value, gHudRed, gHudGreen, gHudBlue);
}
