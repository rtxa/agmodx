/*
    LLHL Gamemode for AG Mod X

    # New cvars:
    - sv_ag_unstuck_cooldown "10.0"
    - sv_ag_check_soundfiles "1"
    - sv_ag_destroyable_satchel "1"
    - sv_ag_destroyable_satchel_hp "1"
    - sv_ag_block_namechange_inmatch "1"

    # New vote:
    - ag_respawn_fix "0/1"
*/

#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <agmodx>
#include <agmodx_stocks>

#define PLUGIN      "AG Mod X LLHL"
#define VERSION     "Beta 2.4"
#define AUTHOR      "FlyingCat & Th3-822"

#pragma semicolon 1

#define MODE_TYPE_NAME "llhl"

#define GetPlayerHullSize(%1)  ((pev(%1, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN)

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

    gCvarRespawnFix = get_cvar_pointer("mp_respawn_fix");

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

    register_dictionary("agmodxllhl.txt");

    register_clcmd("say /unstuck", "CmdUnstuck");
    register_forward(FM_SetModel, "FwSetModel");
    register_forward(FM_ClientUserInfoChanged, "FwClientUserInfoChanged");

    // Add vote for mp_respawn_fix (Only in LLHL gamemode)
    ag_vote_add("ag_respawn_fix", "OnVoteRespawnFix");
}

public plugin_cfg() {
    hook_cvar_change(get_cvar_pointer("sv_ag_match_running"), "CvarMatchRunningHook");
}

public inconsistent_file(id, const filename[], reason[64]) {
    new name[32], authid[32];
    get_user_name(id, name, charsmax(name));
    get_user_authid(id, authid, charsmax(authid));
    client_print(0, print_chat, "%L", LANG_PLAYER, "LLHL_FILECONSISTENCY_MSG", name, authid, filename);
    server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "LLHL_FILECONSISTENCY_KICK", filename);
    return PLUGIN_HANDLED;
}

public FwClientUserInfoChanged(id) {
    static const name[] = "name";
    static oldName[32], newName[32], cvar;
    pev(id, pev_netname, oldName, charsmax(oldName));
    if (oldName[0]) {
        get_user_info(id, name, newName, charsmax(newName));
        if (get_pcvar_num(gCvarBlockNameChangeInMatch) && !equal(oldName, newName) && (cvar || (cvar = get_cvar_pointer("sv_ag_match_running"))) && get_pcvar_num(cvar) && hl_get_user_spectator(id)) {
            set_user_info(id, name, oldName);
            client_print(id, print_chat, "%L", LANG_PLAYER, "LLHL_BLOCK_NAMECHANGE_MSG");
            return FMRES_HANDLED;
        }
    }
    return FMRES_IGNORED;
}

public CvarAgRespawnFixHook(pcvar, const old_value[], const new_value[]) {
	set_cvar_string("mp_respawn_fix", new_value);
}

public OnVoteRespawnFix(id, check, argc, arg1[], arg2[]) {
	if (argc != 2) {
		console_print(id, "%l", "VOTE_INVALID");
		return false;
	}

	if (!check) {
		new num = str_to_num(arg2);
		if (equal(arg1, "ag_respawn_fix"))
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
        client_print(id, print_chat, "%L", id, "LLHL_UNSTUCK_ON_COOLDOWN", cooldownTime - elapsedTime);
        return PLUGIN_HANDLED;
    }
    gUnstuckLastUsed[id] = get_gametime();
    new value;
    if ((value = UnStuckPlayer(id)) != 1) {
        switch (value) {
            case 0: client_print(id, print_chat, "%L", LANG_PLAYER, "LLHL_UNSTUCK_FREESPOT_NOTFOUND");
            case -1: client_print(id, print_chat, "%L", LANG_PLAYER, "LLHL_UNSTUCK_PLAYER_DEAD");
        }
    }
    return PLUGIN_CONTINUE;
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
