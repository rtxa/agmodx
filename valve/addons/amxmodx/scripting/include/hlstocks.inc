/*
* AMX mod X functions for Half-Life
*
* Supported AMX Mod X versions: 1.9 or newer
*
* Version 1.2 (date: 02.10.2013) Author: Kord
* Version 1.3 (date: 22.12.2018) Author: rtxa
*  - Now offsets are retrieved from gamedata instead of hardcoding them inside plugin (now AMXX 1.9 is required).
*  - Now Spectator message is sended in hl_set_user_spectator(). Some clients depends on this to show spectators in scoreboard.
*  - Added HL_MAX_TEAMNAME_LENGTH constant.
*  - Added hl_[g|s]et_user_frags().
* Version 1.4 (date: 14.03.2019) Author: rtxa
* - Renamed hl.inc to hlstocks.inc to distinguish it from the original.
* - Renamed HL_MAX_TEAMNAME_LENGTH to HL_TEAMNAME_LENGTH.
* - Fixed score of players not being updated correctly when using hl_set_user_frags() or hl_set_user_deaths()
*   by using MSG_ALL instead of MSG_BROADCAST.
* - Now hl_set_user_team() doesn't remove you from spectator to set your team.
* - Fixed hl_set_user_team(), now it doesn't kill the player anymore on model's change.
* - Fixed hl_set_user_frags() wrong value by converting frags to float
* Version 1.5 (date: 15.03.2019) Author: rtxa
* - Added hl_set_user_score(), this will send one message instead of two when you need to set both frags and deaths.
* Version 1.6 (date: 03.03.2020) Author: rtxa
* - Get back HL_MAX_TEAMNAME_LENGTH to keep backward compatibility
* - Fixed typos in some functions.
* Version 1.7 (date: 10.04.2020)
* - Fixed typo in hl_set_user_score()
* Version 1.8 (date: 06.05.2020)
* - Added hl_user_has_weapon()
* - Added new constant: HL_MAX_WEAPON_SLOTS
* Version 1.9 (date: 12.05.2020)
* - Added hl_strip_user_weapon() (Thanks XxAvalanchexX)
* Version 2.0 (date: 23.06.2020)
* - Fixed hl_set_user_score(), hl_set_user_frags() and hl_set_user_deaths() glitch in scoreboard when player is in spectator.
* Version 2.1 (date: 26.06.2020)
* - Added hl_set_user_teamnames() and hl_set_user_teamscore().
* Version 2.2 (date: 04/07/2020)
* - Added hl_remove_wbox().
* - Code clean up has been done.
* Version 2.3 (date: 06/07/2020)
* - Improved code for processing team list. Now is more safe and works the same as the GameDLL.
* - Fixed hl_set_user_team() not returning 0 when team is invalid.
* - Added new constant HL_MAX_TEAMLIST_LENGTH
* Version 2.4 (date: 08/07/2020)
* - Fixed typos in hl_remove_wbox()
* http://aghl.ru/forum/ - Russian Half-Life and Adrenaline Gamer Community
*
*/

#if defined _hlstocks_included
	#endinput
#endif
#define _hlstocks_included

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

// Server supports up to 32 teams, but client's scoreboard is hardcoded up to 10.
#define HL_MAX_TEAMS			10
#define HL_TEAMNAME_LENGTH 		16
#define HL_MAX_TEAMNAME_LENGTH  16
#define HL_MAX_WEAPON_SLOTS		6
#define HL_MAX_TEAMLIST_LENGTH  512

stock static teams[HL_MAX_TEAMS][HL_MAX_TEAMNAME_LENGTH];

static const _HLW_to_rgAmmoIdx[] =
{
	0, 	// none
	0,	// crowbar
	2, 	// 9mmhandgun
	4, 	// 357
	2, 	// 9mmAR
	3, 	// m203
	7, 	// crossbow
	1, 	// shotgun
	6, 	// rpg
	5, 	// gauss
	5, 	// egon
	12,	// hornetgun
	10, // handgrenade
	8, 	// tripmine
	9, 	// satchel
	11  // snark
};

