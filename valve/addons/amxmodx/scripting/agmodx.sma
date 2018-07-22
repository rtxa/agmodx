/*
	Adrenaline Gamer Mod X by rtxa

	Acknowledgements:
	Bullit for creating Adrenaline Gamer
	Lev for his Bugfixed and Improved HL Release
	KORD_27 for his hl.inc

	Information:
	An improved Mini AG alternative, made as a plugin for AMX Mod X from zero, to make it easier add improvements, features, fix annoying bugs, etc.
	
	Features:
	AMX Mod X 1.8.3
	Bugfixed and Improved HL Release
	Multilingual (Spanish and English 100%)

	More info in: aghl.ru/forum/viewtopic.php?f=19&t=2926
	Contact: usertxa@gmail.com
*/

#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hl>

#define PLUGIN  "AG Mod X"
#define VERSION "Beta 1.0 Build 17/7/2018"
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
	"agstart",
	"agabort",
	"agallow",
	"agpause",
	"agnextmap",
	"agnextmode",
	"arcade",
	"arena",
	"ffa",
	"lms",
	"lts",
	"no",
	"settings",
	"tdm",
	"vote",
	"yes",
};

// sounds 
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

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

#define HL_MAX_TEAMNAME_LENGTH 16

// Team models (this is used to fix team selection from VGUI Viewport)
new gTeamListModels[HL_MAX_TEAMS][HL_MAX_TEAMNAME_LENGTH];

// Game player equip keys
new gGamePlayerEquipKeys[32][32];

// Location system
new gLocationName[128][32]; 	// Max locations (128) and max location name length (32);
new Float:gLocationOrigin[128][3]; 	// Max locations and origin (x, y, z)
new gNumLocations;

#define MAXVALUE_TIMELIMIT 1410065407
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
new bool:gSendVictimToSpec;
new bool:gSendConnectingToSpec;
new bool:gRestorePlayerEquipOnKill;

// gamemode flags
new bool:gIsArenaMode;
new bool:gIsLtsMode;
new bool:gIsLmsMode;

// arena vars
new Array:gArenaQueue;
new gNameWinner[MAX_NAME_LENGTH];
new gNameLooser[MAX_NAME_LENGTH];
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

// restore score system: array index
#define SCORE_FRAGS 0
#define SCORE_DEATHS 1

new Trie:gTrieScoreAuthId; // handle where it saves all the authids of players playing a versus for rescore system...

enum {
	VOTE_VALID,
	VOTE_INVALID,
	VOTE_INVALID_MAP,
	VOTE_INVALID_MODE,
	VOTE_INVALID_NUMBER
}

// This and gVoteList have to be in the same order...
enum {
	VOTE_AGABORT,
	VOTE_AGALLOW,
	VOTE_AGNEXTMAP,
	VOTE_AGNEXTMODE,
	VOTE_AGPAUSE,
	VOTE_AGSTART,
	VOTE_MAP,
	VOTE_FRIENDLYFIRE,
	VOTE_SELFGAUSS,
	VOTE_TIMELIMIT,
	VOTE_MODE // modes always have to be at the end
}

// this is used for check if user's vote is valid
new const gVoteList[][] = {
	"agabort",
	"agallow",
	"agnextmap",
	"agnextmode",
	"agpause",
	"agstart",
	"map",
	"mp_friendlyfire",
	"mp_selfgauss",
	"mp_timelimit",
};

// this is used for check if user's vote is valid (this can be replaced with a dinamic array to block some modes)
new const gVoteListModes[][] = {
	"arena",
	"tdm",
	"arcade",
	"lts",
	"lms",
	"ffa"
};

#define VOTE_YES 1
#define VOTE_NO -1

// vote system
new Trie:gTrieVoteList;
new bool:gVoteStarted;
new Float:gVoteFailedTime; // in seconds
new gVotePlayers[33]; // 1: vote yes; 0: didn't vote; -1; vote no; 
new gVoteArg1[32];
new gVoteArg2[32];
new gVoteCallerName[MAX_NAME_LENGTH];
new gVoteMode;

// array size of some gamemode cvars
#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11 
#define SIZE_BANWEAPONS 14
#define SIZE_AMMOENTS 9

// cvar pointers
new gCvarContact;
new gCvarGameName;
new gCvarGameMode;
new gCvarHudColor;
new gCvarSpecTalk;
new gCvarAllowVote;
new gCvarVoteFailedTime;
new gCvarVoteDuration;
new gCvarAgStartMinPlayers;
new gCvarAgStartAllowUnlimited;
new gCvarAmxNextMap;

new gCvarTimeLimit;
new gCvarFragLimit;
new gCvarFriendlyFire;
new gCvarForceRespawn;
new gCvarSelfGauss;

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

new const gNameStartWeapons[SIZE_WEAPONS][] = {
	"sv_ag_start_357",
	"sv_ag_start_9mmar",
	"sv_ag_start_9mmhandgun",
	"sv_ag_start_crossbow",
	"sv_ag_start_crowbar",
	"sv_ag_start_egon",
	"sv_ag_start_gauss",
	"sv_ag_start_hgrenade",
	"sv_ag_start_hornetgun",
	"sv_ag_start_rpg",
	"sv_ag_start_satchel",
	"sv_ag_start_shotgun",
	"sv_ag_start_snark",
	"sv_ag_start_tripmine",
};

