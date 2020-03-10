#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X Arena"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "arena"

// array size of some gamemode cvars
#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11 

#define TASK_SENDVICTIMTOSPEC 1499
#define TASK_STARTMATCH 1599
#define TASK_SENDTOSPEC 1699

#define ARRAY_NOMATCHES -1 // i use this with ArrayFindValue

// countdown sounds
new const gCountSnd[][] = {
	"barney/ba_bring", // zero
	"fvox/one", 
	"fvox/two", 
	"fvox/three", 
	"fvox/four", 
	"fvox/five", 
	"fvox/six", 
	"fvox/seven", 
	"fvox/eight", 
	"fvox/nine"
};

new const gBeepSnd[] = "fvox/beep";

// index array
enum _:AgStartWeapons {
	START_357,
	START_9MMAR,
	START_9MMHANDGUN,
	START_CROSSBOW,
	START_CROWBAR,
	START_EGON,
	START_GAUSS,
	START_HGRENADE,
	START_HORNETGUN,
	START_RPG,
	START_SATCHEL,
	START_SHOTGUN,
	START_SNARK,
	START_TRIPMINE
}

// cvars names
new const gAgStartWeapons[SIZE_WEAPONS][] = {
	"sv_ag_start_357",
	"sv_ag_start_9mmar",
	"sv_ag_start_9mmhandgun",
	"sv_ag_start_crossbow",
	"sv_ag_start_crowbar",
	"sv_ag_start_gauss",
	"sv_ag_start_egon",
	"sv_ag_start_hgrenade",
	"sv_ag_start_hornetgun",
	"sv_ag_start_rpg",
	"sv_ag_start_satchel",
	"sv_ag_start_shotgun",
	"sv_ag_start_snark",
	"sv_ag_start_tripmine",
};

// cvars names
new const gAgStartAmmo[SIZE_AMMO][] = {
	"sv_ag_start_ammo_shotgun",
	"sv_ag_start_ammo_9mm",
	"sv_ag_start_ammo_m203",
	"sv_ag_start_ammo_357",
	"sv_ag_start_ammo_gauss",
	"sv_ag_start_ammo_rpg",
	"sv_ag_start_ammo_crossbow",
	"sv_ag_start_ammo_tripmine",
	"sv_ag_start_ammo_satchel",
	"sv_ag_start_ammo_hgrenade",
	"sv_ag_start_ammo_snark",
};

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

// arena vars
new Array:gArenaQueue;
new gMatchWinner;
new gMatchLooser;
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

public OnPlayerKilled_Pre(victim, attacker) {
	set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	if (victim != attacker && IsPlayer(attacker)) {
		gMatchWinner = attacker;
		gMatchLooser = victim;
	} else if (gMatchWinner == victim)
		swap(gMatchWinner, gMatchLooser);
	
	// send looser to the end of the queue
	ArrayDeleteCell(gArenaQueue, gMatchLooser);
	ArrayPushCell(gArenaQueue, gMatchLooser);

	set_task(1.0, "EndArena");
}

/*
* Arena Mode
*/
public StartArena() {
	if (get_playersnum() > 1) {
		CountArenaQueue();

		gMatchWinner = ArrayGetCell(gArenaQueue, 0);
		gMatchLooser = ArrayGetCell(gArenaQueue, 1);

		gStartMatchTime = 5;
		ArenaCountdown();
		
	} else { // Wait for more players...
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		
		set_task(5.0, "StartArena", TASK_STARTMATCH);	
	}
}


public ArenaCountdown() {
	gStartMatchTime--;

	PlaySound(0, gCountSnd[gStartMatchTime]);

	if (gStartMatchTime == 0) {
		if (!is_user_connected(gMatchWinner) || !is_user_connected(gMatchLooser)) {
			set_task(5.0, "StartArena", TASK_STARTMATCH); // start new match after win match
			return;
		}

		if (hl_get_user_spectator(gMatchWinner))
			hl_set_user_spectator(gMatchWinner, false);
		else
			hl_user_spawn(gMatchWinner);

		hl_set_user_spectator(gMatchLooser, false);

		ResetMap();

		remove_task(TASK_STARTMATCH);

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_STARTARENA", gMatchWinner, gMatchLooser, gStartMatchTime);

	set_task(1.0, "ArenaCountdown", TASK_STARTMATCH);
}

public EndArena() {
	if (task_exists(TASK_STARTMATCH))
		return;

	new alives = GetNumAlives();

	if (alives < 2) {
		set_task(5.0, "StartArena", TASK_STARTMATCH); // start new match after win match

		if (alives == 1) { // Show winner
			if (is_user_connected(gMatchWinner))
				set_user_godmode(gMatchWinner, true); // avoid kill himself or get hurt by victim after win
			
			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.2); 
			ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER", gMatchWinner);
		} else { // No winners
			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
			ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_DRAW");
		}
	}

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

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	if (GetNumAlives() < 2) {
		if (id == gMatchWinner)
			gMatchWinner = gMatchLooser;
		EndArena();
	}
	return PLUGIN_HANDLED;
}

stock swap(&x, &y) {
	x = x + y;
	y = x - y;
	x = x - y;
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