/* Returns player frags.
*/
stock hl_get_user_frags(id)
{
	return pev(id, pev_frags);
}

/* Sets player frags.
*/
stock hl_set_user_frags(id, frags)
{
	static ScoreInfo;

	if (!ScoreInfo)
		ScoreInfo = get_user_msgid("ScoreInfo");

	set_pev(id, pev_frags, float(frags));

	message_begin(MSG_ALL, ScoreInfo);
	write_byte(id);
	write_short(frags);
	write_short(hl_get_user_deaths(id));
	write_short(0);
	write_short(__get_user_team(id));
	message_end();
}

/* Returns player deaths.
*/
stock hl_get_user_deaths(client)
{
	return get_ent_data(client, "CBasePlayer", "m_iDeaths");
}

/* Sets player deaths.
*/
stock hl_set_user_deaths(client, deaths)
{
	set_ent_data(client, "CBasePlayer", "m_iDeaths", deaths);

	static ScoreInfo;
	if (ScoreInfo || (ScoreInfo = get_user_msgid("ScoreInfo")))
	{
		message_begin(MSG_ALL, ScoreInfo);
		write_byte(client);
		write_short(get_user_frags(client));
		write_short(deaths);
		write_short(0);
		write_short(__get_user_team(client));
		message_end();
	}
}

/* Sets player score.
*/
stock hl_set_user_score(client, frags, deaths)
{
	set_pev(client, pev_frags, float(frags));
	set_ent_data(client, "CBasePlayer", "m_iDeaths", deaths);

	static ScoreInfo;
	if (ScoreInfo || (ScoreInfo = get_user_msgid("ScoreInfo")))
	{
		message_begin(MSG_ALL, ScoreInfo);
		write_byte(client);
		write_short(frags);
		write_short(deaths);
		write_short(0);
		write_short(__get_user_team(client));
		message_end();
	}
}


/* Get amount of ammo in backpack on a user for a specific weapon.
* Look in hlsdk_const.inc for weapon types: HLW_*.
* Weapons on the same line uses the same ammo type:
* shotgun
* mp5, glock
* argrenade
* python
* gauss, egon
* rpg
* crossbow
* tripmine
* satchel
* handgrenade
* snark
* hornet
*/
stock hl_get_user_bpammo(client, weapon)
{
	return get_ent_data(client, "CBasePlayer", "m_rgAmmo", _HLW_to_rgAmmoIdx[weapon]);
}

/* Restock/remove ammo in a user's backpack.
*/
stock hl_set_user_bpammo(client, weapon, ammo)
{
	if (weapon <= HLW_CROWBAR)
		return;

	set_ent_data(client, "CBasePlayer", "m_rgAmmo", ammo, _HLW_to_rgAmmoIdx[weapon]);
}

/* Get user model.
*/
stock hl_get_user_model(client, model[], len)
{
	get_user_info(client, "model", model, len);
}

/* Set user model.
*/
stock hl_set_user_model(client, const model[])
{
	set_user_info(client, "model", model);
}

/* Returns health value.
*/
stock hl_get_user_health(client)
{
	static Float:healthvalue;
	pev(client, pev_health, healthvalue);
	return floatround(healthvalue);
}

/* Sets player health.
*/
stock hl_set_user_health(client, health)
{
	health > 0 ? set_pev(client, pev_health, float(health)) : dllfunc(DLLFunc_ClientKill, client);

	return 1;
}

/* Returns armor value.
*/
stock hl_get_user_armor(client)
{
	static Float:armorvalue;
	pev(client, pev_armorvalue, armorvalue);
	return floatround(armorvalue);
}

/* Sets player armor.
*/
stock hl_set_user_armor(client, armorvalue)
{
	set_pev(client, pev_armorvalue, float(armorvalue));
}