new const gNameStartAmmo[SIZE_AMMO][] = {
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

new const gNameBanWeapons[SIZE_BANWEAPONS][] = {
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

new const gNameBanAmmo[SIZE_AMMOENTS][] = {
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
	"weapon_egon",
	"weapon_gauss",
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
	create_cvar("agmodx_version", VERSION, FCVAR_SERVER);
	gCvarContact = get_cvar_pointer("sv_contact");

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
	gCvarGameName = create_cvar("sv_ag_gamename", "", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarGameMode = create_cvar("sv_ag_gamemode", "tdm", FCVAR_SERVER | FCVAR_SPONLY);
	gCvarStartHealth = create_cvar("sv_ag_start_health", "100");
	gCvarStartArmor = create_cvar("sv_ag_start_armor", "0");
	gCvarStartLongJump = create_cvar("sv_ag_start_longjump", "0");
	gCvarBanHealthKit = create_cvar("sv_ag_ban_healthkit", "0");
	gCvarBanBattery = create_cvar("sv_ag_ban_battery", "0");
	gCvarBanLongJump = create_cvar("sv_ag_ban_longjump", "0");
	gCvarBanHealthCharger = create_cvar("sv_ag_ban_healthcharger", "0");
	gCvarBanHevCharger = create_cvar("sv_ag_ban_hevcharger", "0");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = create_cvar(gNameStartWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = create_cvar(gNameStartAmmo[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanWeapons; i++)
		gCvarBanWeapons[i] = create_cvar(gNameBanWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarBanAmmo; i++)
		gCvarBanAmmo[i] = create_cvar(gNameBanAmmo[i], "0", FCVAR_SERVER);

	// Multiplayer cvars
	gCvarTimeLimit = get_cvar_pointer("mp_timelimit");
	gCvarFragLimit = get_cvar_pointer("mp_fraglimit");
	gCvarForceRespawn = get_cvar_pointer("mp_forcerespawn");
	gCvarFriendlyFire = get_cvar_pointer("mp_friendlyfire");
	gCvarSelfGauss = get_cvar_pointer("mp_selfgauss");
	
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
	register_forward(FM_ClientKill, "PlayerKill");
	RegisterHam(Ham_Killed, "player", "PlayerKilled");
	RegisterHam(Ham_Spawn, "player", "PlayerPostSpawn", true);
	RegisterHam(Ham_Spawn, "player", "PlayerPreSpawn");

	register_concmd("help", "CmdHelp", ADMIN_ALL, "HELP_HELP", _, true);
	register_concmd("timeleft", "CmdTimeLeft", ADMIN_ALL, "HELP_TIMELEFT", _, true);
	register_concmd("agabort", "CmdAgAbort", ADMIN_BAN, "HELP_AGABORT", _, true);
	register_concmd("agallow", "CmdAgAllow", ADMIN_BAN, "HELP_AGALLOW", _, true);
	register_concmd("agpause", "CmdAgPause", ADMIN_BAN, "HELP_AGPAUSE", _, true);
	register_concmd("agstart", "CmdAgStart", ADMIN_BAN, "HELP_AGSTART", _, true);
	register_concmd("agnextmode", "CmdAgNextMode", ADMIN_BAN, "HELP_AGNEXTMODE", _, true);
	register_concmd("agnextmap", "CmdAgNextMap", ADMIN_BAN, "HELP_AGNEXTMAP", _, true);
	register_concmd("arcade", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	register_concmd("arena", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	register_concmd("ffa", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	register_concmd("lms", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	register_concmd("lts", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	register_concmd("tdm", "CmdChangeMode", ADMIN_BAN, "HELP_MODE", _, true);
	
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

	// i create this cmds to set pausable to 0 or remove admin cvar access (can be both)
	register_clcmd("pauseAgUser", "CmdPauseAgUser");
	register_clcmd("pauseAgAdmin", "CmdPauseAgAdmin");
	
	// debug arena mode
	//register_concmd("PrintArenaQueue", "PrintArenaQueue");

	// pause it because "say timeleft" shows wrong timeleft, unless we modify the amx plugin, or put the plugin first and create our own timeleft cmd...
	pause("cd", "timeleft.amxx");

	// i'm not sure if its fixed, sometimes i get a bad cvar pointer
	gCvarAmxNextMap = get_cvar_pointer("amx_nextmap");

	// debug for arena, lts and lms
	register_clcmd("userinfo", "CmdUserInfo");

	// Modify say with AG Say Style
	register_message(get_user_msgid("SayText"), "MsgSayText");

	gHudShowVote = CreateHudSyncObj();
	gHudShowMatch = CreateHudSyncObj();
	gHudShowTimeLeft = CreateHudSyncObj();

	// this saves score of players that're playing a match
	// so if someone get disconnect by any reason, the score will be restored when he returns
	gTrieScoreAuthId = TrieCreate();
	gArenaQueue = ArrayCreate();
	CreateVoteSystem();
	// this is used for change hud colors of ag mod x
	hook_cvar_change(gCvarHudColor, "CvarHudColorHook");

	StartTimeLeft();

	StartMode();
}

// Change game description to show current AG mode  when you find servers (ex: AG TDM)
public FwGameDescription() {
	new name[32];
	get_pcvar_string(gCvarGameName, name, charsmax(name));
	forward_return(FMV_STRING, name);
	return FMRES_SUPERCEDE;
}

public client_putinserver(id) {
	new authid[32];
	get_user_authid(id, authid, charsmax(authid));

	// restore score by steamid
	if (TrieKeyExists(gTrieScoreAuthId, authid))
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
	// reset player vote and update showvote
	if (gVoteStarted) {
		gVotePlayers[id] = 0;
		ShowVote();
	}

	new authid[32];
	get_user_authid(id, authid, charsmax(authid));

	// save score by steamid
	if (gVersusStarted && TrieKeyExists(gTrieScoreAuthId, authid)) {
		new score[2];

		score[SCORE_FRAGS] = get_user_frags(id);
		score[SCORE_DEATHS] = hl_get_user_deaths(id);

		// save frags and deaths by authid
		TrieSetArray(gTrieScoreAuthId, authid, score, sizeof score);

		console_print(0, "%L", LANG_PLAYER, "MATCH_LEAVE", authid, score[SCORE_FRAGS], score[SCORE_DEATHS]);
	}

	return PLUGIN_HANDLED;
}

// here is_user_alive(id) will show 0 :)
public client_remove(id) {
	if (gIsArenaMode) {
		EndArena(id);
	} else if (gIsLtsMode) {
		EndMatchLts();
	} else if (gIsLmsMode) {
		EndMatchLms();	
	}

	return PLUGIN_HANDLED;
}

public RestoreScore(authid[], id) {	
	new score[2];	
	if (TrieGetArray(gTrieScoreAuthId, authid, score, sizeof score)) {
		set_user_frags(id, score[SCORE_FRAGS]);
		hl_set_user_deaths(id, score[SCORE_DEATHS]);
		//server_print("* Authid putin: %s; frags: %i; deaths: %i;", authid, score[SCORE_FRAGS], score[SCORE_DEATHS]);
	}
}

public PlayerPreSpawn(id) {
	// if player has to spec, don't let him spawn...
	if (task_exists(TASK_SENDVICTIMTOSPEC + id))
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public PlayerPostSpawn(id) {
	// when he spawn, the hud gets reset so allow him to show settings again
	remove_task(id + TASK_SHOWSETTINGS);

	// here happens the same thing
	if (gVoteStarted)
		set_task(0.1, "ShowVote", TASK_SHOWVOTE); 

	if (is_user_alive(id)) // what happens if users spawn dead? it's just a prevention.
		SetPlayerStats(id); // note: you cant set stats on pre spawn

}

public PlayerKill(id) {
	if (gBlockCmdKill)
		return FMRES_SUPERCEDE;
	return FMRES_IGNORED;
}

public PlayerKilled(victim, attacker) {
	//server_print("Victim %i attacker %i", victim, attacker);
	if (gSendVictimToSpec)
		set_task(3.0, "SendVictimToSpec", victim + TASK_SENDVICTIMTOSPEC);

	// Arena
	if (gIsArenaMode) {
		if (victim != attacker && IsPlayer(attacker)) { // what happens if victim die by fall?
			gMatchWinner = attacker;
			gMatchLooser = victim;
		} else if (gMatchWinner == victim) {
			new temp = gMatchLooser;
			gMatchLooser = victim;
			gMatchWinner = temp;
		}

		//server_print("(PlayerKilled) Winner: %i; Looser: %i", gMatchWinner, gMatchLooser);

		set_user_godmode(gMatchWinner, true); // avoid kill himself or get hurt by victim after win

		// Send looser to the end of the queue
		new idx =  ArrayFindValue(gArenaQueue, gMatchLooser);
		if (idx != -1) {
			ArrayDeleteItem(gArenaQueue, idx);
			ArrayPushCell(gArenaQueue, gMatchLooser);
		}

		get_user_name(gMatchWinner, gNameWinner, charsmax(gNameWinner));

		// Show winner
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.2, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WINNER", gNameWinner);

		set_task(5.0, "StartArena", TASK_STARTMATCH); // start new match after win match
	}

	// Arcade
	if (is_user_alive(attacker) && gRestorePlayerEquipOnKill) {
		set_user_health(attacker, get_pcvar_num(gCvarStartHealth));
		set_user_armor(attacker, get_pcvar_num(gCvarStartArmor));
		GiveAmmo(attacker);
	}

	// Last Team Standing and Last Man Standing
	if (gIsLtsMode)
		EndMatchLts();
	else if (gIsLmsMode)
		EndMatchLms();

}

/*
* Set player equipment of current gamemode
*/
SetGameModePlayerEquip() {
	new ent = find_ent_by_class(0, "game_player_equip");

	if (!ent)
		ent = create_entity("game_player_equip");

	for (new i; i < SIZE_WEAPONS; i++) {
		// If the weapon exists in the game_player_equip, do not create it again...
		if (get_pcvar_num(gCvarStartWeapons[i]) && !ExistsKeyValue(gWeaponClass[i], gGamePlayerEquipKeys, sizeof gGamePlayerEquipKeys)) {
			DispatchKeyValue(ent, gWeaponClass[i], "1");
		}
	}
}

public ExistsKeyValue(const key[], source[][], size) {
	for (new i; i < size; i++) {
		if (equal(key, source[i]))
			return 1;
	}
	return 0;
}

// Get all keys of game_player_equip ent
public pfn_keyvalue(entid)  {
	new classname[32], key[32], value[4];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);
	static i;
	if (equal(classname, "game_player_equip")) {
		copy(gGamePlayerEquipKeys[i], charsmax(gGamePlayerEquipKeys), key);
		i++;
	}
}

SetPlayerStats(id) {
	set_user_health(id, get_pcvar_num(gCvarStartHealth));
	set_user_armor(id, get_pcvar_num(gCvarStartArmor));

	if (get_pcvar_bool(gCvarStartLongJump))
		hl_set_user_longjump(id, true);

	GiveAmmo(id);
}

public GiveAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // some maps like bootbox dont like this if i dont put this condition
			ag_set_user_bpammo(id, 310+i, get_pcvar_num(gCvarStartAmmo[i]));
	}
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
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WAITING");
		set_task(5.0, "StartMatchLms", TASK_STARTMATCH);
		return;
	}

	gStartMatchTime = 5;
	LmsMatchCountdown();
	set_task(1.0, "LmsMatchCountdown", TASK_STARTMATCH, _, _,"b");

}

public LmsMatchCountdown() {
	gStartMatchTime--;

	PlaySound(0, gCountSnd[gStartMatchTime]);

	if (gStartMatchTime == 0) {
		new players[32], numPlayers;
		ag_get_players(players, numPlayers);

		new player;
		for (new i; i < numPlayers; i++) {
			player = players[i];
			if (hl_get_user_spectator(player))
				ag_set_user_spectator(player, false);
			else
				hl_user_spawn(player);
		}

		RespawnAll();

		remove_task(TASK_STARTMATCH);

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_START", gStartMatchTime);
}

public EndMatchLms() {
	if (task_exists(TASK_STARTMATCH))
		return;

	new alive[MAX_PLAYERS], numAlives;
	get_players(alive, numAlives, "a");

	switch (numAlives) {
		case 1: {
			set_user_godmode(alive[0], true);

			new name[MAX_NAME_LENGTH];
			get_user_name(alive[0], name, charsmax(name));

			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
			ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WINNER", name);

			set_task(5.0, "StartMatchLms", TASK_STARTMATCH);	
		} 
		case 0: {
			set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
			ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_DRAW");

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
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WAITING");
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
		return;
	}

	gStartMatchTime = 5;
	LtsMatchCountdown();
	set_task(1.0, "LtsMatchCountdown", TASK_STARTMATCH, _, _,"b");

}

public LtsMatchCountdown() {
	gStartMatchTime--;

	PlaySound(0, gCountSnd[gStartMatchTime]);

	if (gStartMatchTime == 0) {
		new players[32], numPlayers;
		ag_get_players(players, numPlayers);

		new player;
		for (new i; i < numPlayers; i++) {
			player = players[i];
			if (hl_get_user_spectator(player))
				ag_set_user_spectator(player, false);
			else
				hl_user_spawn(player);
		}

		remove_task(TASK_STARTMATCH);

		RespawnAll();

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_START", gStartMatchTime);
}

SetGodModeAlives() {
	for (new id = 1; id <= MaxClients; id++)
		if (is_user_alive(id))
			set_user_godmode(id, true);
}

public GetNumAlives() {
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
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WINNER_RED");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	} else if (numAlivesRed == 0 && numAlivesBlue > 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WINNER_BLUE");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	} else if (numAlivesRed == 0 && numAlivesBlue == 0) {
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_DRAW");
		SetGodModeAlives();
		set_task(5.0, "StartMatchLts", TASK_STARTMATCH);
	}	
}

stock AutoTeamBalance() {

}
stock AutoAssing() {

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

		get_user_name(gMatchWinner, gNameWinner, charsmax(gNameWinner));
		get_user_name(gMatchLooser, gNameLooser, charsmax(gNameLooser));

		//server_print("(StartArena) Last Winner %i vs New %i", gMatchWinner, gMatchLooser);
		
		gStartMatchTime = 5;
		ArenaCountdown();
		set_task(1.0, "ArenaCountdown", TASK_STARTMATCH, _, _,"b");
	} else { // Wait for more players...
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5);
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WAITING");
		
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
			ag_set_user_spectator(gMatchWinner, false);
		else
			hl_user_spawn(gMatchWinner);

		ag_set_user_spectator(gMatchLooser, false);

		ClearField();

		remove_task(TASK_STARTMATCH);

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.5, -1); 
	ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_STARTARENA", gNameWinner, gNameLooser, gStartMatchTime);
}

public EndArena(id) {
	if (task_exists(TASK_STARTMATCH))
		return;
		
	if (GetNumAlives() < 2) {
		if (id == gMatchWinner)
			gMatchWinner = gMatchLooser;

		get_user_name(gMatchWinner, gNameWinner, charsmax(gNameWinner));

		// Show winner
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 4.0, 0.2, 0.2, -1); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_WINNER", gNameWinner);

		set_task(5.0, "StartArena", TASK_STARTMATCH); // start new match after win match	
	}
}

// this will add to the queue newly connected players and it will remove disconnected players
public CountArenaQueue() {
	new isUserConnected, arrayIdx;

	for (new id = 1; id <= MaxClients; id++) {
		isUserConnected = is_user_connected(id);
		arrayIdx = ArrayFindValue(gArenaQueue, id);

		if (arrayIdx != -1) { // player is in the queue?
			if (!isUserConnected) // he has disconnected? then remove it of the queue
				ArrayDeleteItem(gArenaQueue, arrayIdx);
		} else { // is a new player? then add it to the queue
			if (isUserConnected)
				ArrayPushCell(gArenaQueue, id);
		}
	}
}

public PrintArenaQueue() {
	for (new i; i < ArraySize(gArenaQueue); i++) {
		server_print("i. %i", ArrayGetCell(gArenaQueue, i));
	}
}

public CmdTimeLeft(id) {
	console_print(id, "timeleft: %i:%02i", 
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft / 60, // minutes
		gTimeLeft == TIMELEFT_SETUNLIMITED ? 0 : gTimeLeft % 60); // seconds
}

/*
* Timeleft/Timelimit System
*/

public StartTimeLeft() {
	// from now, i'm going to use my own timeleft and timelimit
	gTimeLimit = get_pcvar_num(gCvarTimeLimit);
	gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;

	// set mp_timelimit to "unlimited" and block changes so no one mess the timelimit
	set_pcvar_num(gCvarTimeLimit, MAXVALUE_TIMELIMIT);
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
		ShowSyncHudMsg(0, gHudShowTimeLeft, "%L", LANG_PLAYER, "TIMER_UNLIMITED");
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
			client_print(0, print_center, "%L", LANG_PLAYER, "MATCH_DENY_CHANGEUNLIMITED");
		} else {
			gTimeLeft = TIMELEFT_SETUNLIMITED;
			gTimeLimit = timeLimit;
		}
	} else {
		gTimeLeft =  timeLimit * 60;
		gTimeLimit = timeLimit;
	}

	// always set it to unlimited, so players can't change the cvar value and finish the map (go to intermission mode) by accident...	
	set_pcvar_num(pcvar, MAXVALUE_TIMELIMIT);

	enable_cvar_hook(gHookCvarTimeLimit);
}

/* 
* AgStart
*/
public StartVersus() {
	if (get_playersnum() < get_pcvar_num(gCvarAgStartMinPlayers)) {
		client_print(0, print_center, "%L", LANG_PLAYER, "MATCH_MINPLAYERS", get_pcvar_num(gCvarAgStartMinPlayers));
		return;
	} else if (gTimeLimit <= 0 && !get_pcvar_num(gCvarAgStartAllowUnlimited)) { // start versus with mp_timelimit 0
		client_print(0, print_center, "%L", LANG_PLAYER, "MATCH_DENY_STARTUNLIMITED");
		return;
	}

	// remove previous start match even if doesnt exist
	remove_task(TASK_STARTVERSUS);

	// clean list of authids to begin a new match
	TrieClear(gTrieScoreAuthId);

	// gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gSendConnectingToSpec = true;

	// reset score and freeze players who are going to play versu
	for (new id = 1; id <= MaxClients; id++) {
		if (pev_valid(id) != 2)
			continue;

		if (IsObserver(id) && pev(id, pev_deadflag) != DEAD_RESPAWNABLE) // this is to avoid set spec to dead players, just i wnat to spec players  in welcome cam 
			ag_set_user_spectator(id);

		if (is_user_connected(id) && !hl_get_user_spectator(id)) {
			ResetScore(id);
			FreezePlayer(id);
		}
	}

	// prepare the match field
	ClearField();
	RespawnAll();
	ResetChargers();

	gStartVersusTime = 10;
	StartVersusCountdown();
	set_task(1.0, "StartVersusCountdown", TASK_STARTVERSUS, _, _,"b");
}

public StartVersusCountdown() {
	gStartVersusTime--;

	PlaySound(0, gCountSnd[gStartVersusTime]);
		
	if (gStartVersusTime == 0) {
		remove_task(TASK_STARTVERSUS); // stop countdown

		gVersusStarted = true;

		gBlockCmdDrop = false;

		// message hold on a lot of time to avoid flickering or dissapearing, so remove it manually
		ClearSyncHud(0, gHudShowMatch);

		new authid[32];
		for (new id = 1; id <= MaxClients; id++) {
			if (is_user_connected(id) && !hl_get_user_spectator(id)) {
				get_user_authid(id, authid, charsmax(authid));

				// when a match start, save authid of every match player
				TrieSetCell(gTrieScoreAuthId, authid, 0);

				hl_user_spawn(id);

				set_task(0.5, "ShowSettings", id);
			}
		}

		// set new timeleft according to timelimit
		gTimeLeft = gTimeLimit == 0 ? TIMELEFT_SETUNLIMITED : gTimeLimit * 60;

		return;
	}

	PlaySound(0, gBeepSnd);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.2, 0, 3.0, 15.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_START", gStartVersusTime);
}

/* 
* AgAbort
*/
public AbortVersus() {
	server_print("AgAbort");

	gVersusStarted = false;

	// clear authids to prepare for the next match
	TrieClear(gTrieScoreAuthId);

	// remove start match hud
	remove_task(TASK_STARTVERSUS);

	// restore gamerules
	gBlockCmdSpec = false;
	gBlockCmdDrop = false;
	gSendConnectingToSpec = false;

	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_alive(id)) {
			//ClearSyncHud(0, gHudShowMatch);
			FreezePlayer(id, false);
		} else if (hl_get_user_spectator(id))
			ag_set_user_spectator(id, false);
	}
}

ResetScore(id) {
	set_user_frags(id, 0);
	hl_set_user_deaths(id, 0);
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
	ag_set_user_spectator(id, true);
}

public SendVictimToSpec(taskid) {
	new id = taskid - TASK_SENDVICTIMTOSPEC;
	if (is_user_connected(id)) {
		if (!is_user_alive(id) || is_user_bot(id)) {
			ag_set_user_spectator(id, true);
		}
	}
}

/*
* AG Say
*/
public MsgSayText(msg_id, msg_dest, dest_id) {
	new text[191]; // 192 will crash the sv if someone put a large message with any %l, %w, etc...
	
	get_msg_arg_string(2, text, charsmax(text)); // get user message
	
	if (text[0] == '*') // ignore server messages
		return PLUGIN_CONTINUE;

	new id = get_msg_arg_int(1);

	// Add or change channel tags	
	if (is_user_connected(id)) { 
		if (hl_get_user_spectator(id)) {
			if (containi(text, "(TEAM)") != -1) {
				replace(text, charsmax(text), "(TEAM)", "(ST)"); // Spectator Team
				if (dest_id != id && !hl_get_user_spectator(dest_id)) // only show messages to spectator
					return PLUGIN_HANDLED;
			} else {
				format(text, charsmax(text), "^x02(S)%s", text); // Spectator
				if (dest_id != id && gVersusStarted && !get_pcvar_num(gCvarSpecTalk)) // spec cant talk to people in vs so block it
					return PLUGIN_HANDLED;
			}
		} else {
			if (containi(text, "(TEAM)") != -1) { // Team
				replace(text, charsmax(text), "(TEAM)", "(T)"); 
				if (dest_id != id && hl_get_user_spectator(dest_id))
					return PLUGIN_HANDLED;
			} else {
				format(text, charsmax(text), "^x02(A)%s", text); // All
			}
		}
	}

	// replace all %h with health
	replace_string(text, charsmax(text), "%h", fmt("%i", get_user_health(id)), false);

	// replace all %a with armor
	replace_string(text, charsmax(text), "%a", fmt("%i", get_user_armor(id)), false);

	// replace all %p with longjump
	replace_string(text, charsmax(text), "%p", hl_get_user_longjump(id) ? "On" : "Off", false);

	// replace all %l with location
	replace_string(text, charsmax(text), "%l", gLocationName[FindNearestLocation(id, gLocationOrigin, gNumLocations)], false);

	// replace all %w with name of current weapon
	new ammo, bpammo, weaponid = get_user_weapon(id, ammo, bpammo);

	if (weaponid) {
		new weaponName[32];
		get_weaponname(weaponid, weaponName, charsmax(weaponName));
		replace_string(weaponName, charsmax(weaponName), "weapon_", "");
		replace_string(text, charsmax(text), "%w", weaponName, false);
	}

	// replace all %q with total ammo (ammo and backpack ammo) of current weapon
	replace_string(text, charsmax(text), "%q", fmt("%i", ammo < 0 ? bpammo : ammo + bpammo), false); // when the weapon doesnt have ammo, it shows -1, replace it with 0

	// send final message
	set_msg_arg_string(2, text);

	return PLUGIN_CONTINUE;
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

// return the index of the nearest location from an array
public FindNearestLocation(id, Float:locOrigin[][3], numLocs) {
	new Float:userOrigin[3], Float:nearestOrigin[3], idxNearestLoc;
	
	pev(id, pev_origin, userOrigin);
	
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

	console_print(id, "----- Ag Mod X -----");
	for (new i; i < get_clcmdsnum(-1); i++) {
		isInfoMl = false;
		if (!get_clcmd(i, cmd, charsmax(cmd), flags, info, charsmax(info), ADMIN_BAN, isInfoMl)) 
			continue;
		for (new i; i < sizeof gHelpList; i++) {
			if (isInfoMl)
				LookupLangKey(info, charsmax(info), info, id);

			if (equal(cmd, gHelpList[i]))
				console_print(id, "%i. %s %s", ++j, cmd, info);
		}
	}
	console_print(id, "--------------------");
}

public CmdSpectate(id) {
	new authid[32];
	get_user_authid(id, authid, charsmax(authid));

	if (TrieKeyExists(gTrieScoreAuthId, authid)) { // let user spectate if he is playing a versus
		if (!hl_get_user_spectator(id)) // set score when he is in spec will mess up the scoreboard (bugfixed hl bug?)
			ResetScore(id); // Penalize players when they go to spec in a match
	} else if (gBlockCmdSpec)
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public CmdChangeTeam(id) {
	// we need to show a menu to choose team because VGUI Viewport just show you 4 teams.
	return PLUGIN_HANDLED;
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
}

public CmdDrop() {
	if (gBlockCmdDrop)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public ShowNextMap(taskid) {
	new id = taskid - TASK_SHOWSETTINGS;

	new map[32];
	get_pcvar_string(gCvarAmxNextMap, map, charsmax(map));

	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.055, 0, 0.0, 5.0, 0.2);
	show_dhudmessage(id, "%L", LANG_PLAYER, "SETTINGS_NEXTMAP", map);
}

// We need to use director hud msg because there aren't enough hud channels, unless we make a better gui that use less channels
// We are limited to 128 characters, so that is bad for multilingual or to show more settings ...
public ShowSettings(id) {
	// avoid hud overlap
	if (task_exists(id + TASK_SHOWSETTINGS) || !is_user_connected(id))
		return;

	set_task(10.0, "ShowSettings", id + TASK_SHOWSETTINGS); // this will stop hud overlap
	
	new arg[32], started[64];

	// left - top
	get_pcvar_string(gCvarContact, arg, charsmax(arg));
	formatex(started, charsmax(started), "%L", id, "MATCH_STARTED");
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "AG Mod X %s^n%s^n^n%s", VERSION, arg, gVersusStarted ? started : "");

	// center - top 
	get_mapname(arg, charsmax(arg));
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, 0.055, 0, 0.0, 4.5, 0.2);
	show_dhudmessage(id, "%L", LANG_PLAYER, "SETTINGS_CURRENTMAP", arg);
	set_task(5.0, "ShowNextMap", id + TASK_SHOWSETTINGS);

	// right - top
	get_pcvar_string(gCvarGameName, arg, charsmax(arg));
	set_dhudmessage(gHudRed, gHudGreen, gHudBlue, -0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(id, "%L", LANG_PLAYER, "SETTINGS_VARS", arg, gTimeLimit, 
		get_pcvar_num(gCvarFragLimit), 
		get_pcvar_num(gCvarFriendlyFire) ? "On" : "Off", 
		get_pcvar_num(gCvarForceRespawn) ? "On" : "Off",
		get_pcvar_num(gCvarSelfGauss) ? "On" : "Off");
}

public CmdAgPause(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	RemoveVote();
	PauseGame(id);

	return PLUGIN_CONTINUE;	
}

public CmdAgStart(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

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
				ag_set_user_spectator(i, false);
			else {
				ag_set_user_spectator(i, true);
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
			}
		}		
	}
	get_user_name(id, arg, charsmax(arg));
	server_print("Id: %i Nombre: %s inicio versus", id, arg);
	StartVersus();

	return PLUGIN_HANDLED;
}

