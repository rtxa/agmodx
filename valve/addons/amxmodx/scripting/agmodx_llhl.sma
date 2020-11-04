/*
    LLHL Gamemode for AG Mod X

    # New cvars:
    - sv_ag_fpslimit_check_interval "5.0"
    - sv_ag_fpslimit_max_detections "5"
    - sv_ag_fpslimit_max_fps "144"
    - sv_ag_fpslimiter_margin_error "0.6"
    - sv_ag_unstuck_cooldown "10.0"
    - sv_ag_check_soundfiles "1"
    - sv_ag_destroyable_satchel "1"
    - sv_ag_destroyable_satchel_hp "1"
    - sv_ag_block_namechange_inmatch "1"

    # New vote:
    - mp_respawn_fix "0/1"

    # Thanks to:
    - Th3-822: FPS Limiter
    - Alka: Server FPS
    - Arkshine: Unstuck command
    - Assassin, Darkzito, DieGo, Dcarlox, K3NS4N, Rhye, rtxa and Shadow: Testers
*/

#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <agmodx>
#include <agmodx_stocks>

#define PLUGIN      "AG Mod X LLHL"
#define VERSION     "Beta 2.4"
#define AUTHOR      "FlyingCat"

#pragma semicolon 1

#define MODE_TYPE_NAME "llhl"

#define GetPlayerHullSize(%1)  ((pev(%1, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN)

#define __is_user_alive(%1) (gIsAlive[%1])
new bool:gIsAlive[MAX_PLAYERS + 1];

#define precision_round(%1,%2) (float(floatround((%1)/ %2)) * %2)

enum (+=101) {
    TASK_FPSLIMITER = 36961,
    TASK_SHOWVENGINE
};

new gCvarFpsCheckInterval;
new gCvarFpsMaxDetections;
new gCvarFpsMax;
new gCvarFpsMarginError;
new gCvarAllowVoteSetting;
new gCvarUnstuckStartDistance;
new gCvarUnstuckMaxSearchAttempts;
new gCvarUnstuckCooldown;
new gCvarCheckSoundFiles;
new gCvarDestroyableSatchel;
new gCvarDestroyableSatchelHP;
new gCvarBlockNameChangeInMatch;
new gCvarRespawnFix;

new Float:gUnstuckLastUsed[MAX_PLAYERS + 1];
new Float:gLastProbeFPS[MAX_PLAYERS + 1];
new gProbeSum[MAX_PLAYERS + 1], gProbeCount[MAX_PLAYERS + 1], Float:gMeanFPS[MAX_PLAYERS + 1];
new gNumDetections[MAX_PLAYERS + 1];
new Float:gServerFPS;
static Float:gActualServerFPS;

// Sounds to check if sv_ag_check_soundfiles is 1
new const gConsistencySoundFiles[][] = {
    "ambience/pulsemachine.wav",
    "common/npc_step1.wav", "common/npc_step2.wav", "common/npc_step3.wav", "common/npc_step4.wav",
    "fvox/powermove_on.wav",
    "items/gunpickup2.wav",
    "player/pl_dirt1.wav", "player/pl_dirt2.wav", "player/pl_dirt3.wav", "player/pl_dirt4.wav",
    "player/pl_duct1.wav", "player/pl_duct2.wav", "player/pl_duct3.wav", "player/pl_duct4.wav",
    "player/pl_fallpain3.wav",
    "player/pl_grate1.wav", "player/pl_grate2.wav", "player/pl_grate3.wav", "player/pl_grate4.wav",
    "player/pl_ladder1.wav", "player/pl_ladder2.wav", "player/pl_ladder3.wav", "player/pl_ladder4.wav",
    "player/pl_metal1.wav", "player/pl_metal2.wav", "player/pl_metal3.wav", "player/pl_metal4.wav",
    "player/pl_pain2.wav",
    "player/pl_slosh1.wav", "player/pl_slosh2.wav", "player/pl_slosh3.wav", "player/pl_slosh4.wav",
    "player/pl_step1.wav", "player/pl_step2.wav", "player/pl_step3.wav", "player/pl_step4.wav",
    "player/pl_swim1.wav", "player/pl_swim2.wav", "player/pl_swim3.wav", "player/pl_swim4.wav",
    "weapons/egon_off1.wav",
    "weapons/egon_run3.wav",
    "weapons/egon_windup2.wav"
};

public plugin_precache() {
    if (!IsSelectedMode(MODE_TYPE_NAME)) {
        StopPlugin();
        return;
    }
}