/* Returns team id. When length is greater then 0 then a name of team is set.
*/
stock hl_get_user_team(client, team[] = "", len = 0)
{
	if (hl_get_user_spectator(client))
		return 0;

	static Float:tdm;
	global_get(glb_teamplay, tdm);
	if (tdm < 1.0) return 0;

	if (!len) len = HL_MAX_TEAMNAME_LENGTH;
	hl_get_user_model(client, team, len);

	return __get_team_index(team);
}

/* Set player team by teamname.
*/
stock hl_set_user_team(client, const team[])
{
	static Float:tdm;
	global_get(glb_teamplay, tdm);
	if (tdm < 1.0) return 0;

	static teamid;
	teamid = __get_team_index(team);
	if (!teamid) return 0;

	set_ent_data_string(client, "CBasePlayer", "m_szTeamName", team);
	engfunc(EngFunc_SetClientKeyValue, client, engfunc(EngFunc_GetInfoKeyBuffer, client), "model", team);
	engfunc(EngFunc_SetClientKeyValue, client, engfunc(EngFunc_GetInfoKeyBuffer, client), "team", team);

	static TeamInfo;
	if (TeamInfo || (TeamInfo = get_user_msgid("TeamInfo")))
	{
		message_begin(MSG_ALL, TeamInfo);
		write_byte(client);
		write_string(pev(client, pev_iuser1) ? "" : team);
		message_end();
	}

	static ScoreInfo;
	if (ScoreInfo || (ScoreInfo = get_user_msgid("ScoreInfo")))
	{
		message_begin(MSG_ALL, ScoreInfo);
		write_byte(client);
		write_short(get_user_frags(client));
		write_short(hl_get_user_deaths(client));
		write_short(0);
		write_short(teamid);
		message_end();
	}

	return 1;
}

// ignores if player is in spec or not
stock __get_user_team(client, team[] = "", len = 0) {
	static Float:tdm;
	global_get(glb_teamplay, tdm);
	if (tdm < 1.0) return 0;

	if (!len) len = HL_MAX_TEAMNAME_LENGTH;
	hl_get_user_model(client, team, len);

	return __get_team_index(team);
}

stock __get_team_index(const team[])
{
	static teamid;
	teamid = 0;
	static valid;
	valid = 0;
	static i;
	i = 0;

	__count_teams();

	for (i = 0; i < sizeof(teams); i++)
	{
		teamid++;
		if (equali(teams[i][0], team))
		{
			valid = 1;
			break;
		}
	}

	if (valid)
		return teamid;

	return 0;
}

stock __count_teams()
{
	if (!teams[0][0])
	{
		new teamlist[HL_MAX_TEAMLIST_LENGTH];
		get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));
		__explode_teamlist(teams, charsmax(teams[]), teamlist, ';');
	}

	static teamcount;

	if (!teamcount)
	{
		for (new i = 0; i < sizeof(teams); i++)
		{
			if (teams[i][0])
				teamcount++;
		}
	}

	return teamcount;
}

stock __explode_teamlist(output[][], size, input[], delimiter)
{
	new nLen, teamname[HL_MAX_TEAMLIST_LENGTH], numTeams;
	while (nLen < strlen(input) && numTeams < HL_MAX_TEAMS)
	{
		strtok(input[nLen], teamname, charsmax(teamname), "", 0, delimiter);
		nLen += strlen(teamname) + 1;
		if (__get_team_index__(teamname, output, numTeams) < 0)
		{
			copy(output[numTeams], size, teamname);
			numTeams++;
		}
	}
}

stock __get_team_index__(const teamname[], team_names[][], numTeams)
{
	for (new i = 0; i < numTeams; i++)
		if (equali(team_names[i], teamname))
			return i;
	return -1;
}

