---
sidebar_position: 1
---

# Commands reference

Here you will find most of the commands used in the mod.

## Client commands

### General

* ✨ **New!** `say settings` or `settings` — Show server settings.
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
* 🚧 *Not Implemented* `customtimer` (seconds) — Shows countdown for the amount of seconds.
* 🚧 *Not Implemented* `variables` — Dump of server variable list.
* 🚧 *Not Implemented* `timeout` — Call 1 minute timeout in matches. Useful when a players drops from the match. Only one for team.

### Match commands

* `agstart` — Start a match.
* `agallow [name or #userid]` — Allow a player into the match. If empty, you allow yourself to enter the match.
* `agpause` — Pause server.
* `agnextmap <map>`  — Set next map.
* `agnextmode <mode>` — Set next mode.
* `agforcespectator <name or #userid>` — Force a player into spectator mode.
* `agforceteamup <name or #userid> <teamname or #teamid>` — Force a player into a team.

### Vote commands

* `ag_spectalk <0-1>` — Allow spectators to talk to all.
* `ag_gauss_fix <0-2>` — 0: Self gauss enabled. 1: Self gauss partially disabled. 2: Self gauss fully disabled.
* `ag_rpg_fix <0-1>` — Avoids self-damage on rocket launch when moving at high speeds or closer to a wall.
* ✨ **New!** `mp_falldamage`— Enable fall damage for players.
* ✨ **New!** `mp_bunnyhop <0-1>`— Enable bunny hop technique to gain additional speed.
* ✨ **New!** `mp_footsteps`— Enable sound of player's footsteps.
* ✨ **New!** `mp_forcerespawn`— Enforce respawn of players after 5 seconds. 
* ✨ **New!** `mp_flashlight`— Enable player flashlight.
* ✨ **New!** `mp_selfgauss <0-2>` — 0: Self gauss partially disabled. 1: Self gauss enabled. 2: Self gauss fully disabled.
* `mp_timelimit` — Sets the time limit for the current map, in minutes.
* `mp_friendlyfire` — Prevents players from damaging their teammates.
* `mp_weaponstay` — Weapons don't disappear from the floor when picked up.
* `mp_fraglimit` — Sets the frag limit for the current map.
* `sv_maxspeed` — Sets the maximum movement speed for players.
* ⛔ *Deprecated* `agadmin` — Dropped in favour of AMXX admin system.

:::note
All game modes (TDM, Arena, etc.) and match commands (agstart, agallow, etc.) are already included in the vote list.
:::

## Server variables

### General

* ✨ **New!** `sv_ag_hud_color "230 230 0"` — Changes the color of AG Hud.
* `sv_ag_allowed_gamemodes "ffa;tdm;arena;arcade"` — The allowed gamemodes. Set this in startup_server.cfg.
* `sv_ag_max_spectators 32` — Max spectators allowed.
* `sv_ag_start_minplayers 2` — Minimum amount of players to allow match with agstart command.
* `ag_spectalk <0|1>` — Allow spectators to talk to all.
* 🚧 *Not Implemented* `sv_ag_show_gibs 1` — Show dead bodies.
* 🚧 *Not Implemented* `sv_ag_spawn_volume 0.5` — Respawn sound volume.
* 🚧 *Not Implemented* `sv_ag_allow_timeout 1` — Allow players calling timeout when playing a match.
* 🚧 *Not Implemented* `ag_spec_team_only 0` — Limit spectators to their team only.
* ⛔ *Deprecated* `sv_ag_pure 1` — 0: Checks for player models consistency, variables and wallhack. 1: Adds checks for weapon models.

### Vote

* ✨ **New!** `sv_ag_vote_duration 30` — Duration of vote.
* ✨ **New!** `sv_ag_vote_oldstyle 0` — Sets the style of the vote. Old style (text vote) or the new style (HUD vote).
* `sv_ag_allow_vote 1` — Allow voting.
* `sv_ag_vote_setting 1` — Vote ag_xxx settings.
* `sv_ag_vote_gamemode 1` — Allow game mode switching. If enabled, only shows available modes in `sv_ag_allowed_gamemodes`.
* `sv_ag_vote_kick 0` — Allow voting a kick.
* `sv_ag_vote_map 1` — Allow map voting.
* `sv_ag_vote_start 1` — Allow agstart/agkick.
* `sv_ag_vote_allow 1` — Allow agallow..
* `sv_ag_vote_failed_time 15` — Seconds until next vote can begin if last failed.
* `sv_ag_vote_mp_timelimit_low 10` — Lowest timelimit to vote on.
* `sv_ag_vote_mp_timelimit_high 1440` — Highest timelimit to vote on.
* `sv_ag_vote_mp_fraglimit_low 0` — Lowest fraglimit to vote on.
* `sv_ag_vote_mp_fraglimit_high 999` — Highest fraglimit to vote on.
* ⛔ *Deprecated* `sv_ag_vote_admin 0` — Allow voting an admin. Dropped in favour of AMXX admin system.