public CmdAgAbort(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	AbortVersus();

	return PLUGIN_CONTINUE;
}

public CmdAgAllow(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	if (!gVersusStarted)
		return PLUGIN_HANDLED;

	new arg[32], player;
	read_argv(1, arg, charsmax(arg));

	if (!arg[0])
		player = id;
	else 
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);

	AllowPlayer(player);

	return PLUGIN_CONTINUE;
}

public AllowPlayer(id) {
	if (!is_user_connected(id) || !gVersusStarted)
		return PLUGIN_HANDLED;

	if (hl_get_user_spectator(id)) {
		new authid[32], name[32];
		get_user_authid(id, authid, charsmax(authid));

		// create a key for this new guy so i can save his score when he gets disconnect...
		TrieSetCell(gTrieScoreAuthId, authid, 0);

		ag_set_user_spectator(id, false);

		ResetScore(id);

		get_user_name(id, name, charsmax(name));

		client_print(0, print_chat,"* %L", LANG_PLAYER, "MATCH_ALLOW", name);

		set_hudmessage(gHudRed, gHudGreen, gHudBlue, -1.0, -1.0, 0, 0.0, 5.0); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_ALLOW", name);	
	}

	return PLUGIN_HANDLED;
}

public CmdAgNextMode(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	new arg[32], isValid;
	read_argv(1, arg, charsmax(arg));

	for (new i; i < sizeof gVoteListModes; i++)
		if (equal(arg, gVoteListModes[i])) {
			set_pcvar_string(gCvarGameMode, gVoteListModes[i]); // set new mode
			isValid = true;
		}

	if (!isValid) {
		console_print(id, "%L", LANG_PLAYER, "INVALID_MODE");
	}
	return PLUGIN_CONTINUE;
}