/* Checks if user has that weapon (weapon id is from the HLW enum in hlsdk_const.inc)
*  Returns the weapon entity index or 0 if weapon wasn't found.
*/
stock hl_user_has_weapon(id, weapon_id)
{
	new ent;
	for (new i = 1; i < HL_MAX_WEAPON_SLOTS; i++)
	{
		ent = get_ent_data_entity(id, "CBasePlayer", "m_rgpPlayerItems", i);
		while (ent != FM_NULLENT) 
		{
			if (hl_get_weapon_id(ent) == weapon_id)
				return ent;
			ent = get_ent_data_entity(ent, "CBasePlayerItem", "m_pNext");
		}
	}

	return 0;
}

/* Returns entity index of active weapon.
*/
stock hl_get_user_weapon_ent(client)
{
	return get_ent_data_entity(client, "CBasePlayer", "m_pActiveItem");
}

/* Returns amount of ammo in weapon's clip.
*/
stock hl_get_weapon_ammo(entity)
{
	return get_ent_data(entity, "CBasePlayerWeapon", "m_iClip");
}

/* Set amount of ammo in weapon's clip.
*/
stock hl_set_weapon_ammo(entity, clip)
{
	set_ent_data(entity, "CBasePlayerWeapon", "m_iClip", clip);
}

/* Get weapon type. Corresponds to HLW_* in hlsdk_const.inc: 1 is HLW_CROWBAR, 2 is HLW_GLOCK and so on...
*/
stock hl_get_weapon_id(entity)
{
	return get_ent_data(entity, "CBasePlayerItem", "m_iId");
}

/* Returns weapon entity index from weaponbox.
*/
stock hl_get_wbox_weapon_ent(entity)
{
	static wpn_entity;
	for (new i = 1; i < HL_MAX_WEAPON_SLOTS; i++)
	{
		wpn_entity = get_ent_data_entity(entity, "CWeaponBox", "m_rgpPlayerItems", i);
		if (wpn_entity > 0)
		{
			break;
		}
	}

	return wpn_entity;
}

/* Returns amount of ammo in weaponbox.
*/
stock hl_get_wbox_ammo(entity)
{
	return get_ent_data(entity, "CWeaponBox", "m_rgAmmo", 1);
}

/* Set amount of ammo in weaponbox.
*/
stock hl_set_wbox_ammo(entity, ammo)
{
	set_ent_data(entity, "CWeaponBox", "m_rgAmmo", ammo, 1);
}

/* Removes weapon box with proper handling of all entities inside.
*/
stock hl_remove_wbox(entity)
{
	new pWeapon;
	
	// destroy the weapons inside the box
	for (new i = 0 ; i < HL_MAX_WEAPON_SLOTS; i++) {
		pWeapon = get_ent_data_entity(entity, "CWeaponBox", "m_rgpPlayerItems", i);
		while (pWeapon != FM_NULLENT) {
			set_pev(pWeapon, pev_flags, FL_KILLME);
			pWeapon = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pNext");
		}
	}
	
	// remove the box
	set_pev(entity, pev_flags, FL_KILLME);
}

/* Spawns a Half-Life player.
*/
stock hl_user_spawn(client)
{
	if (!hl_strip_user_weapons(client))
		return;

	set_pev(client, pev_deadflag, DEAD_RESPAWNABLE);
	dllfunc(DLLFunc_Spawn, client);
}

/* Strip a weapon from player
*/
stock hl_strip_user_weapon(id, weapon_id)
{    
	new weapon_ent = hl_user_has_weapon(id, weapon_id);

	if (!weapon_ent) 
		return 0;

	// make sure to retire the weapon before removing it
	if (get_user_weapon(id) == weapon_id)
		ExecuteHamB(Ham_Weapon_RetireWeapon, weapon_ent);

	if (!ExecuteHamB(Ham_RemovePlayerItem, id, weapon_ent))
		return 0;

	ExecuteHamB(Ham_Item_Kill, weapon_ent);

	set_pev(id, pev_weapons, pev(id, pev_weapons) & ~(1 << weapon_id));

	return 1;
}

/* Strips all weapons from player.
*/
stock hl_strip_user_weapons(client)
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "player_weaponstrip"));
	if (!pev_valid(ent))
		return 0;

	dllfunc(DLLFunc_Spawn, ent);
	dllfunc(DLLFunc_Use, ent, client);
	engfunc(EngFunc_RemoveEntity, ent);

	return 1;
}

