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

#define PLUGIN  "AG Mod X LMS"
#define VERSION "Beta 2.1"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "lms"

#define TASK_SENDVICTIMTOSPEC 1499
#define TASK_STARTMATCH 1599
#define TASK_SENDTOSPEC 1699

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

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
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre");
	
	register_clcmd("drop", "CmdDrop");
	register_clcmd("spectate", "CmdSpectate");

	gHudShowMatch = CreateHudSyncObj();

	DisableVote("agstart", "OnVoteNotAllowed");
	DisableVote("agpause", "OnVoteNotAllowed");
	DisableVote("agallow", "OnVoteNotAllowed");

	StartMatchLms();
}

public OnVoteNotAllowed(id) {
	console_print(id, "%l", "VOTE_NOTALLOWED_GAMEMODE");
	return false;
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

public OnPlayerKilled_Pre(victim, attacker) {
	set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	if (!PlayerKilledHimself(victim, attacker))
		player_teleport_splash(victim);
	EndMatchLms();
}

/* 
* Last Man Standing Mode
*/
public StartMatchLms() {
	if (get_playersnum() < 2) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		set_task(5.0, "StartMatchLms", TASK_STARTMATCH);
		return;
	}

	gStartMatchTime = 5;
	LmsMatchCountdown();	
}

public LmsMatchCountdown() {
	gStartMatchTime--;

	PlayNumSound(0, gStartMatchTime);

	if (gStartMatchTime == 0) {
		ClearSyncHud(0, gHudShowMatch);

		new players[32], numPlayers, player;
		get_players(players, numPlayers);

		for (new i; i < numPlayers; i++) {
			player = players[i];
			if (hl_get_user_spectator(player))
				hl_set_user_spectator(player, false);
			else
				hl_user_spawn(player);
		}

		remove_task(TASK_STARTMATCH);

		EndMatchLms();

		ResetMap();

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 10.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_START", gStartMatchTime);

	set_task(1.0, "LmsMatchCountdown", TASK_STARTMATCH);
}

public EndMatchLms() {
	if (task_exists(TASK_STARTMATCH))
		return;

	new alive[MAX_PLAYERS], numAlives, player;
	get_players_ex(alive, numAlives, GetPlayers_ExcludeDead);

	switch (numAlives) {
		case 1: {
			player = alive[0];
			set_user_godmode(player, true);

			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5); 
			ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER", player);

			set_task(5.0, "StartMatchLms", TASK_STARTMATCH);	
		} 
		case 0: {
			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
			ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_DRAW");

			set_task(5.0, "StartMatchLms", TASK_STARTMATCH);
		}
	}
}

// SI no es arena realmente, parar le modo con amx_pausecfg stop nombredelplugin
public client_putinserver(id) {
	set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid some scoreboard glitchs
}

stock bool:PlayerKilledHimself(victim, attacker) {
	return (!IsPlayer(attacker) || victim == attacker); // attacker can be worldspawn if player dies by fall
}

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	EndMatchLms();
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
