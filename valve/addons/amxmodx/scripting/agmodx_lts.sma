#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hlstocks>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X LTS"
#define VERSION "Beta 2.0"
#define AUTHOR  "rtxA"

#pragma semicolon 1

#define MODE_TYPE_NAME "lts"

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

// gameplay cvars
new gTeamListModels[HL_MAX_TEAMS][HL_TEAMNAME_LENGTH];

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

	new color[12];
	get_pcvar_string(get_cvar_pointer("sv_ag_hud_color"), color, charsmax(color));
	SetHudColorCvarByString(color, gHudRed, gHudGreen, gHudBlue);

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

public plugin_init() {
	GetTeamListModels(gTeamListModels, HL_MAX_TEAMS);

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre");
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

public OnPlayerKilled_Pre(victim, attacker) {
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

	new numBlue = ag_get_team_numplayers(1, gTeamListModels);
	new numRed = ag_get_team_numplayers(2, gTeamListModels);

	if (get_playersnum() < 2 || numBlue < 1 || numRed < 1) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WAITING");
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
		return;
	}

	gStartMatchTime = 5;
	LtsMatchCountdown();
}

public LtsMatchCountdown() {
	gStartMatchTime--;

	PlaySound(0, gCountSnd[gStartMatchTime]);

	if (gStartMatchTime == 0) {
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

		EndMatchLts();

		ResetMap();

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

public EndMatchLts() {
	if (task_exists(TASK_STARTMATCH))
		return; // this has already been triggered, so ignore.

	new numAlivesBlue = ag_get_team_alives(1);
	new numAlivesRed = ag_get_team_alives(2);
	
	if (numAlivesBlue == 0 && numAlivesRed > 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER_RED");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	} else if (numAlivesRed == 0 && numAlivesBlue > 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_WINNER_BLUE");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	} else if (numAlivesRed == 0 && numAlivesBlue == 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_DRAW");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
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
	EndMatchLts();
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