# UTBomb: Bomb Defusal for Unreal Tournament 99

**TL;DR:** A class-based attack/defend bombsite mode for **Unreal Tournament 99 (v469)**. Attackers plant a bomb,
defenders stop them, nobody respawns, and everyone picks a class (armour, speed, weapon choices) before each round.
**Requires [InstaGibPlus](https://github.com/rxut/InstaGibPlus).** Build `UTBomb.u`, put it on the server with
`ServerPackages=UTBomb`, and run the game type `UTBomb.BombGame` on a `BMB-` map (no map is included).

> **Status:** development has stopped. It runs on a real dedicated server (Linux, with InstaGibPlus), but a full
> 5 v 5 session was never played, so expect rough edges and untuned balance. Fork it and do what you like with it
> (within the licence).

   Short introduction video (youtube):
   
   [![UTBomb short introduction video](https://img.youtube.com/vi/7urG5g7vCxM/hqdefault.jpg)](https://www.youtube.com/watch?v=7urG5g7vCxM)

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
- **Comeback.** A team that loses **5 rounds in a row** gets **Superman** (the super class) for one random
  player in the next round: more armour and health, the Damage Amplifier and the pick of the best weapons.
  See [Superman](#superman-the-comeback-class).
- **Bots** spawn, pick classes and fight, but do not carry, plant or defuse the bomb.

## Classes

Before every round you pick one of seven classes in the class menu (it opens by itself during the freeze). A class
decides your **armour**, **health**, **speed**, the **weapons** you can choose from and your **wildcards**.
Everyone also carries the Impact Hammer. All numbers live in `System/UTBombClasses.ini` and can be changed
without recompiling.

### Weapon tiers

Each class has up to three weapon slots, called tiers:

| Tier | What it normally holds | Your choice |
|---|---|---|
| **Tier 1** | The strong weapon: Shock Rifle or Sniper Rifle (or nothing). | Fixed to the class. Only Superman gets two to choose from. |
| **Tier 2** | A close-range weapon: Rocket Launcher, Flak Cannon, Pulse Gun or Minigun. | A short list. The first entry is the default. |
| **Tier 3** | A weak backup: Ripper, Bio Rifle or Enforcer. | A short list. The first entry is the default. |

- **Choosing.** The class menu has one button per tier. Click it to go to the next weapon on the list. Or use the
  commands `mutate t2 flak`, `mutate t3 bio` and `mutate t2next`. Your choices are remembered per class.
- **When it counts.** A choice made during warm-up or the freeze is used straight away. One made during a live round
  is used from the next round.
- **Ammo.** Every weapon on a list has its own ammo, set by the class: `Shock 24` means 24 rounds. The numbers stay
  inside each weapon's stock maximum (Minigun 199, most others 50).
- **Minigun and Enforcer** share their ammo in UT99, so the game never lets one player have both.
- **Empty tiers are normal.** A class can leave a tier empty. The Spammer has no Shock or Sniper at all and is
  balanced by armour instead.
- **How strong is a weapon?** Top: Shock, Sniper. Strong: Rocket, Flak, Pulse, Minigun. Weak: Ripper, Bio, Enforcer.
  The class set follows one rule: every mobility or toughness advantage is paid for somewhere else.

### The seven classes

`Shock 24` is the weapon and its ammo. In the tier columns, `/` means you pick one.

| Class | Armour | Health | Speed | Tier 1 | Tier 2 | Tier 3 | Wildcards |
|---|---|---|---|---|---|---|---|
| **Default** | 100 | 100 | normal | Shock 24 | Rocket 18 / Flak 20 / Pulse 50 | none | Translocator x5 |
| **HammerKing** | 75 | 100 | normal | Shock 12 | Flak 24 | none | No self damage |
| **SniperNoob** | 50 | 100 | normal | Sniper 16 | none | Ripper 30 / Bio 20 | Translocator x6 |
| **FastGirl** | 50 | 100 | **130%** | none | Flak 12 | Ripper 30 / Enforcer 40 / Bio 20 | none, but two wall dodges (IG+) |
| **Spammer** | 150 | 100 | normal | none | Flak 30 / Pulse 60 / Rocket 18 | Ripper 40 / Bio 30 | Ammo Pack (on tier 2) |
| **Booster** | 125 | **70**, regenerates 3 a second | normal | Shock 20 | Rocket 18 | none | No team damage |
| **Fatboy** | 200 | 100 + 100 (Keg) | **70%** | Shock 50 | Minigun 199 / Rocket 18 / Flak 24 | none | Keg |

- **Default** is the all-rounder and class 0, so it is what you get if you never open the menu. Five translocations
  to push in or get out.
- **HammerKing** jumps with the Impact Hammer and takes no damage from it. His only tier 2 weapon is the Flak: with a
  Rocket Launcher he could rocket jump as well, which would be too much.
- **SniperNoob** has the Sniper, which is strong at any range, plus six translocations to change position. No tier 2.
- **FastGirl** is fast (130%) and has two wall dodges, but little armour and only weak weapons.
- **Spammer** is the tank: 150 armour and an Ammo Pack that adds half again to the tier 2 weapon (Flak 30 becomes 45,
  Pulse 60 becomes 90, Rocket 18 becomes 27). Close-range spam, with no Shock or Sniper.
- **Booster** has only 70 health but heals 3 a second after a few seconds without being hit, up to 70. Her rockets and
  hammer never hurt teammates, but they still push them, so she can launch allies across the map.
- **Fatboy** is slow (70%) and very tough: 200 armour plus 200 health at the start (100 and the Keg's 100), with a
  Shock Rifle with 50 rounds and the choice of Minigun, Rocket or Flak.

### Wildcards

Every class has a fixed wildcard (it cannot be changed in game). A class can have more than one, written like
`Wild=NoSelfDamage,Translocator:5`.

| Wildcard | What it does |
|---|---|
| **Translocator** | Gives you the Translocator. `Translocator:5` limits it to 5 uses a round: a counter on the screen shows how many are left, and after the last one the Translocator is taken away. Without a number it is unlimited (no default class does that). |
| **Ammo Pack** | Adds 50% ammo to the weapon in one tier of the class (the `PackSlot` setting). |
| **Keg** | +100 health at the start of the round, on top of the class's own health. |
| **Defuse Kit** | Defusing takes half the time. Works for defenders only: an attacker with it gets the Translocator instead. No default class uses it. |
| **No self damage** | Your own weapons do not hurt you. Rocket and Impact Hammer jumps cost no health, and you still get pushed. |
| **No team damage** | Your weapons never hurt your teammates. They still push them. |
| **None** | Nothing. |

### Other class settings

Each class line in `UTBombClasses.ini` can also set:

| Setting | Meaning |
|---|---|
| `Armor` | 0 to 300. 1-50 is thigh pads, 51-100 body armour, 101-150 both, 151-300 a bigger body armour plus pads (200 = 150 + 50). Armour only soaks part of each hit, so it is worth about one health point per point, as long as enough health is left. |
| `Health` | Starting health, 50 to 400 (default 100). Regeneration stops at this value. |
| `Speed` | Movement speed in percent, 30 to 250. Only clear steps (130 fast, 70 slow) can really be felt. |
| `Regen` | Health regained per second, after a short delay without damage (`RegenDelay`). |
| `WallDodge`, `Dodges` | Wall dodging and how many dodges in a row. These are IG+ features. |
| `SelfDamage`, `HammerSelfDamage` | Percentage of self damage you take (100 = normal, 0 = none). |
| `Amp` | `Amp=1` starts the round with the Damage Amplifier active. |
| `Model`, `Skin`, `Face`, `Portrait` | Optional look of the class, see **Class skins**. |

You can add your own classes (up to 15) by writing a new line, for example:

```
ClassDef[7]=Sapper | Armor=50 | T1=Shock:16 | T2=Flak:24,Pulse:40 | Wild=DefuseKit
```

`T1`, `T2` and `T3` are the three tiers (a comma between weapons means "pick one of these", while a comma in
`Wild=` means "all of these at once"). The comments in the file explain every setting.

## Superman (the comeback class)

If a team loses **5 rounds in a row**, one of its players becomes **Superman** in the next round. It is the mode's
comeback mechanic, so a team that is getting crushed gets one very strong player.

**What happens**
- The game picks **one random player** from the losing team (a human or a bot) at the start of the next round and
  announces it to everybody in the chat. The player gets a big message on their screen.
- It is **assigned, not picked**. Nobody can choose it, and Superman cannot change class during that round.
  He does still choose his own weapons from the lists below, in the class menu during the freeze.
- After the round he gets his normal class back. The team's count then starts again from zero, so it can happen
  again after another five lost rounds in a row.
- The count is kept per team, across the halftime side swap. It never triggers in overtime, and the count is cleared
  when overtime starts.

**What Superman gains**

| | |
|---|---|
| **Armour** | 150 |
| **Health** | 125 |
| **Damage Amplifier** | Starts the round with it active (the usual purple glow and extra damage, for its normal duration of about 30 seconds). |
| **Speed** | 80%, a little slow |
| **Translocator** | 5 uses |
| **No self damage** | Rocket and Impact Hammer jumps cost nothing. |
| **Tier 1** | Sniper Rifle 8 / Shock Rifle 14 |
| **Tier 2** | Rocket Launcher 24 / Flak Cannon 30 |
| **Tier 3** | Minigun 199 / Pulse Gun 60 |

Settings: `SuperLossStreak` in `UTBomb.ini` sets the number of lost rounds (5 by default, 0 turns the feature
off). The class itself is the `SuperDef` line in `UTBombClasses.ini`, written like any other class line. It is
called `SUPER` there, so rename it if you like (for example to Superman). The ammo numbers for the Rocket, Flak,
Minigun and Pulse are placeholders.

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

[PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0), see `LICENSE`.

You may use, change and share it for any **noncommercial** purpose. Personal use, hobby projects, communities,
education and charities are all fine, and so is running a free community server. You may **not** use it commercially:
no selling it and no paid access. Whenever you pass it on, keep the `LICENSE` file. It carries the line
`Required Notice: Copyright (c) 2026 zkyp`, which is how you credit zkyp.

This covers the code and text in this repository, not Unreal Tournament (Epic Games) or InstaGibPlus.
