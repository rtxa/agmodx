---
sidebar_position: 2
---

# Game mode setup

How to setup game mode name, description, CVars, etc.

## Name and description

Every game mode `.cfg` file specifies his name and description this way:

1. The first line specifies what game name that should be displayed in server browser and in splash with server settings data.
2. The second line is a help text displayed when someone types `help` in console.

```c title="/gamemodes/tdm.cfg"
//AG TDM
//Team Death Match mode (FF1, WS0).
```

## Server variables

:::warning
Some settings don't change on the fly, requiring a map change to have any effect.
:::

### General
* `sv_ag_gametype ""` — Special plugins will be activated according to game type. E.g. `ctf`, `arena`, etc.
* `sv_ag_wallgauss 1` — Wall gauss effect multiplier.
* `sv_ag_headshot 3` — Head shot damage multiplier.
* `sv_ag_blastradius 1` — Explosion radius multiplier.
* <Badge type='planned' /> `sv_ag_lj_timer 0` — Remove LJ from player after certain time.
* <Badge type='planned' /> `sv_ag_spawn_volume 1` — Default volume for spawn.
* <Badge type='deprecated' /> `sv_ag_pure 0` 0: Checks for player models consistency, variables and wallhack. 1: Adds checks for weapon models.
* <Badge type='deprecated' /> `sv_ag_oldphysics 1` — Bunnyhop enabled. Dropped in favour of `mp_bunnyhop`.

### Ban weapons from the map
* `sv_ag_ban_crowbar 0`
* `sv_ag_ban_glock 0`
* `sv_ag_ban_357 0`
* `sv_ag_ban_mp5 0`
* `sv_ag_ban_shotgun 0`
* `sv_ag_ban_crossbow 0`
* `sv_ag_ban_rpg 0`
* `sv_ag_ban_gauss 0`
* `sv_ag_ban_egon 0`
* `sv_ag_ban_hornet 0`
* `sv_ag_ban_hgrenade 0`
* `sv_ag_ban_satchel 0`
* `sv_ag_ban_tripmine 0`
* `sv_ag_ban_snark 0`

### Ban ammunition from the map
* `sv_ag_ban_9mmar 0` —	Removes all 9mm ammo type from the map.
* `sv_ag_ban_m203 0`
* `sv_ag_ban_bockshot 0` — Removes shotgun ammo.
* `sv_ag_ban_uranium 0`
* `sv_ag_ban_bolts 0`
* `sv_ag_ban_rockets 0`
* `sv_ag_ban_357ammo 0`

### Ban items and chargers from the map
* `sv_ag_ban_health 0` — Removes health kits from the map.
* `sv_ag_ban_armour 0` — Removes batteries from the map.
* `sv_ag_ban_recharg 0` — Disables health and hev chargers.
* `sv_ag_ban_longjump 0`

### Set player starting weapons
* `sv_ag_start_crowbar 1`
* `sv_ag_start_glock 1`
* `sv_ag_start_357 0`
* `sv_ag_start_mp5 0`
* `sv_ag_start_shotgun 0`
* `sv_ag_start_crossbow 0`
* `sv_ag_start_rpg 0`
* `sv_ag_start_gauss 0`
* `sv_ag_start_egon 0`
* `sv_ag_start_hornet 0`
* `sv_ag_start_hgrenade 0`
* `sv_ag_start_satchel 0`
* `sv_ag_start_tripmine 0`
* `sv_ag_start_snark 0`

### Set player starting ammo
* `sv_ag_start_9mmar 68` — Sets 9mm backpack ammo.
* `sv_ag_start_m203 0`
* `sv_ag_start_bockshot 0` — Sets shotgun backpack ammo.
* `sv_ag_start_uranium 0`
* `sv_ag_start_bolts 0`
* `sv_ag_start_rockets 0`
* `sv_ag_start_357ammo 0`

### Set player starting health, armour and LJ
* `sv_ag_start_health 100`
* `sv_ag_start_armour 0`
* `sv_ag_start_longjump 0`

### Set weapons damage
* <Badge type='new' /> `sv_ag_dmg_bolts_normal 120` — Using scope.
* <Badge type='new' /> `sv_ag_dmg_bolts_explosion 40` — Not using scope.
* <Badge type='new' /> `sv_ag_dmg_gauss_secondary 200`
* `sv_ag_dmg_crowbar 25`
* `sv_ag_dmg_glock 12`
* `sv_ag_dmg_357 40`
* `sv_ag_dmg_mp5 12`
* `sv_ag_dmg_shotgun 20`
* `sv_ag_dmg_rpg 120`
* `sv_ag_dmg_gauss 20`
* `sv_ag_dmg_egon_wide 20`
* `sv_ag_dmg_hornet 10`
* `sv_ag_dmg_hgrenade 100`
* `sv_ag_dmg_satchel 120`
* `sv_ag_dmg_tripmine 150`
* `sv_ag_dmg_m203 100`
* <Badge type='deprecated' /> `sv_ag_dmg_egon_narrow 10` — Dropped. This CVar is only used in single player.
* <Badge type='deprecated' /> `sv_ag_dmg_bolts` — Dropped in favour of better naming. Original mod never actually implemented this.
* <Badge type='deprecated' /> `sv_ag_dmg_crossbow` — Dropped in favour of better naming. Original mod never actually implemented this.

:::caution Caution

Modifying the damage values of certain weapons, like the Gauss, may break client-side synchronization. Use with caution.

<details>
  <summary>List of CVars requiring client-side modifications</summary>
  * `sv_ag_dmg_gauss`
  * `sv_ag_dmg_gauss_secondary`
  * `sv_ag_dmg_hgrenade`
  > Note: There may be more.
</details>

:::