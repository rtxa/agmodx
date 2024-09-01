# Changelog

## [2.6] - 2024-09-01

### New

- **CTF:** Game play has been changed to be more like the original mod.
  - Now in order to capture, your team's flag must still be at your base.
  - Messages, sounds and the flag model are now like AG.
- **BHL:** Improved compatibility with older Linux servers with `GLIBC 2.17`.

### Fixed

- Fixed gauss charge sound not being reset when far away (Only on PAS). Still requires fixing on underwater, static discharge, etc.
- **BHL:** Fixed self gauss not blocking damage on certain angles. Now `ag_gauss_fix 2` will fully disable it.
- **Instagib:** Now self gauss damage is fully blocked.
- Fixed vote not displaying the correct error when the input value is out of bounds.

### Removed

- Removed **Beta** tag from the version. It was used at the beginning of the project when it was far from completion, but now there's no more reason to keep it.

Now the mod has an [official website](https://rtxa.github.io/agmodx) made with Docusaurus. Check it out!

## [Beta 2.5.2] - 2023-07-04

- Fixed issue with BHL not working on Linux in some cases by going back to older Metamod.
- Fixed BugfixedHL using wrong offsets for some player variables:
  - This fixes an odd behaviour with team change not working as expected when using `m_szTeamName.`
- LLHL now uses a simplified method to get FPS from server. #14 
- Added missing ready/notready commands on arena with improved behaviour allowing you to use them in more situations.
- Fixed bots/HLTVs being undecided voters.
- Added `sv_ag_vote_allow_bots` for debug purposes. Disabled by default.
- Improve game mode vote with mode and map at the same time. Example:  `arena stalkx` or `vote arena stalkx`.
- Fixed CTF misplacing entities in some maps.

## [Beta 2.5.1] - 2021-08-22

- Now displays the correct number version of AG Mod X.

## [Beta 2.5] - 2020-12-07

### New LLHL gamemode:

- FPS Limiter (Default value: 144)
- Auto-record of demos on players when a match starts.
- Included /unstuck command.
- Players can't enter the server if they're not using the original sound files.
- Nickname changes are blocked when a match is in progress (Enabled by default).
- New intermission mode that allows you to move the camera freely.
- Damage of egon has been decreased.

### Also

- Arcade: Fixed some weapons not being restore when they have been depleted (grenades, satchels).
- Removed LJ intro sound in respawn (you can notice this in Arcade or Arena).
- Now spectators are not able to hear the microphone of players in a match.
- Renamed agmodxctf.txt to agmodx_ctf.txt to keep consistency with other lang files.
- Fixed health chargers being refilled with more HP than they should be when a match starts.
- Fixed memory leak when loading map locations.
- Now map locations are being read with case ignoring (ex: HAVOC.LOC wasn't being read).    

## [Beta 2.4] - 2020-07-11

### New
- Added cvar `sv_ag_oldphysics`. Works the same as `mp_bunnyhop`. Added only for compatability.
- Added cvar `sv_ag_match_running`. Useful for plugins who need to do actions when a match starts.
- Added game mode **Arcade X**. Start with 100 HP. Everytime you kill someone, only HP and weapons are restored unlike Arcade which restores both HP and AP.
- CTF:
  - Added CTF map config files for agctf_brazilian and dm_dust.
  - Added locations for agctf_ag_crossfire, agctf_bootcamp, agctf_dabo, agctf_eden and dm_dust.

### Improved
- Only notify score of a disconnected player only when he's playing a match. If no match is being play, then notify from all disconnected players.
- CTF: Now team score gets reset and flag returns to base in agstart.
- Now weaponbox are removed properly. This will avoid crashes.
- Improved spanish translation.
- Improved clearing of corpses.

### Fixed
- Fixed code for detecting game_player_equip crashing the server in some maps (xbow_jump).
- CTF: Fixed an issue where map config files were not loading.
- Fixed an issue where players get their score penalized if they change to another team.
- Fixed an issue that happens only when the map doesn't have locations. If the player was writing %L, it was displaying garbage ("Yes" or "No").

## [Beta 2.3] - 2020-06-02

### New
- Added say commands `!yes` and `!no`
- CTF:  A flag icon is now draw in the screen when you pickup the flag.
- CTF: Added missing command 'drop flag'.

### Improved
- Improved the order of the list of votes in `aglistvotes`. Gamemode votes are now found in the last pages.
- Now `say_close` will show tag (C) instead of (T).
- Improved translations for match start in agstart, arena, lts and lms and help list.
- Locations are now fully loaded. This was affecting maps that contain a lot of locations (e.g. boot_camp).

### Fixed
- **Fixed restore score system not working as expected when player crashes.**
- Fixed set of equipment on player spawn not removing correctly some weapons.
- Instagib: fixed some maps (e.g. bootbox) giving not allowed equipment.
- Fixed `help` cmd not displaying correctly from server console.

## [Beta 2.2] - 2020-05-10

### New
- Configuration maps for CTF are now loaded.
- Added say enhacements for flag status, death location and score.
- Added `ag_spectalk` and `sv_maxspeed` votes.

### Improved
- `sv_ag_start_mp5` now gives 50 bullets instead of 25.
- Now match final result is printed in console.
- Now player score when he leaves is printed always and not only in agstart.

### Fixed
- Disabled ladder crouch fix for being gameplay changing.
- Kick message for max spectators limit not displaying correctly.
- Spectator command resetting player score in Arena, LMS and LTS.
- g_pGameRules address for Bugfixed HL has been fixed.
- `settings` displaying unknown command.
- Ammo sometimes not being set correctly on respawn.
- Arcade not setting armor on player spawn.
- Invalid private data when a player leaves before he has fully joined.

[2.6]: https://github.com/rtxa/agmodx/compare/beta-2.5.2...2.6
[Beta 2.5.2]: https://github.com/rtxa/agmodx/compare/beta-2.5.1...beta-2.5.2
[Beta 2.5.1]: https://github.com/rtxa/agmodx/compare/beta-2.5...beta-2.5.1
[Beta 2.5]: https://github.com/rtxa/agmodx/compare/beta-2.4...beta-2.5
[Beta 2.4]: https://github.com/rtxa/agmodx/compare/beta-2.3...beta-2.4
[Beta 2.3]: https://github.com/rtxa/agmodx/compare/beta-2.3...beta-2.2
[Beta 2.2]: https://github.com/rtxa/agmodx/compare/Beta-2.1...beta-2.2