public CmdAgNextMap(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	new arg[32];
	read_argv(1, arg, charsmax(arg));

	if (is_map_valid(arg))
		set_pcvar_string(gCvarAmxNextMap, arg); // set new mode
	else
		console_print(id, "%L", LANG_PLAYER, "INVALID_MAP");

	return PLUGIN_CONTINUE;
}

public CmdChangeMode(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
	    return PLUGIN_HANDLED;

	new arg[32];
	read_argv(0, arg, charsmax(arg));

	for (new i; i < sizeof gVoteListModes; i++)
		if (equal(arg, gVoteListModes[i]))
			set_pcvar_string(gCvarGameMode, gVoteListModes[i]); // set new mode

	get_mapname(arg, charsmax(arg));
	server_cmd("changelevel %s", arg); // we need to reload the map so cvars can take effect

	return PLUGIN_CONTINUE;
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
	return PLUGIN_CONTINUE;
}

stock PrintUserInfo(caller, target) {
	new model[16];
	new team = hl_get_user_team(target);

	new iuser1 = pev(target, pev_iuser1);
	new iuser2 = pev(target, pev_iuser2);

	new alive = is_user_alive(target);
	new dead = pev(target, pev_deadflag);

	hl_get_user_model(target, model, charsmax(model));

	client_print(caller, print_chat, "Team: %i; Model: %s; iuser1: %i; iuser2: %i Alive: %i; Deadflag: %i", team, model, iuser1, iuser2, alive, dead);
}

