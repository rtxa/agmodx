/*
	Adrenaline Gamer Mod X by rtxa

	Acknowledgements:
	Bullit for creating Adrenaline Gamer
	Lev for his Bugfixed and Improved HL Release
	KORD_27 for his hl.inc

	Information:
	An improved Mini AG alternative, made as a plugin for AMX Mod X from zero, to make it easier add improvements, features, fix annoying bugs, etc.
	
	Features:
	AMX Mod X 1.9 or newer
	Bugfixed and Improved HL Release
	Multilingual (Spanish and English 100%)

	More info in: aghl.ru/forum/viewtopic.php?f=19&t=2926
	Contact: usertxa@gmail.com or Discord rtxa#6795
*/

#include <agmodx>
#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hlstocks>

#define PLUGIN  "AG Mod X"
#define VERSION "Beta 1.4"
#define AUTHOR  "rtxa"

#pragma semicolon 1

// TaskIDs
enum (+=100) {
	TASK_STARTMATCH = 1000,
	TASK_STARTVERSUS,
	TASK_SENDVICTIMTOSPEC,
	TASK_SENDTOSPEC,
	TASK_SHOWVOTE,
	TASK_SHOWSETTINGS,
	TASK_DENYVOTE,
	TASK_TIMELEFT
};

new const gHelpList[][] = {
	"agabort",
	"agallow",
	"agnextmap",
	"agnextmode",
	"agpause",
	"agstart",
	"no",
	"settings",
	"vote",
	"yes",
};

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

#define ARRAY_NOMATCHES -1 // i use this with ArrayFindValue

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

// Team models (this is used to fix team selection from VGUI Viewport)
new gTeamListModels[HL_MAX_TEAMS][HL_MAX_TEAMNAME_LENGTH];

// Location system
new gLocationName[128][32]; 		// Max locations (128) and max location name length (32);
new Float:gLocationOrigin[128][3]; 	// Max locations and origin (x, y, z)
new gNumLocations;

#define TIMELEFT_SETUNLIMITED -1

// timeleft / timelimit system
new gTimeLeft; // if timeleft is set to -1, it means unlimited time
new gTimeLimit;

new cvarhook:gHookCvarTimeLimit;

// ag hud color
new gHudRed, gHudGreen, gHudBlue;

// play_team cmd
new Float:gPlayTeamDelayTime[33];
	
// gamerules flags
new bool:gBlockCmdKill;
new bool:gBlockCmdSpec;
new bool:gBlockCmdDrop;
new bool:gBlockPlayerSpawn;
new bool:gSendVictimToSpec;
new bool:gSendConnectingToSpec;
new bool:gRestorePlayerEquipOnKill;
new bool:gGamePlayerEquipExists;

// gamemode flags
new bool:gIsArenaMode;
new bool:gIsLtsMode;
new bool:gIsLmsMode;

// arena vars
new Array:gArenaQueue;
new gMatchWinner;
new gMatchLooser;

// agstart
new bool:gVersusStarted;
new gStartVersusTime;

// for arena and lts/lms
new gStartMatchTime; 

// hud sync handles
new gHudShowVote;
new gHudShowMatch;
new gHudShowTimeLeft;

// agpause
new bool:gIsPause;

new gGameModeList[32][32];
new gGameModeName[32];

// restore score system: array index
#define SCORE_FRAGS 0
#define SCORE_DEATHS 1
new Trie:gTrieScoreAuthId; // handle where it saves all the authids of players playing a versus for rescore system...

// vote system
#define VOTE_YES 1
#define VOTE_NO -1
new Trie:gTrieVoteList;
new bool:gVoteStarted;
new Float:gVoteFailedTime; // in seconds
new gVotePlayers[33]; // 1: vote yes; 0: didn't vote; -1; vote no; 
new gVoteCallerName[MAX_NAME_LENGTH];
new gVoteCallerUserId;
new gVoteArg1[32];
new gVoteArg2[32];
new gVoteOptionFwHandle;
new gNumVoteArgs;

// array size of some gamemode cvars
#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11 
#define SIZE_BANWEAPONS 14
#define SIZE_AMMOENTS 9

// cvar pointers
new gCvarDebugVote;
new gCvarContact;
new gCvarGameMode;
new gCvarGameType;
new gCvarHudColor;
new gCvarSpecTalk;
new gCvarAllowVote;
new gCvarVoteFailedTime;
new gCvarVoteDuration;
new gCvarAgStartMinPlayers;
new gCvarAgStartAllowUnlimited;
new gCvarAmxNextMap;

new gCvarBunnyHop;
new gCvarFallDamage;
new gCvarFlashLight;
new gCvarFootSteps;
new gCvarForceRespawn;
new gCvarFragLimit;
new gCvarFriendlyFire;
new gCvarSelfGauss;
new gCvarTimeLimit;
new gCvarWeaponStay;
new gCvarHeadShot;

new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];
new gCvarStartHealth;
new gCvarStartArmor;
new gCvarStartLongJump;

new gCvarBanWeapons[SIZE_BANWEAPONS];
new gCvarBanAmmo[SIZE_AMMOENTS];
new gCvarBanBattery;
new gCvarBanHealthKit;
new gCvarBanLongJump;
new gCvarBanHevCharger;
new gCvarBanHealthCharger;
new gCvarReplaceEgonWithAmmo;

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

// cvars names
new const gAgBanWeapons[SIZE_BANWEAPONS][] = {
	"sv_ag_ban_357",
	"sv_ag_ban_9mmar",
	"sv_ag_ban_9mmhandgun",
	"sv_ag_ban_crossbow",
	"sv_ag_ban_crowbar",
	"sv_ag_ban_egon",
	"sv_ag_ban_gauss",
	"sv_ag_ban_hgrenade",
	"sv_ag_ban_hornetgun",
	"sv_ag_ban_rpg",
	"sv_ag_ban_satchel",
	"sv_ag_ban_shotgun",
	"sv_ag_ban_snark",
	"sv_ag_ban_tripmine",	
};	