// We create the cvars before 'exec gamemodes/%s.cfg'
public agmodx_pre_config() {
    gCvarAllowVoteSetting = get_cvar_pointer("sv_ag_vote_setting");

    // FPS Limiter
    gCvarFpsCheckInterval = create_cvar("sv_ag_fpslimit_check_interval", "5.0");
    gCvarFpsMaxDetections = create_cvar("sv_ag_fpslimit_max_detections", "5");
    gCvarFpsMax = create_cvar("sv_ag_fpslimit_max_fps", "144");
    gCvarFpsMarginError = create_cvar("sv_ag_fpslimiter_margin_error", "0.6");

    // Unstuck command
    gCvarUnstuckCooldown = create_cvar("sv_ag_unstuck_cooldown", "10.0");
    gCvarUnstuckStartDistance = create_cvar("sv_ag_unstuck_start_distance", "32");
    gCvarUnstuckMaxSearchAttempts = create_cvar("sv_ag_unstuck_max_attempts", "64");

    // Sound file checker
    gCvarCheckSoundFiles = create_cvar("sv_ag_check_soundfiles", "0");

    // Destroyable Satchel
    gCvarDestroyableSatchel =  create_cvar("sv_ag_destroyable_satchel", "0");
    gCvarDestroyableSatchelHP = create_cvar("sv_ag_destroyable_satchel_hp", "1");

    // Block name change (Only spectators) log in match
    gCvarBlockNameChangeInMatch = create_cvar("sv_ag_block_namechange_inmatch", "1");

    // Make respawn delay consistent in all fps values (already implemented by BugfixedHL)
    gCvarRespawnFix = get_cvar_pointer("mp_respawn_fix");

    hook_cvar_change(gCvarFpsCheckInterval, "CvarAgFpsCheckIntervalHook");
    hook_cvar_change(gCvarRespawnFix, "CvarAgRespawnFixHook");
}

public agmodx_post_config() {
    if (get_pcvar_num(gCvarCheckSoundFiles)) {
        // Sound file consistency
        for (new i; i < sizeof gConsistencySoundFiles; i++) {
            force_unmodified(force_exactfile, {0,0,0}, {0,0,0}, gConsistencySoundFiles[i]);
        }
    }
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_dictionary("agmodx_llhl.txt");

    register_forward(FM_StartFrame, "FwStartFrame");

    register_clcmd("say /unstuck", "CmdUnstuck");

    RegisterHam(Ham_Spawn, "player", "Ham_Player_Spawn_Pre", 0);
    RegisterHam(Ham_Spawn, "player", "Ham_Player_Spawn_Post", 1);
    RegisterHam(Ham_Killed, "player", "Ham_Player_Killed_Post", 1);
    RegisterHam(Ham_Use, "game_end", "Ham_Game_End");

    register_message(SVC_INTERMISSION, "FwMsgIntermission");

    register_forward(FM_CmdStart, "fmCmdStart_Pre");
    register_forward(FM_SetModel, "FwSetModel");
    register_forward(FM_ClientUserInfoChanged, "FwClientUserInfoChanged");

    // Add vote for mp_respawn_fix (Only in LLHL gamemode)
    ag_vote_add("mp_respawn_fix", "OnVoteRespawnFix");
}

public plugin_cfg() {
    set_task(get_pcvar_float(gCvarFpsCheckInterval), "taskMeasureMeanFPS", TASK_FPSLIMITER, .flags = "b");
    hook_cvar_change(get_cvar_pointer("sv_ag_match_running"), "CvarMatchRunningHook");
}

public inconsistent_file(id, const filename[], reason[64]) {
    new name[32], authid[32];
    get_user_name(id, name, charsmax(name));
    get_user_authid(id, authid, charsmax(authid));
    if (get_cvar_num("sv_ag_match_running")) {
        for (new i = 1; i <= MaxClients; i++) {
            if (!ag_is_player_inmatch(i)) {
                client_print(i, print_chat, "%l", "LLHL_FILECONSISTENCY_MSG", name, authid, filename);
            }
        }
    } else {
        client_print(0, print_chat, "%l", "LLHL_FILECONSISTENCY_MSG", name, authid, filename);
    }
    log_amx("%L", LANG_SERVER, "LLHL_FILECONSISTENCY_MSG", name, authid, filename);
    server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "LLHL_FILECONSISTENCY_KICK", filename);
    return PLUGIN_HANDLED;
}

public client_connect(id) {
    gIsAlive[id] = false;
    gMeanFPS[id] = gLastProbeFPS[id] = 0.0;
    gNumDetections[id] = 0;
}

public client_disconnected(id) {
    gIsAlive[id] = false;
}

public Ham_Player_Spawn_Pre(id) {
    gIsAlive[id] = false;
    return HAM_IGNORED;
}

public Ham_Player_Spawn_Post(id) {
    gIsAlive[id] = bool:is_user_alive(id);
    gProbeCount[id] = gProbeSum[id] = 0;
    return HAM_IGNORED;
}