/* 
* Vote system
*/
public CmdVoteYes(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_YES;
		ShowVote();
	}

	return PLUGIN_HANDLED;
}

public CmdVoteNo(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_NO;
		ShowVote();
	}

	return PLUGIN_HANDLED;
}

public CmdVote(id) {
	//server_print("CmdVote");

	if (!get_pcvar_num(gCvarAllowVote))
		return PLUGIN_HANDLED;

	// Print help on console
	if (read_argc() == 1) {
		new i, j;
		console_print(id, "%L", LANG_PLAYER, "VOTE_HELP");
		for (i = 0; i < sizeof gVoteListModes; i++)
			console_print(id, "%i. %s", ++j, gVoteListModes[i]);
		for (i = 0; i < sizeof gVoteList; i++)
			console_print(id, "%i. %s", ++j, gVoteList[i]);
		return PLUGIN_HANDLED;
	}

	// get delay time
	new Float:timeleft = gVoteFailedTime - get_gametime();

	if (timeleft > 0.0) {	
		console_print(id, "%L", LANG_PLAYER, "VOTE_DELAY", floatround(timeleft, floatround_floor));
		return PLUGIN_HANDLED;
	} else if (gVoteStarted) {
		console_print(id, "%L", LANG_PLAYER, "VOTE_RUNNING");
		return PLUGIN_HANDLED;
	}

	new arg1[32], arg2[32];

	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));

	/*if (gIsPause && !equal(arg1, "agpause")) {
		console_print(id,"%L", LANG_PLAYER, "VOTE_ONLYPAUSE");
		return PLUGIN_HANDLED;
	}*/
	
	if (IsVoteInvalid(id, arg1, arg2, charsmax(arg2)))
		return PLUGIN_HANDLED;

	gVoteArg1 = arg1;
	gVoteArg2 = arg2;
	TrieGetCell(gTrieVoteList, arg1, gVoteMode);
	gVoteStarted = true;
	gVotePlayers[id] = VOTE_YES;

	get_user_name(id, gVoteCallerName, charsmax(gVoteCallerName));

	// show vote
	ShowVote();

	// cancel vote after x seconds (set_task doesnt work in pause)
	set_task(get_pcvar_float(gCvarVoteDuration), "DenyVote", TASK_DENYVOTE);  

	return PLUGIN_HANDLED;
}