// cvars names
new const gAgBanAmmo[SIZE_AMMOENTS][] = {
	"sv_ag_ban_ammo_357",		
	"sv_ag_ban_ammo_9mm",
	"sv_ag_ban_ammo_9mm",	
	"sv_ag_ban_ammo_9mm",		
	"sv_ag_ban_ammo_m203",	
	"sv_ag_ban_ammo_crossbow",	
	"sv_ag_ban_ammo_gauss",	
	"sv_ag_ban_ammo_rpg",		
	"sv_ag_ban_ammo_shotgun"	
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

new const gAmmoClass[][] = {
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_buckshot",
	"ammo_crossbow",
	"ammo_gaussclip",
	"ammo_rpgclip"
};

new const gClearFieldEntsClass[][] = {
	"bolt",
	"monster_snark",
	"monster_satchel",
	"monster_tripmine",
	"beam", // this removes beam of tripmine
	"weaponbox"
};

public plugin_precache() {
	// AG Mod X Version
	create_cvar("agmodx_version", VERSION, FCVAR_SERVER);

	gCvarContact = get_cvar_pointer("sv_contact");

	gCvarDebugVote = create_cvar("sv_ag_debug_vote", "0", FCVAR_SERVER);

	// Chat cvar
	gCvarSpecTalk = create_cvar("sv_ag_spectalk", "0", FCVAR_SERVER | FCVAR_SPONLY);

	// Agstart cvars
	gCvarAgStartMinPlayers = create_cvar("sv_ag_agstart_minplayers", "2", FCVAR_SERVER);
	gCvarAgStartAllowUnlimited = create_cvar("sv_ag_agstart_allowunlimited", "0", FCVAR_SERVER); // block start versus with unlimited time
	
	// Vote cvars
	gCvarAllowVote = create_cvar("sv_ag_allow_vote", "1", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarVoteFailedTime = create_cvar("sv_ag_vote_failed_time", "15", FCVAR_SERVER | FCVAR_SPONLY, "", true, 0.0, true, 999.0);
	gCvarVoteDuration = create_cvar("sv_ag_vote_duration", "30", FCVAR_SERVER, "", true, 0.0, true, 999.0);

	// Gamemode cvars
	gCvarGameMode = create_cvar("sv_ag_gamemode", "tdm", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarGameType = create_cvar("sv_ag_gametype", "", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarStartHealth = create_cvar("sv_ag_start_health", "100");
	gCvarStartArmor = create_cvar("sv_ag_start_armor", "0");
	gCvarStartLongJump = create_cvar("sv_ag_start_longjump", "0");
	gCvarBanHealthKit = create_cvar("sv_ag_ban_healthkit", "0");
	gCvarBanBattery = create_cvar("sv_ag_ban_battery", "0");
	gCvarBanLongJump = create_cvar("sv_ag_ban_longjump", "0");
	gCvarBanHealthCharger = create_cvar("sv_ag_ban_healthcharger", "0");
	gCvarBanHevCharger = create_cvar("sv_ag_ban_hevcharger", "0");
	gCvarReplaceEgonWithAmmo = create_cvar("sv_ag_replace_egonwithammo", "0");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = create_cvar(gAgStartWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = create_cvar(gAgStartAmmo[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanWeapons; i++)
		gCvarBanWeapons[i] = create_cvar(gAgBanWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanAmmo; i++)
		gCvarBanAmmo[i] = create_cvar(gAgBanAmmo[i], "0", FCVAR_SERVER);

	// Multiplayer cvars
	gCvarHeadShot = create_cvar("mp_headshot", "1.0", FCVAR_SERVER);
	gCvarBunnyHop = get_cvar_pointer("mp_bunnyhop");
	gCvarFallDamage = get_cvar_pointer("mp_falldamage");
	gCvarFlashLight = get_cvar_pointer("mp_flashlight");
	gCvarFootSteps = get_cvar_pointer("mp_footsteps");
	gCvarForceRespawn = get_cvar_pointer("mp_forcerespawn");
	gCvarFragLimit = get_cvar_pointer("mp_fraglimit");
	gCvarFriendlyFire = get_cvar_pointer("mp_friendlyfire");
	gCvarSelfGauss = get_cvar_pointer("mp_selfgauss");
	gCvarTimeLimit = get_cvar_pointer("mp_timelimit");
	gCvarWeaponStay = get_cvar_pointer("mp_weaponstay");

	// AG Hud Color
	gCvarHudColor = create_cvar("sv_ag_hud_color", "255 255 0", FCVAR_SERVER | FCVAR_SPONLY); // yellow

	new color[12];
	get_pcvar_string(gCvarHudColor, color, charsmax(color));
	SetHudColorCvarByString(color, gHudRed, gHudGreen, gHudBlue);

	// Load mode cvars
	new mode[32];
	get_pcvar_string(gCvarGameMode, mode, charsmax(mode));

	server_cmd("exec gamemodes/%s.cfg", mode);
	server_exec();
}

public plugin_natives() {
	register_native("ag_vote_add", "native_ag_vote_add");
	register_native("ag_vote_remove", "native_ag_vote_remove");
	register_native("ag_vote_exists", "native_ag_vote_exists");
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// Cache models from teamlist
	GetTeamListModels(gTeamListModels, HL_MAX_TEAMS); // This will fix VGUI Viewport
	CacheTeamListModels(gTeamListModels, HL_MAX_TEAMS);

	// Get locations from locs/<mapname>.loc file
	GetLocations(gLocationName, 32, gLocationOrigin, gNumLocations);

	// Multilingual
	register_dictionary("agmodx.txt");
	register_dictionary("agmodxhelp.txt");

	// show current AG mode on game description when you find servers
	register_forward(FM_GetGameDescription, "FwGameDescription");

	// player's hooks
	RegisterHam(Ham_TraceAttack, "player", "PlayerTraceAttack");
	RegisterHam(Ham_Killed, "player", "PlayerPreKilled");
	RegisterHam(Ham_Spawn, "player", "PlayerPostSpawn", true);
	RegisterHam(Ham_Spawn, "player", "PlayerPreSpawn");

	register_concmd("agabort", "CmdAgAbort", ADMIN_BAN, "HELP_AGABORT", _, true);
	register_concmd("agallow", "CmdAgAllow", ADMIN_BAN, "HELP_AGALLOW", _, true);
	register_concmd("agpause", "CmdAgPause", ADMIN_BAN, "HELP_AGPAUSE", _, true);
	register_concmd("agstart", "CmdAgStart", ADMIN_BAN, "HELP_AGSTART", _, true);
	register_concmd("agnextmode", "CmdAgNextMode", ADMIN_BAN, "HELP_AGNEXTMODE", _, true);
	register_concmd("agnextmap", "CmdAgNextMap", ADMIN_BAN, "HELP_AGNEXTMAP", _, true);
	register_concmd("agmap", "CmdAgMap", ADMIN_BAN, "HELP_AGMAP", _, true);
	
	register_concmd("help", "CmdHelp", ADMIN_ALL, "HELP_HELP", _, true);
	register_concmd("timeleft", "CmdTimeLeft", ADMIN_ALL, "HELP_TIMELEFT", _, true);
	register_clcmd("vote", "CmdVote", ADMIN_ALL, "HELP_VOTE", _, true);
	register_clcmd("yes", "CmdVoteYes", ADMIN_ALL, "HELP_YES", _, true);
	register_clcmd("no", "CmdVoteNo", ADMIN_ALL, "HELP_NO", _, true);
	register_clcmd("settings", "ShowSettings", ADMIN_ALL, "HELP_SETTINGS", _, true);
	register_clcmd("say settings", "ShowSettings", ADMIN_ALL, "HELP_SETTINGS", _, true);
	register_clcmd("play_team", "PlayTeam", ADMIN_ALL, "HELP_PLAYTEAM", _, true);

	register_clcmd("spectate", "CmdSpectate"); // block spectate
	register_clcmd("drop", "CmdDrop"); // block drop
	register_clcmd("jointeam", "CmdJoinTeam"); // this will make work the vgui
	register_clcmd("changeteam", "CmdChangeTeam");

	// i create this cmds to set pausable to 0
	register_clcmd("pauseAg", "CmdPauseAg");
	
	// debug for arena, lts and lms
	register_clcmd("userinfo", "CmdUserInfo");

	register_event_ex("30", "EventIntermissionMode", RegisterEvent_Global);

	// Chat and voice 
	register_message(get_user_msgid("SayText"), "MsgSayText");
	register_forward(FM_Voice_SetClientListening, "FwVoiceSetClientListening");

	gHudShowVote = CreateHudSyncObj();
	gHudShowMatch = CreateHudSyncObj();
	gHudShowTimeLeft = CreateHudSyncObj();

	// this saves score of players that're playing a match
	// so if someone get disconnect by any reason, the score will be restored when he returns
	gTrieScoreAuthId = TrieCreate();
	gArenaQueue = ArrayCreate();

	// this is used for change hud colors of ag mod x
	hook_cvar_change(gCvarHudColor, "CvarHudColorHook");

	CreateVoteSystem();
	StartTimeLeft();
	LoadGameMode();
	StartMode();
}

public plugin_cfg() {
	// pause it because "say timeleft" shows wrong timeleft, unless we modify the amx plugin, or put the plugin first and create our own timeleft cmd...
	pause("cd", "timeleft.amxx");

	// this should fix bad cvar pointer
	gCvarAmxNextMap = get_cvar_pointer("amx_nextmap");
}

public plugin_end() {
	disable_cvar_hook(gHookCvarTimeLimit);
	set_pcvar_num(gCvarTimeLimit, gTimeLimit);

	ArrayDestroy(gArenaQueue);

	new TrieIter:handle = TrieIterCreate(gTrieVoteList);
	new value;
	while (!TrieIterEnded(handle)) {
		TrieIterGetCell(handle, value);
		DestroyForward(value);
		TrieIterNext(handle);
	}
	TrieIterDestroy(handle);
	TrieDestroy(gTrieVoteList);
	TrieDestroy(gTrieScoreAuthId);
}

// Gamemode name that should be displayed in server browser and in splash with server settings data
public FwGameDescription() {
	forward_return(FMV_STRING, gGameModeName);
	return FMRES_SUPERCEDE;
}

public client_putinserver(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	// restore score by authid
	if (ScoreExists(authid))
		set_task(1.0, "RestoreScore", id, authid, sizeof authid); // delay to avoid some scoreboard glitchs
	else if (gSendConnectingToSpec)
		set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC); // delay to avoid some scoreboard glitchs

	if (gIsArenaMode) {
		CountArenaQueue();
	}

	set_task(3.0, "ShowSettings", id);
	set_task(25.0, "DisplayInfo", id);
}

public client_disconnected(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);

	// save score by authid
	if (gVersusStarted && ScoreExists(authid)) {
		new frags = get_user_frags(id);
		new deaths = hl_get_user_deaths(id);
		SaveScore(id, frags, deaths);
		client_print(0, print_console, "%l", "MATCH_LEAVE", id, frags, deaths);
		log_amx("%L", LANG_SERVER, "MATCH_LEAVE", id, frags, deaths);
	}

	return PLUGIN_HANDLED;
}

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	// reset player's vote and updated hud
	if (gVoteStarted) {
		gVotePlayers[id] = 0;
		ShowVote();
	}

	if (gIsArenaMode) {
		if (GetNumAlives() < 2) {
			if (id == gMatchWinner)
				gMatchWinner = gMatchLooser;
			EndArena();
		}
	} else if (gIsLtsMode) {
		EndMatchLts();
	} else if (gIsLmsMode) {
		EndMatchLms();	
	}

	return PLUGIN_HANDLED;
}

public PlayerTraceAttack(victim, attacker, Float:damage, Float:dir[3], ptr, bits) {
	if (get_tr2(ptr, TR_iHitgroup) == HIT_HEAD)
		SetHamParamFloat(3, damage * get_pcvar_float(gCvarHeadShot));
	return HAM_IGNORED;
} 

public PlayerPreSpawn(id) {
	// if player has to spec, don't let him spawn...
	if (task_exists(TASK_SENDVICTIMTOSPEC + id) || gBlockPlayerSpawn)
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public PlayerPostSpawn(id) {
	// when he spawn, the hud gets reset so allow him to show settings again
	remove_task(id + TASK_SHOWSETTINGS);

	if (is_user_alive(id) && !gGamePlayerEquipExists) // what happens if users spawn dead? it's just a prevention.
		SetPlayerEquipment(id); // note: this doesn't have effect on pre spawn
}

public client_kill() {
	if (gBlockCmdKill)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public PlayerPreKilled(victim, attacker) {
	if (gSendVictimToSpec)
		set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	// Arena
	if (gIsArenaMode) {
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

	// Arcade
	if (is_user_alive(attacker) && gRestorePlayerEquipOnKill) {
		set_user_health(attacker, get_pcvar_num(gCvarStartHealth));
		set_user_armor(attacker, get_pcvar_num(gCvarStartArmor));
		ResetBpAmmo(attacker);
		ResetWeaponClip(attacker);
	}

	// Last Team Standing and Last Man Standing
	if (gIsLtsMode) {
		if (!PlayerKilledHimself(victim, attacker))
		player_teleport_splash(victim);
		EndMatchLts();
	} else if (gIsLmsMode) {
		if (!PlayerKilledHimself(victim, attacker))
			player_teleport_splash(victim);
		EndMatchLms();
	}
}

stock bool:PlayerKilledHimself(victim, attacker) {
	return (!IsPlayer(attacker) || victim == attacker); // attacker can be worldspawn if player dies by fall
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

SetPlayerEquipment(id) {
	set_user_health(id, get_pcvar_num(gCvarStartHealth));
	set_user_armor(id, get_pcvar_num(gCvarStartArmor));

	if (get_pcvar_bool(gCvarStartLongJump))
		hl_set_user_longjump(id, true);

	ResetBpAmmo(id);
}

public ResetBpAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // some maps like bootbox dont like this if i dont put this condition
			set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_pcvar_num(gCvarStartAmmo[i]), i + 1);
	}
}

public ResetWeaponClip(id) {
	new weapon;
	if (get_pcvar_num(gCvarStartWeapons[START_RPG])) {
		weapon = GetUserWeaponEntId(id, HLW_RPG);
		hl_set_weapon_ammo(weapon, 1);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_CROSSBOW])) {
		weapon = GetUserWeaponEntId(id, HLW_CROSSBOW);
		hl_set_weapon_ammo(weapon, 5);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_9MMAR])) {
		weapon = GetUserWeaponEntId(id, HLW_MP5);
		if (hl_get_weapon_ammo(weapon) < 25)
			hl_set_weapon_ammo(weapon, 25);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_9MMHANDGUN])) {
		weapon = GetUserWeaponEntId(id, HLW_GLOCK);
		hl_set_weapon_ammo(weapon, 17);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_357])) {
		weapon = GetUserWeaponEntId(id, HLW_PYTHON);
		hl_set_weapon_ammo(weapon, 6);
	}
	if (get_pcvar_num(gCvarStartWeapons[START_SHOTGUN])) {
		weapon = GetUserWeaponEntId(id, HLW_SHOTGUN);
		hl_set_weapon_ammo(weapon, 8);
	}
}

