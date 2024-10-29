---
sidebar_position: 1
---

# Commands reference

Here you will find most of the commands used in the mod.

## Client commands

* <Badge type='new'/> `say settings` or `settings` — Show server settings.
* `help` — Lists all commands with their description into your console.
* `aglistvotes` — List available votes.
* `play_team <file.wav>` — Play .wav files to your teammates.
* `play_close <file.wav>` — Play .wav files to your teammates close to you.
* `say_close` — Only team mates close to you receive your message.
<details>
  <summary>`say` and `say_team` command enhancements:</summary>

  The chat allows you to use placeholder codes like `%H` or `%A` that will be replaced with your current health and armour.
  * `%H` — Health
  * `%A` — Armour
  * `%L` — Location
  * `%W` — Weapon
  * `%Q` — Ammo. If weapon is a MP5 and has M203 ammo, it would look like this: `Carrying MP5 with 50/255/10`
  * `%P` — Long jump status. Output: Yes/No
  * `%D` — Death location
  * `%S` — Score
  * `%F` — Flag status. Carrying: `I'm carrying <red> flag.` Not carrying: `I'm carrying <> flag`
</details>

* `dropitems` or `drop flag` — Drop flag in CTF mode.
* `ready/notready` — Set ready mode in Arena mode.
* <Badge type='planned'/> `timeout` — Call 1 minute timeout in matches. Useful when a players drops from the match. Only one for team.
* <Badge type='planned'/> `customtimer` — Shows countdown for the amount of seconds.
* <Badge type='planned'/> `variables` — Dump of server variable list.

## Vote and admin commands

### Match

* `agstart` — Start a match. If you're an admin, you can specify which players are going to play like this *agstart player1 player2 ... playerN*.
* `agallow [name or #userid]` — Allow a player into the match. If empty, you will allow yourself into the match.
* `agpause` — Pause server.
* `agnextmap <map>`  — Set next map.
* `agnextmode <mode>` — Set next mode.
* `agforcespectator <name or #userid>` — Force a player into spectator mode.
* `agforceteamup <name or #userid> <teamname or #teamid>` — Force a player into a team.
* `ag_spectalk <0-1>` — Allow spectators to talk to all.
* `ag_gauss_fix <0-2>` — 0: Self gauss enabled. 1: Self gauss partially disabled. 2: Self gauss fully disabled.
* `ag_rpg_fix <0-1>` — Avoids self-damage on rocket launch when moving at high speeds or closer to a wall.

### General

* <Badge type='new'/> `mp_falldamage`— Enable fall damage for players.
* <Badge type='new'/> `mp_bunnyhop <0-1>`— Enable bunny hop technique to gain additional speed.
* <Badge type='new'/> `mp_footsteps`— Enable sound of player's footsteps.
* <Badge type='new'/> `mp_forcerespawn`— Enforce respawn of players after 5 seconds. 
* <Badge type='new'/> `mp_flashlight`— Enable player flashlight.
* <Badge type='new'/> `mp_selfgauss <0-2>` — 0: Self gauss partially disabled. 1: Self gauss enabled. 2: Self gauss fully disabled.
* `mp_timelimit` — Sets the time limit for the current map, in minutes.
* `mp_friendlyfire` — Prevents players from damaging their teammates.
* `mp_weaponstay` — Weapons don't disappear from the floor when picked up.
* `mp_fraglimit` — Sets the frag limit for the current map.
* `sv_maxspeed` — Sets the maximum movement speed for players.
* <Badge type='deprecated'/> `agadmin` — Dropped in favour of AMXX admin system.

:::note
All game modes (TDM, Arena, etc.) are already included in the vote list.
:::

## Server variables

* <Badge type='new'/> `sv_ag_hud_color "230 230 0"` — Changes the color of AG Hud.
* `sv_ag_allowed_gamemodes "ffa;tdm;arena;arcade"` — Set allowed game modes.
* `sv_ag_max_spectators 32` — Max spectators allowed.
* `sv_ag_start_minplayers 2` — Minimum players required to allow to start a match.
* `ag_spectalk <0|1>` — Allow spectators to talk to all.
* <Badge type='planned'/> `sv_ag_show_gibs 1` — Show dead bodies.
* <Badge type='planned'/> `sv_ag_spawn_volume 0.5` — Respawn sound volume.
* <Badge type='planned'/> `sv_ag_allow_timeout 1` — Allow players to call time out when playing a match.
* <Badge type='planned'/> `sv_ag_spec_enable_disable 0` — Allow players to disable tracking in spectator. Requires to use *setinfo cl_disablespecs 1*.
* <Badge type='deprecated'/> `ag_spec_team_only 0` — Limit spectators to their team only. Never implemented in original mod.
* <Badge type='deprecated'/> `sv_ag_pure 1` — 0: Checks for player models consistency, variables and wallhack. 1: Adds checks for weapon models.

### Vote

* <Badge type='new'/> `sv_ag_vote_oldstyle 0` — Sets the style of the vote. Old text style or the new HUD style.
* <Badge type='new'/> `sv_ag_vote_duration 30` — Duration of vote in seconds.
* <Badge type='new'/> `sv_ag_disabled_votes` — Set what votes are disabled. For example: `sv_ag_disabled_votes "agstart;agabort"` will disable `agstart` and `agabort`.
* <Badge type='new'/> `sv_ag_vote_allow_bots 0` — Allow bots to vote. Debug purposes only.
* `sv_ag_allow_vote 1` — Allow vote.
* `sv_ag_vote_setting 1` — Allow vote `ag_xxx` and `mp_xxx` settings.
* `sv_ag_vote_gamemode 1` — Allow vote of game modes.
* `sv_ag_vote_kick 0` — Allow vote kick.
* `sv_ag_vote_map 1` — Allow vote map.
* `sv_ag_vote_start 1` — Allow vote agstart.
* `sv_ag_vote_allow 1` — Allow vote agallow.
* `sv_ag_vote_failed_time 15` — Cooldown for next vote if previous one failed.
* <Badge type='deprecated'/> `sv_ag_vote_admin 0` — Allow vote for player admin. Dropped in favour of AMXX admin system.

**Multiplayer**

* `sv_ag_vote_mp_timelimit_low 10` — Lowest time limit to vote on.
* `sv_ag_vote_mp_timelimit_high 1440` — Highest time limit to vote on.
* `sv_ag_vote_mp_fraglimit_low 0` — Lowest frag limit to vote on.
* `sv_ag_vote_mp_fraglimit_high 999` — Highest frag limit to vote on.