public ShowVote() {
	//server_print("ShowVote");
	
	if (!gVoteStarted) {
		RemoveVote();
		return;
	}

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
		set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 59.0, 0.2);
		ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_START", gVoteArg1, gVoteArg2, gVoteCallerName, numVoteFor, numVoteAgainst, numUndecided);
	}
}

public CreateVoteSystem() {
	gTrieVoteList = TrieCreate();
	for (new i; i < sizeof gVoteList; i++)
		TrieSetCell(gTrieVoteList, gVoteList[i], i);
	for (new i; i < sizeof gVoteListModes; i++) 
		TrieSetCell(gTrieVoteList, gVoteListModes[i], VOTE_MODE);
}

// remplezar todo con get_user_userid para que sea mas independiente...
public DoVote() {
	//server_print("DoVote");

	// show vote is accepted
	set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);

	// sometimes  hud doesnt show, show old style vote too
	client_print(0, print_center, "%L", LANG_PLAYER, "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);

	switch (gVoteMode) {
		case VOTE_AGSTART: 		StartVersus();
		case VOTE_AGABORT: 		AbortVersus();
		case VOTE_AGPAUSE: 		PauseGame(find_player("a", gVoteCallerName));
		case VOTE_AGALLOW: 		AllowPlayer(find_player("a", gVoteCallerName));
		case VOTE_MAP: 			ChangeMap(gVoteArg2);
		case VOTE_AGNEXTMAP:	set_pcvar_string(gCvarAmxNextMap, gVoteArg2);
		case VOTE_AGNEXTMODE:	set_pcvar_string(gCvarGameMode, gVoteArg2);
		case VOTE_SELFGAUSS:	set_pcvar_string(gCvarSelfGauss, gVoteArg2);
		case VOTE_TIMELIMIT:	set_pcvar_string(gCvarTimeLimit, gVoteArg2);
		case VOTE_FRIENDLYFIRE:	set_pcvar_string(gCvarFriendlyFire, gVoteArg2);
		case VOTE_MODE: 		ChangeMode(gVoteArg1);
	}
	
	RemoveVote();
}