// If user has the weapon (HLW enum from hlsdk_const.inc), return the weapon entity index.
public GetUserWeaponEntId(id, weapon) {
	new classname[32];
	get_weaponname(weapon, classname, charsmax(classname));
	return find_ent_by_owner(0, classname, id);
}

/*
* Arcade
*/
public StartArcade() {
	gRestorePlayerEquipOnKill = true;
	gBlockCmdDrop = true;
}

/* 
* Last Man Standing Mode
*/
public StartMatchLms() {
	gIsLmsMode = true;

	// gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gSendVictimToSpec = true;
	gSendConnectingToSpec = true;

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

/* 
* Last Team Standing Mode
*/
public StartMatchLts() {
	gIsLtsMode = true;

	// don't send to spec victims when a match is going to start
	for (new id = 1; id <= MaxClients; id++)
		remove_task(id + TASK_SENDVICTIMTOSPEC);

	// gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gSendVictimToSpec = true;
	gSendConnectingToSpec = true;

	new numBlue = ag_get_team_numplayers(1);
	new numRed = ag_get_team_numplayers(2);

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

stock GetNumAlives() {
	new alives[32], numAlives;
	get_players(alives, numAlives, "a");
	return numAlives;
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

/* 
* Arena Mode
*/
public StartArena() {
	gIsArenaMode = true;

	// game rules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gSendVictimToSpec = true;
	gSendConnectingToSpec = true;

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

public CmdTimeLeft(id) {
	client_print(id, print_console, "timeleft: %i:%02i", 
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft / 60, // minutes
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft % 60); // seconds
	return PLUGIN_HANDLED;
}

/*
* Timeleft/Timelimit System
*/
public StartTimeLeft() {
	// from now, i'm going to use my own timeleft and timelimit
	gTimeLimit = get_pcvar_num(gCvarTimeLimit);

	gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;

	// set mp_timelimit always to empty (this way i can always track changes) and don't let anyone modify it.
	set_pcvar_string(gCvarTimeLimit, "");
	gHookCvarTimeLimit = hook_cvar_change(gCvarTimeLimit, "CvarTimeLimitHook");

	// Start my own timeleft
	set_task(1.0, "TimeLeftCountdown", TASK_TIMELEFT, _, _, "b");
}

public TimeLeftCountdown() {
	if (task_exists(TASK_STARTVERSUS)) // when player send agstart, freeze timer
		return;

	if (gTimeLeft > 0)
		gTimeLeft--;
	else if (gTimeLeft == 0)
		StartIntermissionMode();

	ShowTimeLeft();
}

public ShowTimeLeft() {
	new r = gHudRed;
	new g = gHudGreen;
	new b = gHudBlue;

	if (gTimeLeft >= 0) {

		if (gTimeLeft < 60) { // set red color
			r = 255; 
			g = 50;
			b = 50; 
		}

		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01);

		if (gTimeLeft > 3600)
			ShowSyncHudMsg(0, gHudShowTimeLeft, "%i:%02i:%02i", gTimeLeft / 3600, (gTimeLeft / 60) % 60, gTimeLeft % 60);
		else
			ShowSyncHudMsg(0, gHudShowTimeLeft, "%i:%02i", gTimeLeft / 60, gTimeLeft % 60);
	} else {
		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01); // flicks the hud with out this, maybe is a bug
		ShowSyncHudMsg(0, gHudShowTimeLeft, "%l", "TIMER_UNLIMITED");
	}

	return PLUGIN_CONTINUE;
}

// Ex: If you set mp_timelimit to the same value, this will not get executed
public CvarTimeLimitHook(pcvar, const old_value[], const new_value[]) {
	// i disable the hook to avoid recursion (check cvars.inc)
	disable_cvar_hook(gHookCvarTimeLimit);
	
	new timeLimit = str_to_num(new_value);

	if (timeLimit == 0) {
		if (gVersusStarted && !get_pcvar_num(gCvarAgStartAllowUnlimited)) { // block start versus with unlimited time
			client_print(0, print_center, "%l", "MATCH_DENY_CHANGEUNLIMITED");
		} else {
			gTimeLeft = TIMELEFT_SETUNLIMITED;
			gTimeLimit = timeLimit;
		}
	} else {
		gTimeLeft =  timeLimit * 60;
		gTimeLimit = timeLimit;
	}

	// always leave it empty, so players can't change the cvar value and finish the map (go to intermission mode) by accident...	
	set_pcvar_string(pcvar, ""); 

	enable_cvar_hook(gHookCvarTimeLimit);
}

/* 
* AgStart
*/
public StartVersus() {
	if (get_playersnum() < get_pcvar_num(gCvarAgStartMinPlayers)) {
		client_print(0, print_center, "%l", "MATCH_MINPLAYERS_CENTER", get_pcvar_num(gCvarAgStartMinPlayers));
		return;
	} else if (gTimeLimit <= 0 && !get_pcvar_num(gCvarAgStartAllowUnlimited)) { // block start versus with mp_timelimit 0
		client_print(0, print_center, "%l", "MATCH_DENY_STARTUNLIMITED");
		return;
	}

	// remove previous start match even if doesn't exist
	remove_task(TASK_STARTVERSUS);

	// clean list of authids to begin a new match
	TrieClear(gTrieScoreAuthId);

	// gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gBlockCmdKill = true;
	gSendConnectingToSpec = true;
	gBlockPlayerSpawn = true; // if player is dead on agstart countdown, he will be able to spawn...

	// reset score and freeze players who are going to play versus
	new players[MAX_PLAYERS], numPlayers, player;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (IsInWelcomeCam(player)) { // send to spec players in welcome cam 
			hl_set_user_spectator(player);
		} else if (!hl_get_user_spectator(player)) {
			SaveScore(player);
		}
		FreezePlayer(player);
	}

	// Reset map
	ResetMap();

	gStartVersusTime = 10;
	StartVersusCountdown();
}

stock ResetMap() {
	ClearField();
	ClearCorpses();
	RespawnItems();
	ResetChargers();	
}

public StartVersusCountdown() {
	gStartVersusTime--;

	PlaySound(0, gCountSnd[gStartVersusTime]);
		
	if (gStartVersusTime == 0) {
		remove_task(TASK_STARTVERSUS); // stop countdown

		gVersusStarted = true;

		gBlockCmdDrop = false;
		gBlockCmdKill = false;
		gBlockPlayerSpawn = false;

		TrieClear(gTrieScoreAuthId);

		// message holds a lot of time to avoid flickering, so I remove it manually
		ClearSyncHud(0, gHudShowMatch);

		new players[MAX_PLAYERS], numPlayers, player;
		get_players(players, numPlayers);

		for (new i; i < numPlayers; i++) {
			player = players[i];
			server_print("id %d IsInWelcomeCam %d", player, IsInWelcomeCam(player));
			if (!hl_get_user_spectator(player)) {
				if (!IsInWelcomeCam(player)) {				
					ResetScore(player);
					SaveScore(player);
					hl_user_spawn(player);
					set_task(0.5, "ShowSettings", player);
				}
			} else {
				FreezePlayer(player, false);
			}
		}

		// set new timeleft according to timelimit
		gTimeLeft = gTimeLimit == 0 ? TIMELEFT_SETUNLIMITED : gTimeLimit * 60;

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 15.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_START", gStartVersusTime);

	set_task(1.0, "StartVersusCountdown", TASK_STARTVERSUS);
}

/* 
* AgAbort
*/
public AbortVersus() {
	gVersusStarted = false;

	// clear authids to prepare for the next match
	TrieClear(gTrieScoreAuthId);

	// remove start match hud
	remove_task(TASK_STARTVERSUS);

	// restore gamerules
	gBlockCmdSpec = false;
	gBlockCmdDrop = false;
	gBlockCmdKill = false;
	gSendConnectingToSpec = false;
	gBlockPlayerSpawn = false;

	new players[32], numPlayers, player;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (is_user_alive(player))
			FreezePlayer(player, false);
		else if (hl_get_user_spectator(player))
			hl_set_user_spectator(player, false);
	}
}

FreezePlayer(id, bool:freeze=true) {
	new flags = pev(id, pev_flags);
	if (freeze) {
		set_pev(id, pev_flags, flags | FL_FROZEN);
		set_pev(id, pev_solid, SOLID_NOT); // this will block weapon pick up
	} else {
		set_pev(id, pev_flags, flags & ~FL_FROZEN);
		set_pev(id, pev_solid, SOLID_BBOX);
	}
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

/*
* AG Say
*/
public MsgSayText(msg_id, msg_dest, receiver) {
	new text[191]; // 192 will crash the sv by overflow if someone send a large message with a lot of %l, %w, etc...
	
	get_msg_arg_string(2, text, charsmax(text)); // get user message
	
	if (text[0] == '*') // ignore server messages
		return PLUGIN_CONTINUE;

	new sender = get_msg_arg_int(1);
	new isReceiverSpec = hl_get_user_spectator(receiver);

	// Add or change channel tags	
	if (hl_get_user_spectator(sender)) {
		if (contain(text, "^x02(TEAM)") != -1) {
			if (!isReceiverSpec) // only show messages to spectator
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(ST)"); // Spectator Team
		} else {
			if (gVersusStarted && !get_pcvar_num(gCvarSpecTalk)) {
				if (sender == receiver)
					client_print(sender, print_chat, "%l", "SPEC_CANTTALK");
				return PLUGIN_HANDLED;
			} else
				format(text, charsmax(text), "^x02(S)%s", text); // Spectator
		}
	} else {
		if (contain(text, "^x02(TEAM)") != -1) { // Team
			if (isReceiverSpec)
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(T)"); 
		} else
			format(text, charsmax(text), "^x02(A)%s", text); // All
	}

	// replace all %h with health
	replace_string(text, charsmax(text), "%h", fmt("%i", get_user_health(sender)), false);

	// replace all %a with armor
	replace_string(text, charsmax(text), "%a", fmt("%i", get_user_armor(sender)), false);

	// replace all %p with longjump
	replace_string(text, charsmax(text), "%p", hl_get_user_longjump(sender) ? "Yes" : "No", false);

	// replace all %l with location
	replace_string(text, charsmax(text), "%l", gLocationName[FindNearestLocation(sender, gLocationOrigin, gNumLocations)], false);

	// replace all %w with name of current weapon
	new ammo, bpammo, weaponid = get_user_weapon(sender, ammo, bpammo);

	if (weaponid) {
		new weaponName[32];
		get_weaponname(weaponid, weaponName, charsmax(weaponName));
		replace_string(weaponName, charsmax(weaponName), "weapon_", "");
		replace_string(text, charsmax(text), "%w", weaponName, false);
	}

	// replace all %q with ammo of current weapon
	new ammoMsg[16], arGrenades;

	if (weaponid == HLW_MP5)
		arGrenades = hl_get_user_bpammo(sender, HLW_CHAINGUN);

	FormatAmmo(weaponid, ammo, bpammo, arGrenades, ammoMsg, charsmax(ammoMsg));
	replace_string(text, charsmax(text), "%q", ammoMsg, false); 

	// send final message
	set_msg_arg_string(2, text);

	return PLUGIN_CONTINUE;
}

stock FormatAmmo(weaponid, ammo, bpammo, arGrenades, output[], len) {
	new formatOption;
	switch (weaponid) {
		case HLW_NONE: 		formatOption = 0;
		case HLW_CROWBAR:	formatOption = 0;
		case HLW_CROSSBOW: 	formatOption = 2;
		case HLW_GLOCK: 	formatOption = 2;
		case HLW_MP5: 		formatOption = 3;
		case HLW_PYTHON: 	formatOption = 2;
		case HLW_RPG: 		formatOption = 2;
		case HLW_SHOTGUN: 	formatOption = 2;
		default: 			formatOption = 1;
	}

	switch (formatOption) {
		case 0: copy(output, len, ""); 
		case 1: copy(output, len, fmt("%i", ammo < 0 ? bpammo : ammo + bpammo));
		case 2: copy(output, len, fmt("%i/%i", ammo, bpammo));
		case 3: copy(output, len, fmt("%i/%i/%i", ammo, bpammo, arGrenades));
	}
}

/*
* Block Voice of Spectators
*/
public FwVoiceSetClientListening(receiver, sender, bool:listen) {
	if (receiver == sender)
		return FMRES_IGNORED;

	if (gVersusStarted && !get_pcvar_num(gCvarSpecTalk) && hl_get_user_spectator(sender) && !hl_get_user_spectator(receiver)) {
		engfunc(EngFunc_SetClientListening, receiver, sender, false);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

/*
* Location System
*/
public GetLocations(name[][], size, Float:origin[][], &numLocs) {
	new file[128], map[32], text[2048];

	get_mapname(map, charsmax(map));
	formatex(file, charsmax(file), "locs/%s.loc", map);
	
	if (file_exists(file))
		read_file(file, 0, text, charsmax(text));

	new i, j, nLen;
	j = -1;

	while (nLen < strlen(text)) {
		if (j == -1) {
			nLen += 1 + copyc(name[i], size, text[nLen], '#'); // you must plus one to skip #
			j++;
			numLocs++;
		} else {
			new number[16];
			
			nLen += 1 + copyc(number, sizeof number, text[nLen], '#'); // you must plus one to skip #
			origin[i][j] = str_to_float(number);
			
			j++;

			// if we finish to copy origin, then let's start with next location
			if (j > 2) {
				i++;
				j = -1;
			}
		}
	}
}

// return the index of the nearest location for the player from an array
public FindNearestLocation(id, Float:locOrigin[][3], numLocs) {
	new Float:userOrigin[3], Float:nearestOrigin[3], idxNearestLoc;
	
	pev(id, pev_origin, userOrigin);

	// initialize nearest origin with the first location
	nearestOrigin = locOrigin[0];
	
	for (new i; i < numLocs; i++) {
		if (vector_distance(userOrigin, locOrigin[i]) <= vector_distance(userOrigin, nearestOrigin)) {
			nearestOrigin = locOrigin[i];
			idxNearestLoc = i;
		}
	}

	return idxNearestLoc;
}

public CmdHelp(id, level, cid) {
	new cmd[32], info[128], flags, bool:isInfoMl;
	new j;

	client_print(id, print_console, "----- Ag Mod X -----");
	for (new i; i < get_clcmdsnum(-1); i++) {
		isInfoMl = false;
		if (!get_clcmd(i, cmd, charsmax(cmd), flags, info, charsmax(info), ADMIN_BAN, isInfoMl)) 
			continue;
		for (new i; i < sizeof gHelpList; i++) {
			if (isInfoMl)
				LookupLangKey(info, charsmax(info), info, id);

			if (equal(cmd, gHelpList[i]))
				client_print(id, print_console, "%i. %s %s", ++j, cmd, info);
		}
	}

	for (new i; i < get_clcmdsnum(-1); i++) {
		isInfoMl = false;
		if (!get_clcmd(i, cmd, charsmax(cmd), flags, info, charsmax(info), ADMIN_BAN, isInfoMl)) 
			continue;
		for (new i; i < sizeof gHelpList; i++) {
			if (isInfoMl)
				LookupLangKey(info, charsmax(info), info, id);

			if (equal(cmd, gGameModeList[i]))
				client_print(id, print_console, "%i. %s %s", ++j, cmd, info);
		}
	}
	client_print(id, print_console, "--------------------");
	return PLUGIN_HANDLED;
}

public CmdSpectate(id) {
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	if (!hl_get_user_spectator(id)) // note: setting score while player is in spec will mess up scoreboard (bugfixed hl bug?)
		ResetScore(id);

	if (gBlockCmdSpec) {
		if (!ScoreExists(authid)) // only players playing a match can spectate
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// maybe we need to show old style menu because VGUI Viewport just let you select the first four teams.
public CmdChangeTeam(id) {
	ShowVGUITeamMenu(id);
	return PLUGIN_HANDLED;
}

public ShowVGUITeamMenu(id) {
	static msgVGUIMenu;

	if (!msgVGUIMenu)
		msgVGUIMenu = get_user_msgid("VGUIMenu");

	message_begin(MSG_ONE, get_user_msgid("VGUIMenu"), _, id);
	write_byte(2);
	message_end();
}

public CmdJoinTeam(id) {
	new option = read_argv_int(1); 
	switch (option) {
		case 1, 2, 3, 4: { // in vgui viewport there are only four buttons where you choose the first 4 teams, maybe is better to show a menu to show all team (max 10 teams)
			if (!equal(gTeamListModels[option - 1], "")) {
				hl_set_user_model(id, gTeamListModels[option - 1]);
				if (hl_get_user_spectator(id))
					client_cmd(id, "spectate");
			}
		}
	}
	return PLUGIN_HANDLED;
}

public CmdDrop() {
	if (gBlockCmdDrop)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

// I made this function for foreigners so they can differentiate the order of the month and the day...
GetPluginBuildDate(output[], len) {
	format_time(output, len, "%d %b %Y", parse_time(__DATE__, "%m:%d:%Y")); // 15 Nov 2018
}

// We need to use director hud msg because there aren't enough hud channels, unless we make a better gui that use less channels
// We are limited to 128 characters, so that is bad for multilingual or to show more settings ...
public ShowSettings(id) {
	// avoid hud overlap
	if (task_exists(id + TASK_SHOWSETTINGS) || !is_user_connected(id))
		return;
		
	new arg[32], buildDate[32];

	// left - top
	GetPluginBuildDate(buildDate, charsmax(buildDate));
	get_pcvar_string(gCvarContact, arg, charsmax(arg));
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "AG Mod X %s Build %s^n%s", VERSION, buildDate, arg);

	// center - top
	if (gVersusStarted) {
		set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.02, 0, 0.0, 10.0, 0.2);
		show_dhudmessage(id, "^n%l", "MATCH_STARTED");
	}

	// right - top
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "%l", "SETTINGS_VARS", gGameModeName, gTimeLimit, 
		get_pcvar_num(gCvarFragLimit), 
		get_pcvar_num(gCvarFriendlyFire) ? "On" : "Off", 
		get_pcvar_num(gCvarForceRespawn) ? "On" : "Off",
		get_pcvar_num(gCvarSelfGauss) ? "On" : "Off");

	set_task(10.0, "ShowSettings", id + TASK_SHOWSETTINGS); // this will stop hud overlap
}

public CmdAgPause(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	log_amx("AgPause: %N", id);

	PauseGame(id);

	return PLUGIN_HANDLED;	
}

public CmdAgStart(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (equal(arg, "")) { 
		StartVersus();
		return PLUGIN_HANDLED;
	}

	// from here, where're going to get which players are going to play versus...
	new target[33], player;

	for (new i = 1; i < read_argc(); i++) {
		read_argv(i, arg, charsmax(arg));
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
		if (player)
			target[player] = player;
		else
			return PLUGIN_HANDLED;
	}

	
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			if (i == target[i])
				hl_set_user_spectator(i, false);
			else {
				hl_set_user_spectator(i, true);
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
			}
		}		
	}

	log_amx("AgStart: %N", id);

	StartVersus();

	return PLUGIN_HANDLED;
}

public CmdAgAbort(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}

	log_amx("AgAbort: %N", id);

	AbortVersus();

	return PLUGIN_HANDLED;
}

public CmdAgAllow(id, level, cid) {
	if (!IsUserServer(id)) {
		new cmd[16], args[32];
		read_argv(0, cmd, charsmax(cmd));
		read_args(args, charsmax(args));
		client_cmd(id, "vote %s %s", cmd, args);
		return PLUGIN_HANDLED;
	}

	if (!gVersusStarted)
		return PLUGIN_HANDLED;

	new arg[32], player;
	read_argv(1, arg, charsmax(arg));

	if (equal(arg, ""))
		player = id;
	else 
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);

	if (!player)
		return PLUGIN_HANDLED;

	log_amx("AgAllow: %N to %N", id, player);

	AllowPlayer(player);

	return PLUGIN_HANDLED;
}

