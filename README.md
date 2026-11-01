# UTBomb: Bomb Defusal for Unreal Tournament 99

**TL;DR:** A class-based attack/defend bombsite mode for **Unreal Tournament 99 (v469)**. Attackers plant a bomb,
defenders stop them, nobody respawns, and everyone picks a class (armour, speed, weapon choices) before each round.
**Requires [InstaGibPlus](https://github.com/rxut/InstaGibPlus).** Build `UTBomb.u`, put it on the server with
`ServerPackages=UTBomb`, and run the game type `UTBomb.BombGame` on a `BMB-` map (no map is included).
Free to use and change, **not for commercial use**, credit zkyp. Licence: CC BY-NC 4.0.

> **Status:** development has stopped. It runs on a real dedicated server (Linux, with InstaGibPlus), but a full
> 5 v 5 session was never played, so expect rough edges and untuned balance. Fork it and do what you like with it
> (within the licence).

## How a match plays

- **Round flow.** Warm-up and ready-up before the first round. Then a **15 second freeze**: everybody is unarmed
  and cannot move, and picks a class and weapons (the class menu opens by itself). Then **90 seconds live**, with no
  respawns. Dead players watch their living teammates.
- **How a round is won.** Eliminate the other team. Time runs out: the **defenders** win. The bomb explodes: the
  **attackers** win. The bomb is defused: the **defenders** win.
- **The bomb.** A random human attacker carries it. Stand on a bomb site and hold **crouch** without moving for
  3 seconds to plant. It explodes after 40 seconds. A defender holds crouch next to it for 5 seconds to defuse.
  The carrier drops it on death or when translocating, and a dropped bomb shows a banner and a marker to the attackers.
- **The match.** The first team to **10 rounds** wins. The sides swap after round 9. At 9 : 9 there is an
  **overtime**: first to 3 overtime rounds, with another side swap.
- **Comeback.** A team that loses **5 rounds in a row** gets a **super class** for one random player in the next
  round (150 armour, 125 health, Damage Amplifier, Sniper 8 or Shock 14 and more).
- **Bots** spawn, pick classes and fight, but do not carry, plant or defuse the bomb.

### Classes

Weapons come in three **tiers**. Tier 1 is normally one fixed strong weapon (Shock or Sniper). Tiers 2 and 3 offer
a short list to choose from, in the class menu or with `mutate t2 flak`. Every class also has one or more
**wildcards** (Translocator with a limited number of uses, Ammo Pack, Keg, Defuse Kit, No self damage, No team
damage). Everything is defined in `System/UTBombClasses.ini`, and no recompiling is needed to change it.

| Class | Armour | Idea |
|---|---|---|
| Default | 100 | All-rounder with 5 translocations. |
| HammerKing | 75 | Impact Hammer jumps without self damage. Flak only. |
| SniperNoob | 50 | Sniper plus a weak weapon, 6 translocations. |
| FastGirl | 50 | Speed 130 and two wall dodges. Weak weapons. |
| Spammer | 150 | Tank with an Ammo Pack and no Shock or Sniper. |
| Booster | 125 | 70 health that regenerates. Never hurts teammates, so she can launch them. |
| Fatboy | 200 | Keg (+100 health), Shock 50, speed 70. |

## What you need

- **Unreal Tournament 99 v469** (the [OldUnreal](https://www.oldunreal.com) patch).
- **[InstaGibPlus](https://github.com/rxut/InstaGibPlus).** UTBomb is built for it and should be played with it. It
  was developed and tested on IG+ only, so running without it is not supported. Wall dodging (`WallDodge` and `Dodges`
  on a class) is an IG+ feature.
- To build the mod: Windows, or any setup where you can run `ucc make`.
- A map named `BMB-<something>` with team spawns and bomb sites (see **Making a map**). **No map is included.**

## Install

### 1. Build `UTBomb.u`

1. Copy the `UTBomb` folder (the one holding `Classes`) into your UT folder, next to `System`.
2. Copy everything in this repository's `System` folder into your UT `System` folder
   (`UTBomb.int`, `UTBomb.ini`, `UTBombClasses.ini`).
3. In `System/UnrealTournament.ini`, section `[Editor.EditorEngine]`, add `EditPackages=UTBomb` after the
   `EditPackages=Botpack` line.
4. From the `System` folder run: `del UTBomb.u & ucc make` (Windows). It should end with
   `Success - 0 error(s)`. The result is `System/UTBomb.u`.

### 2. Playing on your own

Install IG+, start UT and choose **Bomb Defusal** as the game type in Start Match, with a `BMB-` map.

### 3. A dedicated server

- Install InstaGibPlus on the server, following its own instructions.
- Copy `UTBomb.u`, `UTBomb.int`, `UTBomb.ini` and `UTBombClasses.ini` to the server's `System` folder.
- In the server's `UnrealTournament.ini`, section `[Engine.GameEngine]`, add `ServerPackages=UTBomb`.
- Start the server with the game type `UTBomb.BombGame`, a `BMB-` map and the IG+ mutators, for example
  `ucc server BMB-YourMap?Game=UTBomb.BombGame`.
- Players download `UTBomb.u` from the server. Every recompile is a new version, so the server and the players
  must have the same build. Copy the new file to the server after every build and restart it.

## Settings

`System/UTBomb.ini` is a working default: first to 10, 15 second freeze, 90 second rounds, 5 v 5 teams
(`MaxPlayers=10`, `MaxTeamSize=5`), five bots, and **no passwords**. Every setting has a comment where it is
declared in `UTBomb/Classes/BombGame.uc`. The ones you will touch most:

| Setting | Default | |
|---|---|---|
| `RoundsToWin` / `HalftimeAfterRound` | 10 / 9 | Match length and when the sides swap. |
| `OvertimeRoundsToWin` | 3 | First to this many overtime rounds. 0 = no overtime. |
| `FreezeTime` / `RoundTime` | 15 / 90 | Seconds. |
| `PlantTime` / `DefuseTime` / `BombTime` | 3 / 5 / 40 | Seconds. |
| `SuperLossStreak` | 5 | Lost rounds in a row for the super class. 0 = off. |
| `MinPlayersPerTeam`, `bRequireEvenTeams` | 1, False | For a proper 5 v 5 use 5 and True. |
| `bDefendersSeeBomb`, `BombTimerShown` | False, 1 | Who sees the planted bomb and its countdown. |
| `InitialBots` (in `[Botpack.DeathMatchPlus]`) | 5 | Bots to start with. 0 = humans only. |

Notes:
- **Passwords.** `AdminPassword` and `GamePassword` are empty in the default file, which means nobody can log in as
  admin and anybody can join. They live in the `[Engine.GameInfo]` section of the same file. Set them on your
  own machine and **do not commit them**.
- **The game rewrites `UTBomb.ini`** every time it starts and drops any comments. Edit it with the game stopped. If a
  server crashes on start with `SaveConfig` in the error, delete `UTBomb.ini` and let the game write a fresh one.
- **Players** can change the look of the HUD (top bar, banner, markers, translocator counter) in the class menu under
  *HUD settings*. It is saved in `System/UTBombClient.ini` on their own PC.
- **Ready-up.** The mode has its own ready-up, which works alongside IG+ (`ready` still works).
- **Forced models.** If you use class skins, set `ForceModels=0` in the server's `InstaGibPlus.ini`, or players who
  force models will not see them.
- **Log.** Everything the mod writes starts with `[UTBomb]`. Mistakes in a class line show up there as
  `[UTBomb] WARNING class ...`.

## Player commands

| Command | What it does |
|---|---|
| `mutate menu` | Opens the class menu (bind it to a key). It also opens by itself every round. |
| `mutate classes` / `mutate class <n>` | List the classes / pick one. |
| `mutate t1 <weapon>`, `t2`, `t3`, and `t1next`, `t2next`, `t3next` | Choose your weapon in a tier. |
| `mutate loadout` | Show your class and weapons. |
| `ready` or `mutate bombready` | Ready up during warm-up. |

## Making a map

1. Name it `BMB-Something`. Any Deathmatch, TDM or CTF map can be converted in UnrealEd (v469).
2. Give every `PlayerStart` a `TeamNumber`: `0` for the red team's spawn area and `1` for blue's. Five or more per
   team for 5 v 5. Delete the old team-less starts. The mode swaps the spawn areas at halftime.
3. Add `BombSite` actors (Actor class browser, Info, BombSite) where attackers should plant. Set `SiteName`
   (`A`, `B`) and `Radius` (default 250). A player plants while within `Radius` of the actor. If a map has no
   BombSite, the game creates one at the defenders' flag base, which only makes sense on CTF maps.
4. `AttackerTeam=0` in `UTBomb.ini` means red attacks first, `1` means blue.
5. For bots, run **Build > Paths** before saving. Players get their weapons from their class, so you do not
   place any.

## Class skins (optional)

A class can have its own body, skin and face with three settings on its class line:

```
... | Model=Soldier | Skin=Soldierskins_SnyperX.snyx | Face=Soldierskins_SnyperX.Fate
```

`Model` is `Commando`, `Soldier`, `FCommando`, `FSoldier` or `Boss`. `Skin` is `Package.base` (the textures
`base1`, `base2` ... without the number) and `Face` is `Package.Name` for the texture `base4Name`. An optional
`Portrait=Package.Texture` sets the class picture in the top bar. The red and blue team versions of the textures
are used automatically, so skins can look quite different from the preview in the player-setup menu.

`examples/UTBombClasses.with-skins.ini` is the class set with seven community skin packs, which are **not
included**: `CommandoSkins_AB`, `Soldierskins_SnyperX`, `FCommandoSkinsAsiaAlt`, `SoldierSkins_Ork`,
`commandoskins_dcu`, `BossSkins_keep` and `SoldierSkins_SuperRobot`. Get them from their authors, put the `.utx`
files in the server's `Textures` folder with exactly those names (Linux cares about upper and lower case) and add
one `ServerPackages=<name>` line for each. The default class file has no skins and works without any extra files.

## Known limitations

- Bots do not carry, plant or defuse.
- Balance is a first guess. The super class ammo (Rocket 24, Flak 30, Minigun 199, Pulse 60) is a placeholder.
- Never tested with real players: someone leaving in the middle of a round, defenders not seeing the carrier
  marker, the other bomb-timer modes, and how every class value behaves on every IG+ setup.
- Ideas never built: a `mutate dropbomb` command, a per-class option for plain skins in both teams, class
  restrictions per side, announcer sounds, and your own class pictures.

## Repository layout

```
UTBomb/Classes/   the UnrealScript source
System/           UTBomb.int (menu entry), UTBomb.ini and UTBombClasses.ini (defaults)
examples/         the class file with skins
LICENSE           Creative Commons Attribution-NonCommercial 4.0
```

## Credits

Vibed by zkyp.

Thanks to: not playunreal

## Licence

[Creative Commons Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/)
(CC BY-NC 4.0), see `LICENSE`. You may use, change and share it, but you must **credit zkyp** and you may **not use
it commercially** (no selling it, no paid access). This covers the code and text in this repository, not
Unreal Tournament (Epic Games) or InstaGibPlus.