public DenyVote() {
	//server_print("DenyVote");

	RemoveVote();
	gVoteFailedTime = get_gametime() + get_pcvar_num(gCvarVoteFailedTime);

	set_hudmessage(gHudRed, gHudGreen, gHudBlue, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);

	// sometimes  hud doesnt show, show old style vote too
	client_print(0, print_center, "%L", LANG_PLAYER, "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
}

public RemoveVote() {
	//server_print("RemoveVote");

	if (task_exists(TASK_DENYVOTE) && gVoteStarted) {
		gVoteStarted = false;
		remove_task(TASK_DENYVOTE);
	} else
		set_task(0.1, "RemoveVote");

	// reset user votes
	arrayset(gVotePlayers, 0, sizeof gVotePlayers);
}

bool:IsVoteInvalid(id, arg1[], arg2[], len) {
	new isInvalid, mode, player;

	if (!TrieGetCell(gTrieVoteList, arg1, mode))
		mode = -1;

	switch (mode) {
		case VOTE_AGSTART, VOTE_AGABORT, VOTE_AGPAUSE:
			isInvalid = VOTE_VALID;
		case VOTE_AGALLOW:
			isInvalid = (player = cmd_target(id, arg2, CMDTARGET_ALLOW_SELF)) ? get_user_name(player, arg2, len) : 0; // cmd_target shows his own error message.
		case VOTE_MAP, VOTE_AGNEXTMAP: 
			isInvalid = is_map_valid(arg2) ? VOTE_VALID : VOTE_INVALID_MAP;
		case VOTE_TIMELIMIT, VOTE_FRIENDLYFIRE, VOTE_SELFGAUSS:
			isInvalid = is_str_num(arg2) ? VOTE_VALID : VOTE_INVALID_NUMBER;
		case VOTE_AGNEXTMODE:
			isInvalid = TrieKeyExists(gTrieVoteList, arg2) ? VOTE_VALID : VOTE_INVALID_MODE;
		default:
			isInvalid = VOTE_INVALID;
	}

	switch (isInvalid) {
		case VOTE_INVALID: console_print(id, "%L", LANG_PLAYER, "VOTE_INVALID");
		case VOTE_INVALID_MAP: console_print(id, "%L", LANG_PLAYER, "INVALID_MAP");
		case VOTE_INVALID_MODE: console_print(id, "%L", LANG_PLAYER, "INVALID_MODE");
		case VOTE_INVALID_NUMBER: console_print(id, "%L", LANG_PLAYER, "INVALID_NUMBER");
	}

	return isInvalid > 0 ? true : false;
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
	client_cmd(id, "spk %s", sound);
}

public PlayTeam(caller) {
	if (gPlayTeamDelayTime[caller] < get_gametime()) 
		gPlayTeamDelayTime[caller] = get_gametime() + 0.75;
	else 
		return PLUGIN_HANDLED;

	new sound[32];
	read_argv(1, sound, charsmax(sound));

	new team = hl_get_user_team(caller);
	for (new id = 1; id < MaxClients; id++) {
		if (is_user_alive(id) && team == hl_get_user_team(id) )
			PlaySound(id, sound);
	}

	return PLUGIN_HANDLED;
}

StartMode() {
	new arg[32];
	get_pcvar_string(gCvarGameMode, arg, charsmax(arg));
	
	if (equal(arg, "arena"))
		StartArena();
	else if (equal(arg, "arcade"))
		StartArcade();
	else if (equal(arg, "lts"))
		StartMatchLts();
	else if (equal(arg, "lms"))
		StartMatchLms();
	
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
		RegisterHam(Ham_Use, "func_recharge", "BlockChargers");

	if (get_pcvar_num(gCvarBanHealthCharger))
		RegisterHam(Ham_Use, "func_healthcharger", "BlockChargers");	
}

public BlockChargers() {
	return HAM_SUPERCEDE;
}

// Advertise about the use of some commands in AG mod x
public DisplayInfo(id) {
	client_print(id, print_chat, "%L", LANG_PLAYER, "DISPLAY_INFO1");
	client_print(id, print_chat, "%L", LANG_PLAYER, "DISPLAY_INFO2");
}

// We can't pause the game from the server because is not connected, unless you have created the sv in-game. "Can't pause, not connected."
// So I found a way to make work pause, we need to give admin cvar access to the user, pause from him, then remove the admin access.
// I hope that you can't do command injection
PauseGame(id) {
	// remove vote so it doesn't get blocked
	RemoveVote();

	set_cvar_num("pausable", 1);

	if (get_user_flags(id) & ADMIN_CVAR) {
		client_cmd(id, "pause; pauseAgAdmin");
	} else {
		set_user_flags(id, ADMIN_CVAR);
		client_cmd(id, "pause; pauseAgUser");
	}

	if (gIsPause)
		gIsPause = false;
	else
		gIsPause = true;
}

public CmdPauseAgUser(id) {
	remove_user_flags(id, ADMIN_CVAR);
	set_cvar_num("pausable", 0);	
	return PLUGIN_HANDLED;
}

public CmdPauseAgAdmin(id) {
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
				set_pdata_int(i, 62, 30); // m_iJuice = 62
			} else if (equal(classname, "func_healthcharger")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_pdata_int(i, 62, 75); // m_iJuice = 62
			}
		}
	}
}

