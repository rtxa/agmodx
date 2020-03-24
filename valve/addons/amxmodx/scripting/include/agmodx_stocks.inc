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

stock ResetMap() {
	ClearField();
	ClearCorpses();
	RespawnItems();
	ResetChargers();	
}

// this will clean entities like tripmines, satchels, etc...
stock ClearField() {
	static const fieldEnts[][] = { "bolt", "monster_snark", "monster_satchel", "monster_tripmine", "beam", "weaponbox" };

	for (new i; i < sizeof fieldEnts; i++)
		remove_entity_name(fieldEnts[i]);

	new ent;
	while ((ent = find_ent_by_class(ent, "rpg_rocket")))
		set_pev(ent, pev_dmg, 0);

	ent = 0;
	while ((ent = find_ent_by_class(ent, "grenade")))
		set_pev(ent, pev_dmg, 0);
}

stock ClearCorpses() {
	new ent;
	while ((ent = find_ent_by_class(ent, "bodyque")))
		entity_set_origin(ent, Float:{4096.0, 4096.0, 4096.0});
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
				set_ent_data(i, "CWallHealth", "m_iJuice", 75);
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

// If user has the weapon (HLW enum from hlsdk_const.inc), return the weapon entity index.
stock GetUserWeaponEntId(id, weapon) {
	new classname[32];
	get_weaponname(weapon, classname, charsmax(classname));
	return find_ent_by_owner(0, classname, id);
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