/* Check if player in spectator mode.
*/
stock bool:hl_get_user_spectator(client)
{
	if (pev(client, pev_iuser1) || pev(client, pev_iuser2))
		return true;

	return false;
}

/* Switch player to spectator mode.
*/
stock hl_set_user_spectator(client, bool:spectator = true)
{
	if (hl_get_user_spectator(client) == spectator)
		return;

	if (spectator)
	{
		static AllowSpectatorsCvar;
		if (AllowSpectatorsCvar || (AllowSpectatorsCvar = get_cvar_pointer("allow_spectators")))
		{
			if (!get_pcvar_num(AllowSpectatorsCvar))
				set_pcvar_num(AllowSpectatorsCvar, 1);

			engclient_cmd(client, "spectate");
		}
	}
	else
	{
		hl_user_spawn(client);

		set_pev(client, pev_iuser1, 0);
		set_pev(client, pev_iuser2, 0);

		set_ent_data(client, "CBasePlayer", "m_iHideHUD", 0);

		static szTeam[HL_MAX_TEAMNAME_LENGTH];
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
		if (TeamInfo || (TeamInfo = get_user_msgid("TeamInfo")))
		{
			message_begin(MSG_ALL, TeamInfo);
			write_byte(client);
			write_string(szTeam);
			message_end();
		}
	}
}

/* Check if player have longjump module.
*/
stock bool:hl_get_user_longjump(client)
{
	new value[2];
	engfunc(EngFunc_GetPhysicsKeyValue, client, "slj", value, charsmax(value));
	return value[0] == '1' ? true : false;
}

/* Set longjump module to player.
*/
stock hl_set_user_longjump(client, bool:longjump = true, bool:tempicon = true)
{
	if (longjump == hl_get_user_longjump(client))
		return;

	if (longjump)
	{
		engfunc(EngFunc_SetPhysicsKeyValue, client, "slj", "1");

		if (tempicon)
		{
			static msgid_itempickup;
			if (!msgid_itempickup)
				msgid_itempickup = get_user_msgid("ItemPickup");

			message_begin(MSG_ONE, msgid_itempickup, _, client);
			write_string("item_longjump");
			message_end();
		}
	}
	else
		engfunc(EngFunc_SetPhysicsKeyValue, client, "slj", "0");

	set_ent_data(client, "CBasePlayer", "m_fLongJump", longjump);
}

/* Set team names in player scoreboard. Use 0 for all clients.
*  Example: hl_set_user_teamnames(id, "Blue", "Red");
*/
stock hl_set_user_teamnames(id, any:...) {
	new teamnames[HL_MAX_TEAMS][HL_TEAMNAME_LENGTH];
	new numTeams = clamp(numargs() - 1, 0, HL_MAX_TEAMS);

	for (new i; i < numTeams; i++)
		format_args(teamnames[i], charsmax(teamnames[]), i + 1);

	static MSG_TeamNames;

	if (!MSG_TeamNames)
		MSG_TeamNames = get_user_msgid("TeamNames");

	message_begin(id ? MSG_ONE : MSG_ALL, MSG_TeamNames, .player = id);
	write_byte(numTeams);
	for (new i; i < numTeams; i++)
		write_string(teamnames[i]);
	message_end();
}

/* Set team score in player scoreboard. This will override the combined player scores.
*  Use 0 for all clients.
*  Warning: Team score gets switched when player changes his team. Send another message to keep this updated.
*/
stock hl_set_user_teamscore(id, const teamname[], frags, deaths = 0) {
	static MSG_TeamScore;

	if (!MSG_TeamScore)
		MSG_TeamScore = get_user_msgid("TeamScore");

	message_begin(id ? MSG_ONE : MSG_ALL, MSG_TeamScore, .player = id);
	write_string(teamname);
	write_short(frags);
	write_short(deaths);
	message_end();
}