public AllowPlayer(id) {
	if (!is_user_connected(id) || !gVersusStarted)
		return PLUGIN_HANDLED;

	if (hl_get_user_spectator(id)) {
		// create a key for this new guy so i can save his score when he gets disconnect...
		SaveScore(id);

		hl_set_user_spectator(id, false);

		ResetScore(id);

		client_print(0, print_console, "%l", "MATCH_ALLOW", id);
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, -1.0, 0, 0.0, 5.0); 
		ShowSyncHudMsg(0, gHudShowMatch, "%l", "MATCH_ALLOW", id);	
	}

	return PLUGIN_HANDLED;
}

public CmdAgNextMode(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	strtolower(arg);

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	}

	if (TrieKeyExists(gTrieVoteList, arg)) {
		log_amx("AgNextMode: ^"%s^" ^"%N^"", arg, id);
		set_pcvar_string(gCvarGameMode, arg); // set next mode
	} else {
		client_print(id, print_console, "%l", "INVALID_MODE");
	}

	return PLUGIN_HANDLED;
}

public CmdAgNextMap(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	}    

	if (is_map_valid(arg)) {
		log_amx("AgNextMap: ^"%s^" ^"%N^"", arg, id);
		set_pcvar_string(gCvarAmxNextMap, arg); // set new mode
	} else {
		client_print(id, print_console, "%l", "INVALID_MAP");
	}

	return PLUGIN_HANDLED;
}