public Ham_Player_Killed_Post(id) {
    gIsAlive[id] = false;
    return HAM_IGNORED;
}

// Create task before intermission because we can't run tasks when in intermission mode
public FwMsgIntermission() {
    gActualServerFPS = gServerFPS;
    client_cmd(0, "stop;wait;wait;+showscores");
    set_task(0.1, "taskShowVEngine", TASK_SHOWVENGINE);    
    message_begin(0, SVC_FINALE);
    write_string("");
    message_end();
    return PLUGIN_HANDLED;
}

public Ham_Game_End(id) {
    // Don't calculate player fps when map is finished
    remove_task(TASK_FPSLIMITER);
}

public FwStartFrame() {
    static Float:gametime, Float:framesPer = 0.0;
    static Float:tempFps;
    
    gametime = get_gametime();
    
    if(framesPer >= gametime) {
        tempFps += 1.0;
    } else {
        framesPer = framesPer + 1.0;
        gServerFPS = tempFps;
        tempFps = 0.0;
    }
}

public fmCmdStart_Pre(id, uc_handle) {
    if (__is_user_alive(id)) {
		static iMSec;
		iMSec = get_uc(uc_handle, UC_Msec);

		gProbeSum[id] += iMSec;
		gProbeCount[id]++;

		gLastProbeFPS[id] = precision_round(1 / (iMSec * 0.001), 0.1);
	}
    return PLUGIN_CONTINUE;
}

public taskMeasureMeanFPS() {
    static players[MAX_PLAYERS], pCount, id;
    get_players(players, pCount, "ch");
    
    for (new i = 0; i < pCount; i++) {
        id = players[i];
        if (gProbeCount[id] && !hl_get_user_spectator(id)) {
            gMeanFPS[id] = precision_round(1 / ((gProbeSum[id] * 0.001) / gProbeCount[id]), 0.1);
            gProbeCount[id] = gProbeSum[id] = 0;
            if ((gMeanFPS[id] >= get_pcvar_float(gCvarFpsMax) + get_pcvar_float(gCvarFpsMarginError))) {
                if (++gNumDetections[id] < get_pcvar_num(gCvarFpsMaxDetections)) {
                    console_cmd(id, "^"FpS_MaX^" %d", get_pcvar_num(gCvarFpsMax));
                    // For P47
                    console_cmd(id, "^"FpS_ModeM^" %d", get_pcvar_num(gCvarFpsMax));
                } else {
                    static name[MAX_NAME_LENGTH];
                    get_user_name(id, name, charsmax(name));
                    server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "LLHL_FPSL_KICK", get_pcvar_num(gCvarFpsMax));
                    log_amx("%L", LANG_SERVER, "LLHL_FPSL_KICK_MSG", name, get_pcvar_num(gCvarFpsMax));
                    client_print(0, print_chat, "%l", "LLHL_FPSL_KICK_MSG", name, get_pcvar_num(gCvarFpsMax));
                }
            }
        }
    }
}

public taskShowVEngine() {
    set_dhudmessage(0, 100, 200, -1.0, -0.125, 0, 0.0, 10.0, 0.2);
    show_dhudmessage(0, "LLHL Mode vEngine^n----------------------^nServer fps: %.1f^nFilecheck: %s", gActualServerFPS, get_pcvar_num(gCvarCheckSoundFiles) ? "On" : "Off");
}

// If I don't do this when pausing/unpausing the game, the fps will be miscalculated (High values) and false positives will occur
public agmodx_pause() {
    arrayset(gProbeCount, 0, sizeof(gProbeCount));
    arrayset(gProbeSum, 0, sizeof(gProbeSum));
}

public FwClientUserInfoChanged(id) {
    static const name[] = "name";
    static oldName[32], newName[32], cvar;
    pev(id, pev_netname, oldName, charsmax(oldName));
    if (oldName[0]) {
        get_user_info(id, name, newName, charsmax(newName));
        if (get_pcvar_num(gCvarBlockNameChangeInMatch) && !equal(oldName, newName) && (cvar || (cvar = get_cvar_pointer("sv_ag_match_running"))) && get_pcvar_num(cvar) && hl_get_user_spectator(id)) {
            set_user_info(id, name, oldName);
            client_print(id, print_chat, "%l", "LLHL_BLOCK_NAMECHANGE_MSG");
            return FMRES_HANDLED;
        }
    }
    return FMRES_IGNORED;
}

public CvarAgRespawnFixHook(pcvar, const old_value[], const new_value[]) {
	set_cvar_string("mp_respawn_fix", new_value);
}

public CvarAgFpsCheckIntervalHook(pcvar, const old_value[], const new_value[]) {
    remove_task(TASK_FPSLIMITER);
    set_task(get_pcvar_float(gCvarFpsCheckInterval), "taskMeasureMeanFPS", TASK_FPSLIMITER, .flags = "b");
}

