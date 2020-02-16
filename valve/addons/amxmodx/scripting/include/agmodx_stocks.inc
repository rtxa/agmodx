#if defined _agmodx_stocks_included
	#endinput
#endif
#define _agmodx_stocks_included

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hlstocks>

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

stock GetTeamListModels(output[][], size) {
	new teamlist[192];
	get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));

	new nIdx, nLen = (1 + copyc(output[nIdx], size, teamlist, ';'));

	while (nLen < strlen(teamlist) && ++nIdx < HL_MAX_TEAMS)
		nLen += (1 + copyc(output[nIdx], size, teamlist[nLen], ';'));
}

// when user spectates, his teams is 0, so you have to check his model..
stock ag_get_team_numplayers(teamIndex, teamlistModels[][]) {
	new players[MAX_PLAYERS], numPlayers;
	get_players(players, numPlayers);

	new model[16], numTeam;
	for (new i; i < numPlayers; i++) {
		hl_get_user_model(players[i], model, charsmax(model));
		// ignore case, sometimes a player set his model to barNey...
		if (equali(model, teamlistModels[teamIndex - 1])) 
			numTeam++; 
	}

	return numTeam;
}