public CmdChangeMode(id, level, cid) {
	new arg[32];
	read_argv(0, arg, charsmax(arg));
	strtolower(arg);

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s", cmd);
		return PLUGIN_HANDLED;
	}   

	if (TrieKeyExists(gTrieVoteList, arg)) {
		log_amx("Change gamemode: ^"%s^" ^"%N^"", arg, id);
		ChangeMode(arg);
	}

	return PLUGIN_HANDLED;
}

public CmdAgMap(id, level, cid) {
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (!IsUserServer(id)) {
		new cmd[16];
		read_argv(0, cmd, charsmax(cmd));
		client_cmd(id, "vote %s %s", cmd, arg);
		return PLUGIN_HANDLED;
	} 

	if (is_map_valid(arg)) {
		log_amx("AgMap: ^"%s^" ^"%N^"", id, arg);
		ChangeMap(arg);
	} else {
		console_print(id, "%l", "INVALID_MAP");
	}


	return PLUGIN_HANDLED;
}

public CmdUserInfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
	    return PLUGIN_HANDLED;

	new target[32];
	read_argv(1, target, charsmax(target));

	if (equal(target, "")) {
	    PrintUserInfo(id, id);
	    return PLUGIN_HANDLED;
	}

	new player = cmd_target(id, target);

	if (!player)
		return PLUGIN_HANDLED;

	PrintUserInfo(id, player);

	return PLUGIN_HANDLED;
}