// This will respawn all weapons, ammo and items to prepare for a new match (agstart)
public RespawnAll() {
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

// is in welcome cam mode?
IsObserver(id) {
	return get_pdata_int(id, 193) & (1 << 5); // m_afPhysicsFlag = 193 and 1 << 5 pflag_observer
}

stock ag_get_players(players[MAX_PLAYERS], &numplayers) {
	arrayset(players, 0, charsmax(players));
	get_players(players, numplayers);
}

stock ag_get_team_alives(teamIndex) {
	new num;
	for (new id = 1; id <= MaxClients; id++)
		if (is_user_alive(id) && hl_get_user_team(id) == teamIndex)
			num++;

	return num;
}

// when user spectates, his teams is 0, so you have to check his model..
stock ag_get_team_numplayers(teamIndex) {
	new num, model[16];
	for (new id = 1; id <= MaxClients; id++){
		hl_get_user_model(id, model, charsmax(model));
		if (equali(model, gTeamListModels[teamIndex])) // equal with case ignoring, sometimes a player set his model to barNey...
			num++;
	}

	return num;
}

/* Restock/remove ammo in a user's backpack.
 */
stock ag_set_user_bpammo(client, weapon, ammo) {
	if(weapon <= HLW_CROWBAR)
		return;

	set_pdata_int(client, weapon, ammo, EXTRAOFFSET);
}

stock ag_set_user_spectator(client, bool:spectator = true) {
	if (hl_get_user_spectator(client) == spectator)
		return;

	if (spectator) {
		static AllowSpectatorsCvar;
		if (AllowSpectatorsCvar || (AllowSpectatorsCvar = get_cvar_pointer("allow_spectators"))) {
			if (!get_pcvar_num(AllowSpectatorsCvar))
				set_pcvar_num(AllowSpectatorsCvar, 1);

			engclient_cmd(client, "spectate");
		}
	} else {

		hl_user_spawn(client);

		set_pev(client, pev_iuser1, 0);
		set_pev(client, pev_iuser2, 0);

		set_pdata_int(client, OFFSET_HUD, 0);

		// clear center message on exit from spectator mode
 		client_print(client, print_center, "");

		static szTeam[16];
		hl_get_user_team(client, szTeam, charsmax(szTeam));

		// this fix when using openag client the scoreboard user colors
		static Spectator;
		if (Spectator || (Spectator = get_user_msgid("Spectator"))) {
			message_begin(MSG_ALL, Spectator);
			write_byte(client);
			write_byte(0);
			message_end();
		}

		static TeamInfo;
		if (TeamInfo || (TeamInfo = get_user_msgid("TeamInfo"))) {
			message_begin(MSG_ALL, TeamInfo);
			write_byte(client);
			write_string(szTeam);
			message_end();
		}
	}
}
