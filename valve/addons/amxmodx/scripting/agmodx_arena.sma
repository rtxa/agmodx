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

#define PLUGIN  "AG Mod X Arena"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "arena"

// TaskIDs
enum (+=100) {
	TASK_SENDVICTIMTOSPEC = 1499,
	TASK_ARENACOUNTDOWN,
	TASK_STARTMATCH,
	TASK_ENDMATCH,
	TASK_SENDTOSPEC
};

#define MATCH_WAITING_Y 0.2
#define MATCH_WINNER_Y 0.2
#define MATCH_START_Y 0.2

#define ARRAY_NOMATCHES -1 // i use this with ArrayFindValue

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

// arena vars
new Array:gArenaQueue;

new gMatchWinner;
new gMatchWinnerName[32];

new gFirstPlayer;
new gSecondPlayer;

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

	new color[12];
	get_pcvar_string(get_cvar_pointer("sv_ag_hud_color"), color, charsmax(color));
	SetHudColorCvarByString(color, gHudRed, gHudGreen, gHudBlue);

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre");
	RegisterHam(Ham_Use, "func_healthcharger", "FwChargersUse");
	RegisterHam(Ham_Use, "func_recharge", "FwChargersUse");

	register_clcmd("drop", "CmdDrop");
	register_clcmd("spectate", "CmdSpectate");

	gHudShowMatch = CreateHudSyncObj();
	gArenaQueue = ArrayCreate();

	StartArena();
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

public FwChargersUse() {
	// block chargers
	return HAM_SUPERCEDE;
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
		if (!is_user_alive(id) || is_user_bot(id)) {
			hl_set_user_spectator(id, true);
		}
	}
}

HasVictimToSpec(id) {
	return task_exists(TASK_SENDVICTIMTOSPEC + id);
}

public OnPlayerKilled_Pre(victim, attacker) {	
	gMatchWinner = attacker;

	if (victim == attacker || !IsPlayer(attacker)) {
		if (!GetNumAlives()) { // if both player are dead, then no winners...
			gMatchWinner = 0;
		} else if (gFirstPlayer == victim)
			gMatchWinner = gSecondPlayer;
		else if (gSecondPlayer == victim) {
			gMatchWinner = gFirstPlayer;
		}
	}

	// send looser to the end of the queue
	ArrayDeleteCell(gArenaQueue, victim);
	ArrayPushCell(gArenaQueue, victim);

	set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);
	set_task(4.0, "EndArena", TASK_ENDMATCH);
}

/*
* Arena Mode
*/
public StartArena() {
	if (task_exists(TASK_STARTMATCH)) {
		return;
	}


	if (get_playersnum() > 1) {
		CountArenaQueue();

		// get the players so we can show their name
		gFirstPlayer = ArrayGetCell(gArenaQueue, 0);
		gSecondPlayer = ArrayGetCell(gArenaQueue, 1);

		gMatchWinner = 0;

		gStartMatchTime = 3;
		ArenaCountdown();
		
	} else { // Wait for more players...
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, MATCH_WAITING_Y, 0, 2.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		set_task(5.0, "StartArena", TASK_STARTMATCH);	
	}
}


public ArenaCountdown() {
	if (!is_user_connected(gFirstPlayer) || !is_user_connected(gSecondPlayer)) {
		set_task(3.0, "StartArena", TASK_STARTMATCH); // start new match after win match
		return;
	}

	PlaySound(0, gCountSnd[gStartMatchTime]);

	if (gStartMatchTime == 0) {
		// Spawn players
		if (hl_get_user_spectator(gFirstPlayer))
			hl_set_user_spectator(gFirstPlayer, false);
		else
			hl_user_spawn(gFirstPlayer);

		hl_set_user_spectator(gSecondPlayer, false);

		ResetMap();

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, MATCH_START_Y, 0, 3.0, 4.0, 0.2, 0.5, -1); 
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_STARTARENA", gFirstPlayer, gSecondPlayer, gStartMatchTime);

	set_task(1.0, "ArenaCountdown", TASK_ARENACOUNTDOWN);

	gStartMatchTime--;
}

public EndArena() {
	if (task_exists(TASK_STARTMATCH))
		return;

	set_task(5.0, "StartArena", TASK_STARTMATCH); // start new match after win match

	if (!gMatchWinner) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, MATCH_WINNER_Y, 0, 3.0, 4.0, 0.2, 0.2); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_NOWINNER");
		return;
	}
	
	if (is_user_connected(gMatchWinner)) {
		get_user_name(gMatchWinner, gMatchWinnerName, charsmax(gMatchWinnerName)); 
		set_user_godmode(gMatchWinner, true); // give inmmunity to player after win
	}

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, MATCH_WINNER_Y, 0, 3.0, 4.0, 0.2, 0.2);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER", gMatchWinnerName);

}

/* This add new players to the queue and removes the disconnected players.
 */
public CountArenaQueue() {
	for (new id = 1; id <= MaxClients; id++) { 
		if (is_user_connected(id)) {
			if (ArrayFindValue(gArenaQueue, id) == ARRAY_NOMATCHES)
				ArrayPushCell(gArenaQueue, id);
		} else {
			ArrayDeleteCell(gArenaQueue, id);
		}
	}
}

ArrayDeleteCell(Array:handle, value) {
	new idx = ArrayFindValue(handle, value);
	if (idx != ARRAY_NOMATCHES)
		ArrayDeleteItem(handle, idx);
}

public PrintArenaQueue() {
	for (new i; i < ArraySize(gArenaQueue); i++) {
		server_print("i. %i", ArrayGetCell(gArenaQueue, i));
	}
}


// SI no es arena realmente, parar le modo con amx_pausecfg stop nombredelplugin
public client_putinserver(id) {
	set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid some scoreboard glitchs
	CountArenaQueue();
}

public client_disconnected(id) {
	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);

	if (gMatchWinner == id) {
		get_user_name(id, gMatchWinnerName, charsmax(gMatchWinnerName));
	}
}

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	CountArenaQueue();
	if (GetNumAlives() < 2) {
		if (!gMatchWinner) {
			if (!task_exists(TASK_STARTMATCH))
				set_task(5.0, "StartArena", TASK_STARTMATCH);
		} else {
			if (!task_exists(TASK_ENDMATCH)) {
				set_task(3.0, "EndArena", TASK_ENDMATCH);
			}
		}
	}
	return PLUGIN_HANDLED;
}

PlaySound(id, const sound[]) {
	new snd[128];
	RemoveExtension(sound, snd, charsmax(snd), ".wav"); // // Remove .wav file extension (console starts to print "missing sound file _period.wav" for every sound)
	client_cmd(id, "spk %s", snd);
}

stock GetNumAlives() {
	new alives[32], numAlives;
	get_players(alives, numAlives, "a");
	return numAlives;
}

stock RemoveExtension(const input[], output[], length, const ext[]) {
	copy(output, length, input);

	new idx = strlen(input) - strlen(ext);
	if (idx < 0) return 0;
	
	return replace(output[idx], length, ext, "");
}

SetHudColorCvarByString(const color[], &red, &green, &blue) {
	new r[4], g[4], b[4];

	parse(color, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	red = str_to_num(r);
	green = str_to_num(g);
	blue = str_to_num(b);
}