stock PrintUserInfo(caller, target) {
	new model[16];
	new team = hl_get_user_team(target);

	new iuser1 = pev(target, pev_iuser1);
	new iuser2 = pev(target, pev_iuser2);

	new alive = is_user_alive(target);
	new dead = pev(target, pev_deadflag);

	hl_get_user_model(target, model, charsmax(model));

	client_print(caller, print_chat, "Team: %i; Model: %s; iuser1: %i; iuser2: %i Alive: %i; Deadflag: %i IsInWelcomeCam: %i", team, model, iuser1, iuser2, alive, dead, IsInWelcomeCam(caller));
}

/* 
* Vote system
*/
CreateVoteSystem() {
	gTrieVoteList = TrieCreate();
	ag_vote_add("agabort", "OnVoteAgAbort");
	ag_vote_add("agallow", "OnVoteAgAllow");
	ag_vote_add("agnextmap", "OnVoteAgNextMap");
	ag_vote_add("agnextmode", "OnVoteAgNextMode");
	ag_vote_add("agpause", "OnVoteAgPause");
	ag_vote_add("agstart", "OnVoteAgStart");
	ag_vote_add("agmap", "OnVoteAgMap");
	ag_vote_add("map", "OnVoteAgMap");
	ag_vote_add("mp_bunnyhop", "OnVoteBunnyHop");
	ag_vote_add("mp_falldamage", "OnVoteFallDamage");
	ag_vote_add("mp_flashlight", "OnVoteFlashLight");
	ag_vote_add("mp_footsteps", "OnVoteFootSteps");
	ag_vote_add("mp_forcerespawn", "OnVoteForceRespawn");
	ag_vote_add("mp_fraglimit", "OnVoteFragLimit");
	ag_vote_add("mp_friendlyfire", "OnVoteFriendlyFire");
	ag_vote_add("mp_selfgauss", "OnVoteSelfGauss");
	ag_vote_add("mp_timelimit", "OnVoteTimeLimit");
	ag_vote_add("mp_weaponstay", "OnVoteWeaponStay");
}

public OnVoteTimeLimit(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarTimeLimit, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
		new num = str_to_num(arg2);
		if (num < 0) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFriendlyFire(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarFriendlyFire, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteBunnyHop(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}
	
	if (!check) {
		set_pcvar_string(gCvarBunnyHop, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFallDamage(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFallDamage, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFlashLight(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFlashLight, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFootSteps(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFootSteps, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteFragLimit(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarFragLimit, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteSelfGauss(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarSelfGauss, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteForceRespawn(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarForceRespawn, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteWeaponStay(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarWeaponStay, arg2);
	} else {
		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public OnVoteAgAbort(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check)
		AbortVersus();
	
	return true;
}

public OnVoteAgStart(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		StartVersus();
	} else {
		if (get_playersnum() < get_pcvar_num(gCvarAgStartMinPlayers)) {
			console_print(id, "%l", "MATCH_MINPLAYERS", get_pcvar_num(gCvarAgStartMinPlayers));
			return false;
		}
	}
	
	return true;
}

public OnVoteAgPause(id, check, argc) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		PauseGame(id);
	}
	
	return true;
}

public OnVoteAgMap(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	// Rename vote always to agmap to be consistent
	formatex(arg1, 31, "%s", "agmap");

	if (!check) {
		ChangeMap(arg2);
	} else {
		if (!is_map_valid(arg2)) {
			client_print(id, print_console, "%l", "INVALID_MAP");
			return false;
		}
	}

	return true;
}

public OnVoteAgNextMap(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		set_pcvar_string(gCvarAmxNextMap, arg2);
	} else {
		if (!is_map_valid(arg2)) {
			client_print(id, print_console, "%l", "INVALID_MAP");
			return false;
		}
	}

	return true;
}

public OnVoteAgNextMode(id, check, argc, arg1[], arg2[]) {
	if (argc != 1) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		ChangeMode(arg2);
	}

	return true;
}

public OnVoteAgAllow(id, check, argc, arg1[], arg2[]) {
	if (argc > 2) {
		client_print(id, print_console, "%l", "VOTE_INVALID");
		return false;
	}

	static userid;
	if (!check) {
		AllowPlayer(find_player_ex(FindPlayer_MatchUserId, userid));
	} else {
		new player;
		if (equal(arg2, "")) { // allow yourself
			userid = get_user_userid(id);
		} else if ((player = cmd_target(id, arg2, CMDTARGET_ALLOW_SELF))) {
			get_user_name(player, arg2, 31);
			userid = get_user_userid(player);
		} else {
			return false;
		}
	}

	return true;
}

public OnVoteChangeMode(id, check, argc, arg1[]) {
	if (!check)
		ChangeMode(arg1);
	return true;
}

LoadGameMode() {
	new fileName[32];
	new handleDir = open_dir("gamemodes", fileName, charsmax(fileName));

	if (!handleDir)
		return;

	new mode[32];
	get_pcvar_string(gCvarGameMode, mode, charsmax(mode));

	do {
		// get index for file type
		new len = strlen(fileName) - 4;
		if (len < 0) len = 0;

		if (equali(fileName[len], ".cfg")) {
			new name[32], info[64];
			
			read_file(fmt("gamemodes/%s", fileName), 0, name, charsmax(name)); // first line specifies what game name that should be displayed in server browser and in splash with server settings data
			read_file(fmt("gamemodes/%s", fileName), 1, info, charsmax(info)); // second line is help text displayed when someone types help in console
			
			replace_string(info, charsmax(info), "/", ""); // remove comments
			replace_string(name, charsmax(name), "/", ""); // remove comments

			trim(fileName);
			replace(fileName[len], charsmax(fileName), ".cfg", "");
			strtolower(fileName);

			if (equal(mode, fileName))
				gGameModeName = name;

			// create cmd and vote for gamemode
			register_concmd(fileName, "CmdChangeMode", ADMIN_BAN, fmt("- %s", info));
			ag_vote_add(fileName, "OnVoteChangeMode"); 
		}
	} while (next_file(handleDir, fileName, charsmax(fileName)));

	close_dir(handleDir);
}

public CmdVoteYes(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_YES;
		if (gIsPause) // when server is in pause, tasks are not going to get executed, so players have to update vote themselves.
			ShowVote();
	}

	return PLUGIN_HANDLED;
}

public CmdVoteNo(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_NO;
		if (gIsPause) // when server is in pause, tasks are not going to get executed, so players have to update vote themselves.
			ShowVote();
	}

	return PLUGIN_HANDLED;
}

public CmdVote(id) {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("CmdVote");

	if (!get_pcvar_num(gCvarAllowVote))
		return PLUGIN_HANDLED;

	// Print help on console
	new argc = read_argc();
	if (argc == 1) {
		VoteHelp(id);
		return PLUGIN_HANDLED;
	}

	// get delay time
	new Float:timeleft = gVoteFailedTime - get_gametime();

	if (timeleft > 0.0) {	
		client_print(id, print_console, "%l", "VOTE_DELAY", floatround(timeleft, floatround_floor));
		return PLUGIN_HANDLED;
	} else if (gVoteStarted) {
		client_print(id, print_console, "%l", "VOTE_RUNNING");
		return PLUGIN_HANDLED;
	}

	gVoteArg1[0] = gVoteArg2[0] = '^0';
	read_argv(1, gVoteArg1, charsmax(gVoteArg1));
	read_argv(2, gVoteArg2, charsmax(gVoteArg2));

	gVoteCallerUserId = get_user_userid(id);
	gNumVoteArgs = argc - 1;
	
	// If vote doesn't exist
	if (!TrieGetCell(gTrieVoteList, gVoteArg1, gVoteOptionFwHandle)) {
		client_print(id, print_console, "%l", "VOTE_NOTFOUND");
		return PLUGIN_HANDLED;
	}
	
	new voteResult;
	ExecuteForward(gVoteOptionFwHandle, voteResult, id, true, gNumVoteArgs, PrepareArray(gVoteArg1, sizeof(gVoteArg1), true), PrepareArray(gVoteArg2, sizeof(gVoteArg2), true));

	if (!voteResult)
		return PLUGIN_HANDLED;

	gVoteStarted = true;

	gVotePlayers[id] = VOTE_YES;

	get_user_name(id, gVoteCallerName, charsmax(gVoteCallerName));
	
	log_amx("%L", LANG_SERVER, "LOG_VOTE_STARTED", gVoteArg1, strlen(gVoteArg2) ? fmt(" %s", gVoteArg2) : "", id);

	new time = get_pcvar_num(gCvarVoteDuration);

	ShowVote();
	
	if (gVoteStarted) {
		set_task(float(time), "DenyVote", TASK_DENYVOTE); // show vote only for 30 seconds (warning: if sv is in pause, tasks are paused too)
		set_task_ex(1.0, "ShowVote", TASK_SHOWVOTE, _, _, SetTask_Repeat, time);
	}

	return PLUGIN_HANDLED;
}

public ShowVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("ShowVote");

	new numVoteFor, numVoteAgainst, numUndecided;

	// count votes
	for (new id = 1; id <= MaxClients; id++) {
		switch (gVotePlayers[id]) {
			case VOTE_YES: numVoteFor++;
			case VOTE_NO: numVoteAgainst++;
		}
	}
	
	numUndecided = get_playersnum() - (numVoteFor + numVoteAgainst);

	// show vote hud
	if (numVoteFor > numVoteAgainst && numVoteFor > numUndecided) { // accepted
		DoVote();
	} else if (numVoteAgainst > numVoteFor && numVoteAgainst > numUndecided) { // denied
		DenyVote();
	} else { // in progress
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, get_pcvar_float(gCvarVoteDuration) * 2, 0.2);
		ShowSyncHudMsg(0, gHudShowVote, "%l", "VOTE_START", gVoteArg1, gVoteArg2, gVoteCallerName, numVoteFor, numVoteAgainst, numUndecided);
	}
}

public DoVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("DoVote");

	// show vote is accepted
	set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%l", "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);

	// sometimes  hud doesnt show, show old style vote too
	client_print(0, print_center, "%l", "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);
	
	RemoveVote();

	new caller = find_player_ex(FindPlayer_MatchUserId, gVoteCallerUserId);
	
	// if vote caller is not connected, cancel it...
	if (!caller)
		return;

	log_amx("%L", LANG_SERVER, "LOG_VOTE_ACCEPTED", gVoteArg1, strlen(gVoteArg2) ? fmt(" %s", gVoteArg2) : "", caller);

	ExecuteForward(gVoteOptionFwHandle, _, caller, false, gNumVoteArgs, PrepareArray(gVoteArg1, sizeof(gVoteArg1), true), PrepareArray(gVoteArg2, sizeof(gVoteArg2), true));
}

public DenyVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("DenyVote");

	new caller = find_player_ex(FindPlayer_MatchUserId, gVoteCallerUserId);
	log_amx("%L", LANG_SERVER, "LOG_VOTE_DENIED", gVoteArg1, strlen(gVoteArg2) ? fmt(" %s", gVoteArg2) : "", caller);
	RemoveVote();

	gVoteFailedTime = get_gametime() + get_pcvar_num(gCvarVoteFailedTime);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%l", "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);

	// sometimes  hud doesnt show, so show old style vote too
	client_print(0, print_center, "%l", "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
}

public RemoveVote() {
	if (get_pcvar_num(gCvarDebugVote))
		server_print("RemoveVote");

	gVoteStarted = false;

	remove_task(TASK_DENYVOTE);
	remove_task(TASK_SHOWVOTE);

	// reset user votes
	arrayset(gVotePlayers, 0, sizeof gVotePlayers);
}

VoteHelp(id) {
	new TrieIter:handle = TrieIterCreate(gTrieVoteList);
	
	console_print(id, "--- %l ---", "VOTE_HELP");
	new key[32], i;
	while (!TrieIterEnded(handle)) {
	    TrieIterGetKey(handle, key, charsmax(key));
	    console_print(id, "%d. %s", ++i, key);
	    TrieIterNext(handle);
	}
	console_print(id, "--- %l ---", "VOTE_HELP");
	TrieIterDestroy(handle);
}

public ChangeMode(const mode[]) {
	set_pcvar_string(gCvarGameMode, mode); // set new mode

	// we need to reload the map so cvars can take effect
	new map[32];
	get_mapname(map, charsmax(map));
	set_pcvar_string(gCvarAmxNextMap, map);

	StartIntermissionMode();
}

// i want to show score when map finishes so you can take a pic, engine_changelevel() will change it instantly
public ChangeMap(const map[]) {
	set_pcvar_string(gCvarAmxNextMap, map);
	StartIntermissionMode();
} 

PlaySound(id, const sound[]) {
	new snd[128];
	RemoveExtension(sound, snd, charsmax(snd), ".wav"); // // Remove .wav file extension (console starts to print "missing sound file _period.wav" for every sound)
	client_cmd(id, "spk %s", snd);
}

public PlayTeam(caller) {
	if (gPlayTeamDelayTime[caller] < get_gametime()) 
		gPlayTeamDelayTime[caller] = get_gametime() + 0.75;
	else 
		return PLUGIN_HANDLED;

	new sound[128];
	read_argv(1, sound, charsmax(sound));

	new team = hl_get_user_team(caller);

	new players[32], numPlayers, player;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	for (new i; i < numPlayers; i++) {
		player = players[i];
		if (team == hl_get_user_team(player))
			PlaySound(player, sound);
	}

	return PLUGIN_HANDLED;
}

StartMode() {
	new arg[32];
	get_pcvar_string(gCvarGameType, arg, charsmax(arg));
	
	if (equal(arg, "arena"))
		StartArena();
	else if (equal(arg, "arcade"))
		StartArcade();
	else if (equal(arg, "lts"))
		StartMatchLts();
	else if (equal(arg, "lms"))
		StartMatchLms();
	
	// doesn't work in plugin_precache :/
	if (get_pcvar_num(gCvarReplaceEgonWithAmmo))
		ReplaceEgonWithAmmo();

	BanGamemodeEnts();

	SetGameModePlayerEquip(); //  set an equipment when user spawns
}

BanGamemodeEnts() {
	if (get_pcvar_num(gCvarBanLongJump))
		remove_entity_name("item_longjump");

	if (get_pcvar_num(gCvarBanBattery))
		remove_entity_name("item_battery");

	if (get_pcvar_num(gCvarBanHealthKit))
		remove_entity_name("item_healthkit");

	for (new i; i < SIZE_BANWEAPONS; i++) {
		if (get_pcvar_num(gCvarBanWeapons[i]))
			remove_entity_name(gWeaponClass[i]);
	}

	for (new i; i < SIZE_AMMOENTS; i++) {
		if (get_pcvar_num(gCvarBanAmmo[i]))
			remove_entity_name(gAmmoClass[i]);
	}

	// block chargers
	if (get_pcvar_num(gCvarBanHevCharger))
		RegisterHam(Ham_Use, "func_recharge", "FwChargersUse");

	if (get_pcvar_num(gCvarBanHealthCharger))
		RegisterHam(Ham_Use, "func_healthcharger", "FwChargersUse");	
}

