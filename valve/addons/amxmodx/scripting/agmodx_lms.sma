#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <hl>
#include <fun>
#include <agmodx_stocks>

#define PLUGIN  "AG Mod X LMS"
#define VERSION "2.0"
#define AUTHOR  "rtxa"

#pragma semicolon 1

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

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

new const gWeaponClass[][] = {
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_crowbar",
	"weapon_gauss",
	"weapon_egon",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine"
};

new bool:gIsLmsMode;
new bool:gGamePlayerEquipExists;

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];

new gCvarStartHealth;
new gCvarStartArmor;
new gCvarStartLongJump;

// gameplay cvars

// arena vars
new gStartMatchTime; 
new gHudShowMatch;

// ag hud color
new gHudRed, gHudGreen, gHudBlue;

// To do: use a native to check if ag mod x is on, or to check if normal ag mod is being use
bool:IsLmsMode() {
	new type[32];
	get_cvar_string("sv_ag_gametype", type, charsmax(type));

	if (equal(type, "lms"))
		return true;

	return false;
}

public plugin_precache() {
	// maybe add a check to detect ag mod x is on, if it's on, then it means all cvars are registred and safe to use, or in plugins.ini this always has to be after
	gIsLmsMode = IsLmsMode();

	if (!gIsLmsMode) {
		StopPlugin();
		return;
	}

	gCvarStartLongJump = get_cvar_pointer("sv_ag_start_longjump");
	gCvarStartHealth = get_cvar_pointer("sv_ag_start_health");
	gCvarStartArmor = get_cvar_pointer("sv_ag_start_armor");

	new color[12];
	get_pcvar_string(get_cvar_pointer("sv_ag_hud_color"), color, charsmax(color));
	SetHudColorCvarByString(color, gHudRed, gHudGreen, gHudBlue);

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = get_cvar_pointer(gAgStartWeapons[i]);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = get_cvar_pointer(gAgStartAmmo[i]);
}

stock StopPlugin() {
	new pluginName[32];
	get_plugin(-1, pluginName, sizeof(pluginName));
	pause("d", pluginName);
	return;
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	if (!gIsLmsMode) {
		StopPlugin();
		return;
	}

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Pre");
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", true);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre");
	RegisterHam(Ham_Use, "func_healthcharger", "FwChargersUse");
	RegisterHam(Ham_Use, "func_recharge", "FwChargersUse");

	register_clcmd("drop", "CmdDrop");
	register_clcmd("spectate", "CmdSpectate");

	gHudShowMatch = CreateHudSyncObj();

	SetGameModePlayerEquip();

	StartMatchLms();
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

public OnPlayerSpawn_Post(id) {
	if (is_user_alive(id) && !gGamePlayerEquipExists) // what happens if users spawn dead? it's just a prevention.
		SetPlayerEquipment(id); // note: this doesn't have effect on pre spawn
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

ResetBpAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // some maps like bootbox dont like this if i dont put this condition
			set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_pcvar_num(gCvarStartAmmo[i]), i + 1);
	}
}

SetPlayerEquipment(id) {
	set_user_health(id, get_pcvar_num(gCvarStartHealth));
	set_user_armor(id, get_pcvar_num(gCvarStartArmor));

	if (get_pcvar_bool(gCvarStartLongJump))
		hl_set_user_longjump(id, true);

	ResetBpAmmo(id);
}

/*
* Set player equipment of current gamemode
*/
SetGameModePlayerEquip() {
	new ent = find_ent_by_class(0, "game_player_equip");

	if (!ent) {
		ent = create_entity("game_player_equip");
	} else {
		gGamePlayerEquipExists = true;
		return;
	}

	for (new i; i < SIZE_WEAPONS; i++) {
		// If the map has a game_player_equip, ignore gamemode cvars (this will avoid problems in maps like 357_box or bootbox)
		if (get_pcvar_num(gCvarStartWeapons[i]))
			DispatchKeyValue(ent, gWeaponClass[i], "1");
	}
}


/* 
* Last Man Standing Mode
*/
public StartMatchLms() {
	gIsLmsMode = true;

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

		EndMatchLms();

		ResetMap();

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
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