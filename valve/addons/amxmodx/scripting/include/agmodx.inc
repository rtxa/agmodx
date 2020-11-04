#if defined _agmodx_included
	#endinput
#endif
#define _agmodx_included

/**
 * Add vote to AG Mod X Voting System
 *
 * @note The size of both arguments is 32 and you can modify them.
 *
 * @note The callback can be called more than once, first time is for validation
 *       check and second time, only if vote is accepted, where you can do vote actions.
 *
 * @note The callback will be called in the following manner:
 *
 * public OnVoteCallBack(id, check, argc, arg1[], arg2[])
 *
 *   id            - Client index
 *   check         - True if is in validation check, false otherwise
 *   argc          - Number of arguments 
 *   arg1[]        - Contains vote name
 *   arg2[]        - Contains vote argument
 *
 * Return true if vote is correct, false otherwise
 *
 * @param name      Vote name
 * @param callback  Name of callback function
 *
 * @return          True if it was created, false otherwise
 */
native bool:ag_vote_add(const name[], const callback[]);

native bool:ag_vote_remove(const name[]);

native bool:ag_vote_exists(const name[]);

/* 
 * Checks if a player is playing a match
 * 
 * @note         That the player is not playing a match doesn't imply that there's a match in progress.
 *               Be sure to check first cvar 'sv_ag_match_running' before using this native.
 *
 * @param        id - Player slot (1-32)
 * 
 * @return       Returns true if the player is in the match, false if the 
 *               there's no match in progress or he isn't in the match.
 * 
 */
native bool:ag_is_player_inmatch(id);