public FwChargersUse() {
	// block chargers
	return HAM_SUPERCEDE;
}

// Advertise about the use of some commands in AG mod x
public DisplayInfo(id) {
	client_print(id, print_chat, "%l", "DISPLAY_INFO1");
	client_print(id, print_chat, "%l", "DISPLAY_INFO2");
}

// We can't pause the game from the server because is not connected, unless you have created the sv in-game. "Can't pause, not connected."
PauseGame(id) {
	RemoveVote();

	set_cvar_num("pausable", 1);
	console_cmd(id, "pause; pauseAg");

	gIsPause = gIsPause ? false : true;
}

public CmdPauseAg(id) {
	set_cvar_num("pausable", 0);	
	return PLUGIN_HANDLED;
}

public ResetChargers() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (equal(classname, "func_recharge")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_ent_data(i, "CRecharge", "m_iJuice", 30);
			} else if (equal(classname, "func_healthcharger")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_ent_data(i, "CWallHealth", "m_iJuice", 75);
			}
		}
	}
}

// This will respawn all weapons, ammo and items of the map to prepare for a new match (agstart)
public RespawnItems() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (contain(classname, "weapon_") != -1 || contain(classname, "ammo_") != -1 || contain(classname, "item_") != -1) {
				set_pev(i, pev_nextthink, get_gametime());
			}
		}
	}
}

public ReplaceEgonWithAmmo() {
	new num, idx, ents[64], Float:origin[3];

	while (num < sizeof ents && (ents[num] = find_ent_by_class(idx, "weapon_egon"))) {
		idx = ents[num];
		num++;
	}

	for (new i; i < num; i++) {
		pev(ents[i], pev_origin, origin);
		remove_entity(ents[i]);

		ents[i] = create_entity("ammo_gaussclip");
		entity_set_origin(ents[i], origin);
		DispatchSpawn(ents[i]);
	}
}

// this will clean entities from previous matchs
public ClearField() {
	for (new i; i < sizeof gClearFieldEntsClass; i++)
		remove_entity_name(gClearFieldEntsClass[i]);

	new entid;
	while ((entid = find_ent_by_class(entid, "rpg_rocket")))
		set_pev(entid, pev_dmg, 0);

	entid = 0;
	while ((entid = find_ent_by_class(entid, "grenade")))
		set_pev(entid, pev_dmg, 0);
}

stock ClearCorpses() {
	new ent;
	while ((ent = find_ent_by_class(ent, "bodyque")))
		entity_set_origin(ent, Float:{4096.0, 4096.0, 4096.0});
}

/*
* Restore Score
*/
public bool:ScoreExists(const authid[]) {
	return TrieKeyExists(gTrieScoreAuthId, authid);
}

// save score by authid
SaveScore(id, frags = 0, deaths = 0) {
	new authid[MAX_AUTHID_LENGTH], score[2];

	get_user_authid(id, authid, charsmax(authid));

	score[SCORE_FRAGS] = frags;
	score[SCORE_DEATHS] = deaths;

	TrieSetArray(gTrieScoreAuthId, authid, score, sizeof score);
}

public GetScore(const authid[], &frags, &deaths) {
	new score[2];
	TrieGetArray(gTrieScoreAuthId, authid, score, sizeof score);

	frags = score[SCORE_FRAGS];
	deaths = score[SCORE_DEATHS];
}

public RestoreScore(authid[], id) {	
	new frags, deaths;

	if (ScoreExists(authid)) {
		GetScore(authid, frags, deaths);
		set_user_frags(id, frags);
		hl_set_user_deaths(id, deaths);
	}
}

ResetScore(id) {
	set_user_frags(id, 0);
	hl_set_user_deaths(id, 0);
}

SetHudColorCvarByString(const color[], &red, &green, &blue) {
	new r[4], g[4], b[4];

	parse(color, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	red = str_to_num(r);
	green = str_to_num(g);
	blue = str_to_num(b);
}

public CvarHudColorHook(pcvar, const old_value[], const new_value[]) {
	SetHudColorCvarByString(new_value, gHudRed, gHudGreen, gHudBlue);
}

public EventIntermissionMode() {
	gBlockCmdKill = true;
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gVersusStarted = false; // allow specs at the end to talk

	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	for (new i; i < numPlayers; i++) {
		FreezePlayer(players[i]); // sometimes in intermission mode, player can move...
	}
}

public StartIntermissionMode() {
	new ent = create_entity("game_end");
	if (is_valid_ent(ent))
		ExecuteHamB(Ham_Use, ent, 0, 0, 1.0, 0.0);
}

public CacheTeamListModels(teamlist[][], size) {
	new file[128];
	for (new i; i < size; i++) {
		formatex(file, charsmax(file), "models/player/%s/%s.mdl", teamlist[i], teamlist[i]);
		if (file_exists(file))
			engfunc(EngFunc_PrecacheModel, file);
	}
}

public GetTeamListModels(output[][], size) {
	new teamlist[192];
	get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));

	new nIdx, nLen = (1 + copyc(output[nIdx], size, teamlist, ';'));

	while (nLen < strlen(teamlist) && ++nIdx < HL_MAX_TEAMS)
		nLen += (1 + copyc(output[nIdx], size, teamlist[nLen], ';'));
}

bool:IsObserver(id) {
	return get_ent_data(id, "CBasePlayer", "m_afPhysicsFlags") & PFLAG_OBSERVER > 0 ? true : false;
}


bool:IsInWelcomeCam(id) {
	return IsObserver(id) && !hl_get_user_spectator(id) && get_ent_data(id, "CBasePlayer", "m_iHideHUD") & (HIDEHUD_WEAPONS | HIDEHUD_HEALTH);
}

stock ag_get_team_alives(teamIndex) {
	new players[MAX_PLAYERS], numPlayers;
	get_players_ex(players, numPlayers, GetPlayers_ExcludeDead);

	new num;
	for (new i; i < numPlayers; i++)
		if (hl_get_user_team(players[i]) == teamIndex)
			num++;

	return num;
}

// when user spectates, his teams is 0, so you have to check his model..
stock ag_get_team_numplayers(teamIndex) {
	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	new model[16], numTeam;
	for (new i; i < numPlayers; i++) {
		hl_get_user_model(players[i], model, charsmax(model));
		// ignore case, sometimes a player set his model to barNey...
		if (equali(model, gTeamListModels[teamIndex - 1])) 
			numTeam++; 
	}

	return numTeam;
}

stock swap(&x, &y) {
	x = x + y;
	y = x - y;
	x = x - y;
}

stock RemoveExtension(const input[], output[], length, const ext[]) {
	copy(output, length, input);

	new idx = strlen(input) - strlen(ext);
	if (idx < 0) return 0;
	
	return replace(output[idx], length, ext, "");
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

IsUserServer(id) {
	if (is_dedicated_server()) {
		if (!id) {
			return true;
		}
	} else { // listen server
		new ip[MAX_IP_LENGTH];
		get_user_ip(id, ip, charsmax(ip), true);
		if (equal(ip, "loopback")) {
			return true;
		}
	} 
	return false;
}

public native_ag_vote_add(plugin_id, argc) {
	if (argc < 2)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));
	new funcName[64]; get_string(2, funcName, charsmax(funcName)); // the callback function

	new fwHandle = CreateMultiForward(funcName, ET_STOP, FP_CELL, FP_CELL, FP_CELL, FP_ARRAY, FP_ARRAY);

	if (fwHandle == -1)
		return false;

	TrieSetCell(gTrieVoteList, voteName, fwHandle);

	return true;
}

public native_ag_vote_remove(plugin_id, argc) {
	if (argc < 1)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));

	if (TrieKeyExists(gTrieVoteList, voteName)) {
		new handle;
		TrieGetCell(gTrieVoteList, voteName, handle);
		TrieDeleteKey(gTrieVoteList, voteName);
		DestroyForward(handle);
		return true;
	}

	return false;
}

public native_ag_vote_exists(plugin_id, argc) {
	if (argc < 1)
		return false;

	new voteName[32]; get_string(1, voteName, charsmax(voteName));

	if (TrieKeyExists(gTrieVoteList, voteName))
		return true;

	return false;
}
