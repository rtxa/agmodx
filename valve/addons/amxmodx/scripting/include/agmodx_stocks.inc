#if defined _agmodx_stocks_included
	#endinput
#endif
#define _agmodx_stocks_included

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hlstocks>
#include <agmodx_const>

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

stock Float:GetServerUpTime() {
	return Float:engfunc(EngFunc_Time);
}

stock ResetMap() {
	ClearField();
	ClearCorpses();
	RespawnItems();
	ResetChargers();	
}

// this will clean entities like tripmines, satchels, etc...
stock ClearField() {
	static const fieldEnts[][] = { "bolt", "monster_snark", "monster_satchel", "monster_tripmine", "beam" };

	for (new i; i < sizeof fieldEnts; i++)
		remove_entity_name(fieldEnts[i]);

	new ent;
	while ((ent = find_ent_by_class(ent, "rpg_rocket")))
		set_pev(ent, pev_dmg, 0);

	ent = 0;
	while ((ent = find_ent_by_class(ent, "grenade")))
		set_pev(ent, pev_dmg, 0);
	
	ent = 0;
	while ((ent = find_ent_by_class(ent, "weaponbox"))) {
		hl_remove_wbox(ent);
	}
}

stock ClearCorpses() {
	new ent;
	while ((ent = find_ent_by_class(ent, "bodyque")))
		set_pev(ent, pev_effects, EF_NODRAW);
}

// This will respawn all weapons, ammo and items of the map to prepare for a new match (agstart)
stock RespawnItems() {
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

stock ResetChargers() {
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
				set_ent_data(i, "CWallHealth", "m_iJuice", get_skill_cvar_num("sk_healthcharger"));
			}
		}
	}
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
stock ag_get_team_numplayers(teamIndex, teamlistModels[][]) {
	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	new model[16], numTeam;
	for (new i; i < numPlayers; i++) {
		hl_get_user_model(players[i], model, charsmax(model));
		strtolower(model);
		if (equal(model, teamlistModels[teamIndex - 1])) 
			numTeam++; 
	}

	return numTeam;
}

// To do: use a native to check if ag mod x is on, or to check if normal ag mod is being use
stock bool:IsSelectedMode(const mode[]) {
	new type[32];
	get_cvar_string("sv_ag_gametype", type, charsmax(type));
	return equal(type, mode) ? true : false;
}

stock StopPlugin() {
	new pluginName[32];
	get_plugin(-1, pluginName, sizeof(pluginName));
	pause("d", pluginName);
	return;
}

stock PlayNumSound(id, second) {
	if (second >= 0 && second <= sizeof(gCountSnd))
		PlaySound(id, gCountSnd[second]);
}

stock PlaySound(id, const sound[]) {
	new snd[128];
	RemoveExtension(sound, snd, charsmax(snd), ".wav"); // // Remove .wav file extension (console starts to print "missing sound file _period.wav" for every sound)
	client_cmd(id, "spk %s", snd);
}

stock RemoveExtension(const input[], output[], length, const ext[]) {
	copy(output, length, input);

	new idx = strlen(input) - strlen(ext);
	if (idx < 0) return 0;
	
	return replace(output[idx], length, ext, "");
}

stock GetNumAlives() {
	new alives[32], numAlives;
	get_players(alives, numAlives, "a");
	return numAlives;
}

// Cache this in plugin_precache() or plugin_init() because the team code doesn't want to deal with changing this in the middle of a game
stock GetTeamListModels(output[][], size, &numTeams = 0) {
	new teamlist[512];
	get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));

	new nLen, teamname[HL_TEAMNAME_LENGTH];
	while (nLen < strlen(teamlist) && numTeams < HL_MAX_TEAMS)
	{
		strtok(teamlist[nLen], teamname, charsmax(teamname), "", 0, ';');
		nLen += strlen(teamname) + 1;
		if (GetTeamIndex(teamname, output, numTeams) < 0)
		{
			copy(output[numTeams], size, teamname);
			numTeams++;
		}
	}

	if (numTeams < 2)
		numTeams = 0;
}

stock GetTeamIndex(const teamname[], teamlist[][], numTeams){
	for (new i = 0; i < numTeams; i++)
		if (equali(teamlist[i], teamname))
			return i;
	return -1;
}

stock GetStrColor(const input[], &red, &green, &blue) {
	new r[4], g[4], b[4];

	parse(input, r, charsmax(r), g, charsmax(g), b, charsmax(b));

	red = str_to_num(r);
	green = str_to_num(g);
	blue = str_to_num(b);
}

stock ag_cmd_target(id, const arg[], argIdx = -1) {
	new player = ag_find_player(arg);

	// check if there is more player coincidences
	if (player != ag_find_player(arg, .lastMatched = true) && (player = find_player_ex(FindPlayer_MatchName, arg)) == 0) {
		if (argIdx >= 0)
			console_print(id, "%L (Arg %d: ^"%s^")", id, "MORE_CL_MATCHT", argIdx, arg);
		else
			console_print(id, "%L", id, "MORE_CL_MATCHT");
		return 0;
	}

	if (!player) {
		if (argIdx >= 0)
			console_print(id, "%L (Arg %d: ^"%s^")", id, "CL_NOT_FOUND", argIdx, arg);
		else
			console_print(id, "%L", id, "CL_NOT_FOUND");
		return 0;
	}

	return player;
}

stock ag_find_player(const arg[], lastMatched = false) {
	new FindPlayerFlags:flags = FindPlayer_MatchNameSubstring | FindPlayer_CaseInsensitive;

	if (lastMatched)
		flags |= FindPlayer_LastMatched;

	new player;

	// find by name substring first
	player = find_player_ex(flags, arg);
	
	if (player)
		return player;

	// try again but with color codes removed
	new name[MAX_NAME_LENGTH];
	for (new i = 1; i <= MaxClients; i++) {
		if (!is_user_connected(i))
			continue;

		get_user_name(i, name, charsmax(name));
		RemoveColorCodes(name, charsmax(name));

		if (strfind(name, arg, true) != -1) {
			player = i;
			if (!lastMatched) // return the first match
				return player;
		}
	}

	if (player)
		return player;

	// try to find by userid
	if (strlen(arg) >= 2 && arg[0] == '#' && arg[1])
		player = find_player_ex(FindPlayer_MatchUserId, str_to_num(arg[1]));
	
	return player;
}

stock RemoveColorCodes(input[], len) {
	new i;
	while (i < len) {
		if (i + 1 < len) {
			if (input[i] == '^^' && input[i+1] >= '0' && input[i+1] <= '9') {
				replace(input, len, fmt("^^%c", input[i+1]), "");
			} else {
				i++;
			}
		} else {
			break;
		}
	}
}

stock DisableVote(const name[], const callback[]) {
	ag_vote_remove(name);
	ag_vote_add(name, callback);
}

stock CountSpecs() {
	new numSpecs;
	// count specs
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i) && hl_get_user_spectator(i))
			numSpecs++;
	}
	return numSpecs;
}

stock get_skill_cvar_string(const name[], output[], len) {
	new skill = clamp(get_cvar_num("skill"), 1, 3);
	get_cvar_string(fmt("%s%d", name, skill), output, len);
}


stock get_skill_cvar_num(const name[]) {
	new value[32];
	get_skill_cvar_string(name, value, charsmax(value));
	return str_to_num(value);
}