public OnVoteRespawnFix(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		new num = str_to_num(arg2);
		if (equal(arg1, "mp_respawn_fix"))
			num = num > 0 ? 1 : 0;
		set_pcvar_num(gCvarRespawnFix, num);
	} else {
		if (!get_pcvar_num(gCvarAllowVoteSetting)) {
			console_print(id, "%l", "VOTE_NOTALLOWED");
			return false;
		}

		if (!is_str_num(arg2)) {
			console_print(id, "%l", "INVALID_NUMBER");
			return false;
		}
	}

	return true;
}

public CmdUnstuck(id) {
    new Float:cooldownTime = get_pcvar_float(gCvarUnstuckCooldown);
    new Float:elapsedTime = get_gametime() - gUnstuckLastUsed[id];

    if (elapsedTime < cooldownTime) {
        client_print(id, print_chat, "%l", "LLHL_UNSTUCK_ON_COOLDOWN", cooldownTime - elapsedTime);
        return PLUGIN_HANDLED;
    }

    gUnstuckLastUsed[id] = get_gametime();
    new value;
    if ((value = UnStuckPlayer(id)) != 1) {
        switch (value) {
            case 0: client_print(id, print_chat, "%l", "LLHL_UNSTUCK_FREESPOT_NOTFOUND");
            case -1: client_print(id, print_chat, "%l", "LLHL_UNSTUCK_PLAYER_DEAD");
        }
    }

    return PLUGIN_HANDLED;
}

UnStuckPlayer(const id) {
    if (!is_user_alive(id)) return -1;

    static Float:originalOrigin[3], Float:newOrigin[3];
    static attempts, distance;

    pev(id, pev_origin, originalOrigin);

    distance = get_pcvar_num(gCvarUnstuckStartDistance);

    while (distance < 1000) {
        attempts = get_pcvar_num(gCvarUnstuckMaxSearchAttempts);
        while (attempts--) {
            newOrigin[0] = random_float(originalOrigin[0] - distance, originalOrigin[0] + distance);
            newOrigin[1] = random_float(originalOrigin[1] - distance, originalOrigin[1] + distance);
            newOrigin[2] = random_float(originalOrigin[2] - distance, originalOrigin[2] + distance);

            engfunc(EngFunc_TraceHull, newOrigin, newOrigin, DONT_IGNORE_MONSTERS, GetPlayerHullSize(id), id, 0);

            if (get_tr2(0, TR_InOpen) && !get_tr2(0, TR_AllSolid) && !get_tr2(0, TR_StartSolid)) {
                engfunc(EngFunc_SetOrigin, id, newOrigin);
                return 1;
            }
        }
        distance += get_pcvar_num(gCvarUnstuckStartDistance);
    }

    return 0;
}

public agmodx_countdown_start() {
    remove_task(TASK_FPSLIMITER);
}

public agmodx_countdown_end() {
    set_task(get_pcvar_float(gCvarFpsCheckInterval), "taskMeasureMeanFPS", TASK_FPSLIMITER, .flags = "b");
}

public CvarMatchRunningHook(pcvar, const old_value[], const new_value[]) {
    new num = str_to_num(new_value);

    if (num == 0) {
        // Stop demo
        for (new id = 1; id <= MaxClients; id++) {
            if (!is_user_connected(id))
                continue;

            client_cmd(id, "stop");
        }
    } else if (num == 1) {
        new strDemo[128], mapname[32], formatted[32];
        new timestamp = get_systime();
        format_time(formatted, charsmax(formatted), "%d%m%Y_%H%M%S", timestamp);
        get_mapname(mapname, charsmax(mapname));
        formatex(strDemo, charsmax(strDemo), "[LLHL]_%s_%s", mapname, formatted);

        // Record demo
        for (new id = 1; id <= MaxClients; id++) {
            if (!is_user_connected(id))
                continue;

            if (!hl_get_user_spectator(id)) {
                client_cmd(id, "stop; record %s", strDemo);
                client_print(id, print_chat, "%l", "LLHL_DEMO_RECORDING", strDemo);
            }
        }
    }
}

public FwSetModel(entid, model[]) {
    if (!get_pcvar_num(gCvarDestroyableSatchel) || !pev_valid(entid) || !equal(model, "models/w_satchel.mdl"))
        return FMRES_IGNORED;

    static id;
    id = pev(entid, pev_owner);

    if (!id || !is_user_connected(id) || !is_user_alive(id))
        return FMRES_IGNORED;

    new Float:health = get_pcvar_float(gCvarDestroyableSatchelHP);
    set_pev(entid, pev_health, health);
    set_pev(entid, pev_takedamage, DAMAGE_YES);
    return FMRES_IGNORED;
}
