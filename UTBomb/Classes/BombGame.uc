//=============================================================================
// BombGame.uc
// Bomb defusal gametype for Unreal Tournament 99 (v469).
//
// Contains: INI class loader, round loop (freeze / live / round end),
// elimination wins, class selection, loadouts (weapons, ammo, armor, wildcard),
// teammate spectating, halftime side swap, and the bomb (carry, plant, timer,
// defuse, explosion). Bots do not carry, plant or defuse yet.
//
// The settings live in System\UTBomb.ini, section [UTBomb.BombGame]. The classes
// live in System\UTBombClasses.ini.
//=============================================================================
class BombGame extends TeamGamePlus config(UTBomb);

// ---- round states ----
const RS_WAITING = 0;   // warm-up, waiting for players on both teams
const RS_FREEZE  = 1;   // pick phase, everyone frozen and unarmed
const RS_LIVE    = 2;   // round in progress, no respawns
const RS_ENDED   = 3;   // short pause after a round

// ---- wildcard types ----
const WILD_NONE         = 0;
const WILD_TRANSLOCATOR = 1;
const WILD_AMMOPACK     = 2;
const WILD_KEG          = 3;
const WILD_DEFUSEKIT    = 4;
const WILD_NOSELFDAMAGE = 5;
const WILD_NOTEAMDAMAGE = 6;

// The super class is parsed like a class but kept at index 15, out of the menu.
const SUPER_IDX = 15;

// One bit per wildcard, so a class can have several (Wild=NoSelfDamage,Translocator:5).
// The class menu on the client uses the same numbers: 1 2 4 8 16 32.
const WBIT_TRANSLOCATOR = 1;
const WBIT_AMMOPACK = 2;
const WBIT_KEG = 4;
const WBIT_DEFUSEKIT = 8;
const WBIT_NOSELFDAMAGE = 16;
const WBIT_NOTEAMDAMAGE = 32;

// ---- settings (UTBomb.ini) ----
var() config int    RoundsToWin;
var() config int    FreezeTime;        // seconds
var() config int    RoundTime;         // seconds
var() config int    PostRoundTime;     // seconds
var() config int    AttackerTeam;      // 0 = red, 1 = blue (before halftime)
var() config int    HalftimeAfterRound; // sides swap after this many rounds, 0 = never
var() config int    PlantTime;         // seconds of holding crouch to plant
var() config int    DefuseTime;        // seconds of holding crouch to defuse
var() config int    BombTime;          // seconds from plant to explosion
var() config int    BombDamage;
var() config int    BombRadius;
var() config int    DefuseKitPercent;  // defuse time with a Defuse Kit, in percent
var() config bool   bReadyUp;           // players must ready up before the first round
var() config int    WarmupCountdown;    // seconds between "everyone ready" and the first round
var() config int    MinPlayersPerTeam;  // rounds do not start until each team has this many players
var() config bool   bRequireEvenTeams;   // ...and both teams have the same number of players
var() config bool   bDefendersSeeBomb;  // do defenders get the site name and a marker on the planted bomb
var() config int    BombTimerShown;    // who sees the bomb countdown: 0 nobody, 1 both teams, 2 attackers only, 3 defenders only
// default HUD look for all players (a player can override in UTBombClient.ini)
// bar mode: 0 off, 1 portraits, 2 text. fonts: 0 small, 1 medium, 2 big, 3 huge.
// Y = pixels from the top of the screen. Scale in percent.
var() config int    HudBarMode;
var() config int    HudBarScale;
var() config int    HudBarY;
var() config int    HudBarFont;
var() config int    HudMaxPortraits;
var() config int    HudShowNames;
var() config int    HudBannerFont;
var() config int    HudBannerY;
var() config int    HudMarkerFont;
var() config int    HudTransFont;      // translocator counter: font
var() config int    HudTransX;         // ... percent from the left (the text ends there)
var() config int    HudTransY;         // ... percent from the top
// announcer sounds, as Package.Name (see UTBomb.ini); empty = no sound
var() config string AnnCarry;
var() config string AnnPlanted;
var() config string AnnDefused;
var() config string AnnExploded;
var() config string AnnDropped;
var() config int    KegAmount;
var() config int    AmmoPackPercent;
var() config bool   bGiveImpactHammer;
var() config int    OvertimeRoundsToWin; // overtime: first team to win this many overtime rounds wins the match, 0 = no overtime
var() config int    OvertimeSwapAfter;   // the teams swap sides again after this many overtime rounds, 0 = never
var() config int    SuperLossStreak;   // a team that loses this many rounds in a row gets a super class player, 0 = off
var() config int    RegenDelay;        // seconds without taking damage before regeneration starts
var() config int    TranslocatorUses;  // translocations per round for classes with the Translocator, 0 = unlimited

// ---- parsed classes (filled by LoadClasses) ----
var int           NumClasses;
var string        CName[16];
var int           CArmor[16];
var int           CWildMask[16];   // the wildcards of a class, one WBIT_ bit each
// Weapons come in three tiers per class. Each tier can offer up to 4 choices, the
// first one is the default (normally tier 1 has just one). Index of an option:
//   ((class * 3 + tier) * 4) + option        (tier 0..2, option 0..3)
var class<Weapon> TW[192];
var int           TAmmo[192];
var string        TName[192];      // full class names
var string        TShort[192];     // short names as written in the file
var int           TCount[48];      // options per class*3 + tier
var int           SelOpt[1536];    // chosen option: ((slot * 16 + class) * 3) + tier
var int           CHealth[16];     // starting health
var int           CAmp[16];        // 1 = the class starts with the Damage Amplifier
var string        CModel[16];      // body of the class: a player class like Botpack.TMale2
var string        CSkin[16];       // skin: Package.base   (the textures are base1, base2 ...)
var string        CFace[16];       // face: Package.FaceName
var string        CPortrait[16];   // picture for the top bar: Package.Texture (default: made from Skin and Face)
var int           CSelf[16];       // damage the player does to themselves, in percent
var int           CHammerSelf[16]; // ...from the Impact Hammer only, in percent
var int           CSpeed[16];      // movement speed in percent, 100 = normal
var int           CRegen[16];      // health per second
var int           CWall[16];       // IG+ wall dodge: -1 server default, 0 off, 1 on
var int           CDodges[16];     // IG+ extra dodges in the air, -1 server default
var int           CTransUses[16];  // Wild=Translocator:N, -1 = use the TranslocatorUses default
var int           CPackSlot[16];   // which weapon (0-2) the Ammo Pack boosts
var string        CTex[16];        // optional Icon=Package.Texture per class

// ---- per player picks (matched by PlayerReplicationInfo) ----
var PlayerReplicationInfo SelPRI[32];
var int SelClass[32];
var int SelWild[32];             // -1 = use the class default wildcard
var int SelAmmoSlot[32];         // 0..2, which weapon the Ammo Pack boosts

// ---- round state ----
var int RoundState;
var int StateTimer;
var BombInfo BInfo;
var BombHUD  BHud;
var float    PlayerSyncTimer;
var int      WaitLog;
var int      LossStreak[2];       // rounds lost in a row, per team
var int      SuperSlot;           // player slot that has the super class this round, -1 = none
var int      SavedClass;          // that player's own class pick, put back after the round
var bool     bSuperLoaded;
var bool     bOT;                 // overtime is being played
var int      OTScore[2];          // overtime rounds won per team
var int      OTRound;             // overtime rounds finished
var bool     bOTSwapPending;      // swap sides at the start of the first overtime round
var bool     bOTMidSwapped;       // the swap after OvertimeSwapAfter rounds has been done
var int      LateKill[32];        // 1 = joined during a live round, goes to the spectators
var int      AppliedClass[32];    // class each player was last given (-1 = none)
var int      RegenWait[32];
var int      RegenPrev[32];
var string   OrigWall[32];        // IG+ player values before the mod changed them
var string   OrigDodges[32];
var int      OrigSaved[32];       // 1 = original IG+ values saved (UnrealScript has no bool arrays)
var int      TransLeft[32];       // translocations left this round, per player slot
var vector   TransLastLoc[32];
var int      TransOut[32];        // 1 = had the disc out on the previous tick
var bool     bMatchStarted;     // first round has started, no more ready-up
var int      StartCountdown;    // -1 = not counting
var bool     bGiving;          // true while we spawn loadout items (see BombMutator.AlwaysKeep)
var int RoundNumber;            // rounds started so far
var bool bSidesSwapped;

// ---- bomb state ----
var BombSite Sites[8];
var int      NumSites;
var bool     bBombPlanted;
var bool     bBombCarried;
var Pawn     BombCarrier;
var vector   LastCarrierLoc;
var BombActor DroppedBomb;
var BombActor PlantedBombActor;
var BombSite PlantedSite;
var bool     bCarrierInSite;
var bool     bPlanting;
var bool     bDefusing;
var float    PlantProgress;
var float    DefuseProgress;
var int      LastPlantMsg;
var int      LastDefuseMsg;
var int      AppliedWild[32];     // wildcard each player actually received
var int      RoundKills[32];
var string   PlanterName;
var string   DefuserName;


//=============================================================================
// Startup
//=============================================================================
function PostBeginPlay()
{
	local Mutator M;

	Super.PostBeginPlay();
	log("[UTBomb] build: ready-up v3 (uses PlayerPawn.bReadyToPlay)");

	// The mod has its own ready-up (bReadyUp, mutate ready). The stock tournament
	// mode, which IG+ builds its warm-up on, is not used.
	if (bTournament || bRequireReady)
		log("[UTBomb] stock tournament mode was on (bTournament=" $ bTournament $ ", bRequireReady=" $ bRequireReady $ "), turning it off. Use bReadyUp instead.");
	bTournament = False;
	bRequireReady = False;

	// A match here ends by rounds. A time limit would end it in the middle of a round.
	if (TimeLimit != 0 || FragLimit != 0)
		log("[UTBomb] TimeLimit and FragLimit are not used in this mode, setting both to 0");
	TimeLimit = 0;
	FragLimit = 0;
	StartCountdown = -1;

	// NOTE: AdminPassword and GamePassword are read from UTBomb.ini like every other
	// setting of this game type (the game does not let a mod read them from
	// elsewhere). Put them under [UTBomb.BombGame].

	LoadClasses();
	BInfo = Spawn(class'BombInfo');
	FillInfo();
	BHud = Spawn(class'BombHUD');

	// startup diagnostics: what else is running, and the bot / tournament settings
	log("[UTBomb] bTournament=" $ bTournament $ " MinPlayers=" $ MinPlayers $ " InitialBots=" $ InitialBots);
	for (M = BaseMutator; M != None; M = M.NextMutator)
		log("[UTBomb] active mutator: " $ M.Class);

	if (BaseMutator != None)
		BaseMutator.AddMutator(Spawn(class'BombMutator'));
	RoundState = RS_WAITING;
	SuperSlot = -1;
	SetTimer(1.0, true);
}


//=============================================================================
// INI class loader
//=============================================================================
function LoadClasses()
{
	local int i;

	NumClasses = 0;
	for (i = 0; i < SUPER_IDX; i++)
	{
		if (class'BombClassDefs'.Default.ClassDef[i] != "")
			ParseClassLine(class'BombClassDefs'.Default.ClassDef[i], i);
	}
	log("[UTBomb] " $ NumClasses $ " class(es) loaded");

	// the super class: given by the game to a team on a losing streak, never picked
	bSuperLoaded = false;
	if (class'BombClassDefs'.Default.SuperDef != "")
	{
		bSuperLoaded = ParseClassInto(SUPER_IDX, class'BombClassDefs'.Default.SuperDef, 99);
		if (bSuperLoaded)
			log("[UTBomb] super class loaded");
	}
}

// Parses a class line into class slot n. Returns false if the line is unusable.
function bool ParseClassInto(int n, string Line, int LineNo)
{
	local string Rest, F, Key, Val, WName;
	local int nw, p, k, amt;
	local bool bWildKey;

	for (k = 0; k < 3; k++)
		TCount[n * 3 + k] = 0;
	CArmor[n] = 0;
	CWildMask[n] = 0;
	CTex[n] = "";
	CPackSlot[n] = 0;
	CTransUses[n] = -1;
	CSpeed[n] = 100;
	CSelf[n] = 100;
	CHammerSelf[n] = 100;
	CRegen[n] = 0;
	CWall[n] = -1;
	CDodges[n] = -1;
	CHealth[n] = 100;
	CAmp[n] = 0;
	CModel[n] = "";
	CSkin[n] = "";
	CFace[n] = "";
	CPortrait[n] = "";

	Rest = Line;
	CName[n] = NextField(Rest);
	if (CName[n] == "")
	{
		log("[UTBomb] ClassDef[" $ LineNo $ "]: missing class name, skipped");
		return false;
	}

	while (Rest != "")
	{
		F = NextField(Rest);
		if (F == "")
			continue;

		p = InStr(F, "=");
		if (p >= 0)
		{
			Key = Caps(TrimStr(Left(F, p)));
			Val = TrimStr(Mid(F, p + 1));
			if (Key == "ARMOR")
				CArmor[n] = Min(Max(int(Val), 0), 300);
			else if (Key == "WILD")
			{
				// Wild=Translocator:3 limits that class to 3 translocations a round.
				// Several wildcards: Wild=NoSelfDamage,Translocator:5
				bWildKey = true;
				ParseWildList(n, Val);
			}
			else if (Key == "ICON")
				CTex[n] = Val;
			else if (Key == "PACKSLOT")
				CPackSlot[n] = Min(Max(int(Val), 1), 3) - 1;
			else if (Key == "SELFDAMAGE")
				CSelf[n] = Min(Max(int(Val), 0), 100);
			else if (Key == "HAMMERSELFDAMAGE")
				CHammerSelf[n] = Min(Max(int(Val), 0), 100);
			else if (Key == "SPEED")
				CSpeed[n] = Min(Max(int(Val), 30), 250);
			else if (Key == "REGEN")
				CRegen[n] = Min(Max(int(Val), 0), 50);
			else if (Key == "WALLDODGE")
			{
				if (int(Val) > 0 || Caps(Val) == "TRUE" || Caps(Val) == "YES")
					CWall[n] = 1;
				else
					CWall[n] = 0;
			}
			else if (Key == "DODGES")
				CDodges[n] = Min(Max(int(Val), 0), 10);
			else if (Key == "HEALTH")
				CHealth[n] = Min(Max(int(Val), 50), 400);
			else if (Key == "AMP")
				CAmp[n] = Min(Max(int(Val), 0), 1);
			else if (Key == "MODEL")
				CModel[n] = ResolveModel(Val);
			else if (Key == "SKIN")
				CSkin[n] = Val;
			else if (Key == "FACE")
				CFace[n] = Val;
			else if (Key == "PORTRAIT")
				CPortrait[n] = Val;
			else if (Key == "T1")
				ParseTier(n, 0, Val, LineNo);
			else if (Key == "T2")
				ParseTier(n, 1, Val, LineNo);
			else if (Key == "T3")
				ParseTier(n, 2, Val, LineNo);
			else
				log("[UTBomb] ClassDef[" $ LineNo $ "] (" $ CName[n] $ "): unknown setting '" $ Key $ "'");
		}
		else
		{
			if (nw >= 3)
			{
				log("[UTBomb] ClassDef[" $ LineNo $ "] (" $ CName[n] $ "): more than 3 weapons, extra ignored");
				continue;
			}
			p = InStr(F, ":");
			if (p >= 0)
			{
				WName = TrimStr(Left(F, p));
				amt = int(TrimStr(Mid(F, p + 1)));
			}
			else
			{
				WName = F;
				amt = 0;
			}
			// a plain weapon entry: it becomes the only option of the next tier
			if (AddOption(n, nw, WName, amt, LineNo))
				nw++;
		}
	}

	// a class without a Wild setting gets the Translocator, as before
	if (!bWildKey)
		CWildMask[n] = WBIT_TRANSLOCATOR;

	if (TCount[n * 3] + TCount[n * 3 + 1] + TCount[n * 3 + 2] == 0)
	{
		log("[UTBomb] ClassDef[" $ LineNo $ "] (" $ CName[n] $ "): no valid weapons, class skipped");
		return false;
	}
	CheckSkin(n);
	log("[UTBomb] Loaded class " $ (n + 1) $ ": " $ DescribeClass(n, -1));
	return true;
}

function ParseClassLine(string Line, int LineNo)
{
	if (ParseClassInto(NumClasses, Line, LineNo))
		NumClasses++;
}

// Adds one weapon option to a tier of class n. Returns true if it was added.
function bool AddOption(int n, int t, string WName, int amt, int LineNo)
{
	local class<Weapon> WC;
	local int cnt, idx;

	if (t < 0 || t > 2)
		return false;
	cnt = TCount[n * 3 + t];
	if (cnt >= 4)
	{
		log("[UTBomb] ClassDef[" $ LineNo $ "] (" $ CName[n] $ "): at most 4 weapons per tier, '" $ WName $ "' ignored");
		return false;
	}
	WC = class<Weapon>(DynamicLoadObject(ResolveWeapon(WName), class'Class', true));
	if (WC == None)
	{
		log("[UTBomb] ClassDef[" $ LineNo $ "] (" $ CName[n] $ "): unknown weapon '" $ WName $ "', skipped");
		return false;
	}
	idx = (n * 3 + t) * 4 + cnt;
	TW[idx] = WC;
	TAmmo[idx] = Max(amt, 0);
	TName[idx] = ResolveWeapon(WName);
	TShort[idx] = WName;
	TCount[n * 3 + t] = cnt + 1;
	return true;
}

// T2=Flak:30,Pulse:60   a comma separated list, the first is the default.
function ParseTier(int n, int t, string List, int LineNo)
{
	local string Entry, WName;
	local int p, q, amt;

	while (List != "")
	{
		q = InStr(List, ",");
		if (q < 0)
		{
			Entry = TrimStr(List);
			List = "";
		}
		else
		{
			Entry = TrimStr(Left(List, q));
			List = Mid(List, q + 1);
		}
		if (Entry == "")
			continue;
		p = InStr(Entry, ":");
		if (p >= 0)
		{
			WName = TrimStr(Left(Entry, p));
			amt = int(TrimStr(Mid(Entry, p + 1)));
		}
		else
		{
			WName = Entry;
			amt = 0;
		}
		AddOption(n, t, WName, amt, LineNo);
	}
}

// Returns the next '|' separated field of S (trimmed) and removes it from S.
function string NextField(out string S)
{
	local int i;
	local string F;

	i = InStr(S, "|");
	if (i < 0)
	{
		F = S;
		S = "";
	}
	else
	{
		F = Left(S, i);
		S = Mid(S, i + 1);
	}
	return TrimStr(F);
}

function string TrimStr(string S)
{
	while (Left(S, 1) == " " || Left(S, 1) == Chr(9))
		S = Mid(S, 1);
	while (Right(S, 1) == " " || Right(S, 1) == Chr(9))
		S = Left(S, Len(S) - 1);
	return S;
}

// Short INI names to full class names. Anything else is treated as a full name.
function string ResolveWeapon(string N)
{
	local string U;

	U = Caps(N);
	if (U == "SNIPER")                          return "Botpack.SniperRifle";
	if (U == "SHOCK")                           return "Botpack.ShockRifle";
	if (U == "ROCKET")                          return "Botpack.UT_Eightball";
	if (U == "FLAK")                            return "Botpack.UT_FlakCannon";
	if (U == "MINIGUN")                         return "Botpack.minigun2";
	if (U == "PULSE")                           return "Botpack.PulseGun";
	if (U == "RIPPER")                          return "Botpack.Ripper";
	if (U == "BIO")                             return "Botpack.UT_BioRifle";
	if (U == "ENFORCER")                        return "Botpack.Enforcer";
	if (U == "IMPACT" || U == "IMPACTHAMMER")   return "Botpack.ImpactHammer";
	return N;
}

// ---- class skins ----
// Model=Commando|Soldier|FCommando|FSoldier|Boss, or a full class name
function string ResolveModel(string V)
{
	local string U;

	U = Caps(TrimStr(V));
	if (U == "COMMANDO" || U == "MALECOMMANDO" || U == "TMALE1")
		return "Botpack.TMale1";
	if (U == "SOLDIER" || U == "MALESOLDIER" || U == "TMALE2")
		return "Botpack.TMale2";
	if (U == "FCOMMANDO" || U == "FEMALECOMMANDO" || U == "TFEMALE1")
		return "Botpack.TFemale1";
	if (U == "FSOLDIER" || U == "FEMALESOLDIER" || U == "TFEMALE2")
		return "Botpack.TFemale2";
	if (U == "BOSS" || U == "TBOSS")
		return "Botpack.TBoss";
	return TrimStr(V);
}

// Checks a class's skin when the classes are loaded and writes a warning to the
// log if something cannot be found. A wrong name would otherwise silently give
// the player the default look.
function CheckSkin(int n)
{
	local string Pkg, Base, FPkg, FItem;
	local int p;

	if (CSkin[n] == "" && CModel[n] == "")
		return;
	if (CSkin[n] == "" || CModel[n] == "")
	{
		log("[UTBomb] WARNING class " $ CName[n] $ ": Model and Skin must be given together, the skin is ignored");
		CSkin[n] = "";
		CModel[n] = "";
		return;
	}
	if (class<PlayerPawn>(DynamicLoadObject(CModel[n], class'Class', true)) == None)
	{
		log("[UTBomb] WARNING class " $ CName[n] $ ": unknown Model '" $ CModel[n] $ "', the skin is ignored");
		CSkin[n] = "";
		CModel[n] = "";
		return;
	}
	p = InStr(CSkin[n], ".");
	if (p < 0)
	{
		log("[UTBomb] WARNING class " $ CName[n] $ ": Skin must be written Package.name, the skin is ignored");
		CSkin[n] = "";
		CModel[n] = "";
		return;
	}
	Pkg = Left(CSkin[n], p);
	Base = Mid(CSkin[n], p + 1);
	if (DynamicLoadObject(Pkg $ "." $ Base $ "1", class'Texture', true) == None)
		log("[UTBomb] WARNING class " $ CName[n] $ ": skin texture '" $ Pkg $ "." $ Base $ "1' not found. Is the package " $ Pkg $ " on the server?");
	if (CPortrait[n] != "" && DynamicLoadObject(CPortrait[n], class'Texture', true) == None)
		log("[UTBomb] WARNING class " $ CName[n] $ ": portrait texture '" $ CPortrait[n] $ "' not found");
	if (CFace[n] != "")
	{
		p = InStr(CFace[n], ".");
		if (p < 0)
		{
			FPkg = Pkg;
			FItem = CFace[n];
		}
		else
		{
			FPkg = Left(CFace[n], p);
			FItem = Mid(CFace[n], p + 1);
		}
		if (DynamicLoadObject(FPkg $ "." $ Base $ "4" $ FItem, class'Texture', true) == None
			&& DynamicLoadObject(FPkg $ "." $ Base $ "2" $ FItem, class'Texture', true) == None)
			log("[UTBomb] WARNING class " $ CName[n] $ ": face '" $ CFace[n] $ "' not found in the skin package");
	}
}

// Gives a living player the body, skin and face of a class. The team skin
// (red or blue) is chosen by the game.
function int WildBit(int w)
{
	if (w == WILD_TRANSLOCATOR) return WBIT_TRANSLOCATOR;
	if (w == WILD_AMMOPACK)     return WBIT_AMMOPACK;
	if (w == WILD_KEG)          return WBIT_KEG;
	if (w == WILD_DEFUSEKIT)    return WBIT_DEFUSEKIT;
	if (w == WILD_NOSELFDAMAGE) return WBIT_NOSELFDAMAGE;
	if (w == WILD_NOTEAMDAMAGE) return WBIT_NOTEAMDAMAGE;
	return 0;
}

// Wild=Keg   or   Wild=NoSelfDamage,Translocator:5   or   Wild=None
function ParseWildList(int n, string List)
{
	local string Entry;
	local int q, w;

	CWildMask[n] = 0;
	while (List != "")
	{
		q = InStr(List, ",");
		if (q < 0)
		{
			Entry = TrimStr(List);
			List = "";
		}
		else
		{
			Entry = TrimStr(Left(List, q));
			List = Mid(List, q + 1);
		}
		if (Entry == "")
			continue;
		q = InStr(Entry, ":");
		if (q >= 0)
		{
			w = ParseWild(TrimStr(Left(Entry, q)));
			if (w == WILD_TRANSLOCATOR)
				CTransUses[n] = Max(int(TrimStr(Mid(Entry, q + 1))), 0);
		}
		else
			w = ParseWild(Entry);
		CWildMask[n] = CWildMask[n] | WildBit(w);
	}
}

function int ParseWild(string V)
{
	V = Caps(V);
	if (V == "TRANSLOCATOR" || V == "TL") return WILD_TRANSLOCATOR;
	if (V == "AMMOPACK" || V == "AMMO")   return WILD_AMMOPACK;
	if (V == "DEFUSEKIT" || V == "KIT")   return WILD_DEFUSEKIT;
	if (V == "NOSELFDAMAGE" || V == "SAFE") return WILD_NOSELFDAMAGE;
	if (V == "NOTEAMDAMAGE" || V == "BOOSTER") return WILD_NOTEAMDAMAGE;
	if (V == "KEG")                       return WILD_KEG;
	if (V == "NONE")                      return WILD_NONE;
	log("[UTBomb] Unknown wildcard '" $ V $ "', using None");
	return WILD_NONE;
}


//=============================================================================
// Per player class picks (called from BombMutator)
//=============================================================================
function int GetSlot(PlayerReplicationInfo PRI, bool bCreate)
{
	local int i, k, free;

	if (PRI == None)
		return -1;
	free = -1;
	for (i = 0; i < 32; i++)
	{
		if (SelPRI[i] == PRI)
			return i;
		if (SelPRI[i] == None && free < 0)
			free = i;
	}
	if (bCreate && free >= 0)
	{
		SelPRI[free] = PRI;
		SelClass[free] = 0;
		SelWild[free] = -1;
		SelAmmoSlot[free] = 0;
		AppliedWild[free] = 0;
		TransLeft[free] = -1;
		AppliedClass[free] = -1;
		LateKill[free] = 0;
		if (free == SuperSlot)
			SuperSlot = -1;
		for (k = 0; k < 48; k++)
			SelOpt[free * 48 + k] = 0;
		RegenWait[free] = 0;
		RegenPrev[free] = 0;
		OrigSaved[free] = 0;
		RoundKills[free] = 0;
		return free;
	}
	return -1;
}

function SetPlayerClass(PlayerPawn P, int ClassNo)
{
	local int slot;

	if (NumClasses == 0)
	{
		P.ClientMessage("No classes loaded - check UTBomb.ini");
		return;
	}
	if (ClassNo < 1 || ClassNo > NumClasses)
	{
		P.ClientMessage("Pick a class from 1 to " $ NumClasses $ " (type: mutate classes)");
		return;
	}
	slot = GetSlot(P.PlayerReplicationInfo, true);
	if (slot < 0)
		return;
	if (slot == SuperSlot)
	{
		P.ClientMessage("You have the SUPER class this round. It cannot be changed.");
		return;
	}
	SelClass[slot] = ClassNo - 1;
	P.ClientMessage("Class: " $ Describe(P));
	UpdateClientPick(P);
	SyncSkins();
	if (RoundState != RS_FREEZE)
		P.ClientMessage("(takes effect next round)");
}

// ---- weapon choices (tier 2 and tier 3) ----
function int SelIndex(int slot, int c, int t)
{
	return (slot * 16 + c) * 3 + t;
}

// A normal class (0 to NumClasses-1) or the super class.
function bool ValidClass(int c)
{
	if (c >= 0 && c < NumClasses)
		return true;
	return (c == SUPER_IDX && bSuperLoaded);
}

// The chosen option of a tier, 0 if there is no choice or none was made.
function int GetSel(int slot, int c, int t)
{
	local int n, o;

	n = TCount[c * 3 + t];
	if (n <= 0)
		return 0;
	o = SelOpt[SelIndex(slot, c, t)];
	if (o < 0 || o >= n)
		o = 0;
	return o;
}

// The Minigun and the Enforcer share their ammo in UT99: never both.
function bool Conflicts(int slot, int c)
{
	local int t, idx;
	local bool bMini, bEnf;

	for (t = 0; t < 3; t++)
	{
		if (TCount[c * 3 + t] <= 0)
			continue;
		idx = (c * 3 + t) * 4 + GetSel(slot, c, t);
		if (InStr(Caps(TName[idx]), "MINIGUN") >= 0)
			bMini = true;
		if (InStr(Caps(TName[idx]), "ENFORCER") >= 0)
			bEnf = true;
	}
	return (bMini && bEnf);
}

function bool TrySetOption(int slot, int c, int t, int o)
{
	local int old;

	old = SelOpt[SelIndex(slot, c, t)];
	SelOpt[SelIndex(slot, c, t)] = o;
	if (Conflicts(slot, c))
	{
		SelOpt[SelIndex(slot, c, t)] = old;
		return false;
	}
	return true;
}

function RandomizeOptions(int slot, int c)
{
	local int t, n;

	for (t = 0; t < 3; t++)
	{
		n = TCount[c * 3 + t];
		if (n > 1)
			SelOpt[SelIndex(slot, c, t)] = Rand(n);
	}
	if (Conflicts(slot, c))
	{
		SelOpt[SelIndex(slot, c, 0)] = 0;
		SelOpt[SelIndex(slot, c, 1)] = 0;
		SelOpt[SelIndex(slot, c, 2)] = 0;
	}
}

function ReportChoice(PlayerPawn P)
{
	P.ClientMessage("Class: " $ Describe(P));
	if (RoundState != RS_FREEZE)
		P.ClientMessage("(takes effect next round)");
	UpdateClientPick(P);
}

// tier is 2 or 3 (tier 1 is fixed). Goes to the next weapon on the list.
function CycleTier(PlayerPawn P, int tier)
{
	local int slot, c, t, n, o, tries;

	t = tier - 1;
	if (t < 0 || t > 2)
	{
		P.ClientMessage("Choose tier 1, 2 or 3.");
		return;
	}
	slot = GetSlot(P.PlayerReplicationInfo, true);
	if (slot < 0 || NumClasses == 0)
		return;
	c = SelClass[slot];
	if (!ValidClass(c))
		c = 0;
	n = TCount[c * 3 + t];
	if (n <= 1)
	{
		P.ClientMessage("This class has no choice for tier " $ tier $ ".");
		return;
	}
	o = GetSel(slot, c, t);
	for (tries = 0; tries < n; tries++)
	{
		o++;
		if (o >= n)
			o = 0;
		if (TrySetOption(slot, c, t, o))
		{
			ReportChoice(P);
			return;
		}
	}
	P.ClientMessage("The Minigun and the Enforcer share ammo. You cannot have both.");
}

// mutate t2 flak
function SetTierByName(PlayerPawn P, int tier, string WantName)
{
	local int slot, c, t, n, o, idx;
	local string List;

	t = tier - 1;
	if (t < 0 || t > 2)
	{
		P.ClientMessage("Choose tier 1, 2 or 3.");
		return;
	}
	slot = GetSlot(P.PlayerReplicationInfo, true);
	if (slot < 0 || NumClasses == 0)
		return;
	c = SelClass[slot];
	if (!ValidClass(c))
		c = 0;
	n = TCount[c * 3 + t];
	WantName = TrimStr(WantName);
	for (o = 0; o < n; o++)
	{
		idx = (c * 3 + t) * 4 + o;
		if (Caps(TShort[idx]) == Caps(WantName))
		{
			if (TrySetOption(slot, c, t, o))
				ReportChoice(P);
			else
				P.ClientMessage("The Minigun and the Enforcer share ammo. You cannot have both.");
			return;
		}
	}
	for (o = 0; o < n; o++)
	{
		if (o > 0)
			List = List $ ", ";
		List = List $ TShort[(c * 3 + t) * 4 + o];
	}
	if (n == 0)
		P.ClientMessage("This class has no tier " $ tier $ " weapon.");
	else
		P.ClientMessage("Tier " $ tier $ " choices for this class: " $ List);
}

function ListClasses(PlayerPawn P)
{
	local int i;

	if (NumClasses == 0)
	{
		P.ClientMessage("No classes loaded - check UTBomb.ini");
		return;
	}
	for (i = 0; i < NumClasses; i++)
		P.ClientMessage((i + 1) $ ": " $ DescribeClass(i, -1));
}

function string Describe(Pawn P)
{
	local int slot, c;

	if (NumClasses == 0)
		return "No classes loaded - check UTBomb.ini";
	c = 0;
	slot = GetSlot(P.PlayerReplicationInfo, true);
	if (slot >= 0)
		c = SelClass[slot];
	if (!ValidClass(c))
		c = 0;
	return DescribeClass(c, slot);
}

// slot >= 0: the weapons that player has chosen. slot < 0: the class defaults,
// with the number of choices in brackets.
function string DescribeClass(int c, int slot)
{
	local int t, n, o, idx;
	local string S, Txt;
	local bool bFirst;
	local class<Weapon> WC;

	S = CName[c] $ ": ";
	bFirst = true;
	for (t = 0; t < 3; t++)
	{
		n = TCount[c * 3 + t];
		if (n <= 0)
			continue;
		o = 0;
		if (slot >= 0)
			o = GetSel(slot, c, t);
		idx = (c * 3 + t) * 4 + o;
		WC = TW[idx];
		Txt = WC.Default.ItemName;
		if (TAmmo[idx] > 0)
			Txt = Txt $ " " $ TAmmo[idx];
		if (slot < 0 && n > 1)
			Txt = Txt $ " [" $ n $ " choices]";
		if (!bFirst)
			S = S $ ", ";
		S = S $ Txt;
		bFirst = false;
	}
	S = S $ " | Armor " $ CArmor[c] $ " | " $ WildMaskName(CWildMask[c], c);
	if (ExtraText(c) != "")
		S = S $ " | " $ ExtraText(c);
	return S;
}

// The optional movement values of a class, as text. Empty if the class has none.
function string ExtraText(int c)
{
	local string S;

	if (CSpeed[c] != 100)
		S = S $ "Speed " $ CSpeed[c] $ "%  ";
	if (CHealth[c] != 100)
		S = S $ "Health " $ CHealth[c] $ "  ";
	if (CAmp[c] > 0)
		S = S $ "Damage Amp  ";
	if (CRegen[c] > 0)
		S = S $ "Regen " $ CRegen[c] $ "/s  ";
	if (CSelf[c] < 100)
		S = S $ "Self damage " $ CSelf[c] $ "%  ";
	if (CHammerSelf[c] < 100 && CHammerSelf[c] < CSelf[c])
		S = S $ "Hammer self damage " $ CHammerSelf[c] $ "%  ";
	if (CWall[c] == 1)
		S = S $ "Wall dodge  ";
	if (CDodges[c] >= 0)
		S = S $ "Dodges " $ CDodges[c] $ "  ";
	return TrimStr(S);
}

// Translocations per round for a class. 0 = unlimited.
function int EffTransUses(int c)
{
	if (CTransUses[c] >= 0)
		return CTransUses[c];
	return TranslocatorUses;
}

function string JoinPart(string S, string Part)
{
	if (S == "")
		return Part;
	return S $ ", " $ Part;
}

function string WildMaskName(int mask, int c)
{
	local string S;

	if ((mask & WBIT_TRANSLOCATOR) != 0)
	{
		S = "Translocator";
		if (EffTransUses(c) > 0)
			S = S $ " x" $ EffTransUses(c);
	}
	if ((mask & WBIT_AMMOPACK) != 0)
		S = JoinPart(S, "Ammo Pack (+" $ AmmoPackPercent $ "%)");
	if ((mask & WBIT_KEG) != 0)
		S = JoinPart(S, "Keg (+" $ KegAmount $ " health)");
	if ((mask & WBIT_DEFUSEKIT) != 0)
		S = JoinPart(S, "Defuse Kit (" $ DefuseKitPercent $ "% defuse time)");
	if ((mask & WBIT_NOSELFDAMAGE) != 0)
		S = JoinPart(S, "No self damage");
	if ((mask & WBIT_NOTEAMDAMAGE) != 0)
		S = JoinPart(S, "No team damage");
	if (S == "")
		return "no wildcard";
	return S;
}


//=============================================================================
// Sides
//=============================================================================
function int AttackersNow()
{
	if (bSidesSwapped)
		return 1 - AttackerTeam;
	return AttackerTeam;
}

// After halftime the teams use each other's spawn areas. The player's team
// number is flipped only for the duration of the spawn lookup.
function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
	local NavigationPoint N;
	local byte OldTeam;

	if (bSidesSwapped && Player != None && Player.PlayerReplicationInfo != None
		&& Player.PlayerReplicationInfo.Team < 2)
	{
		OldTeam = Player.PlayerReplicationInfo.Team;
		Player.PlayerReplicationInfo.Team = 1 - OldTeam;
		N = Super.FindPlayerStart(Player, InTeam, incomingName);
		Player.PlayerReplicationInfo.Team = OldTeam;
		return N;
	}
	return Super.FindPlayerStart(Player, InTeam, incomingName);
}


//=============================================================================
// Players
//=============================================================================
function bool IsParticipant(Pawn P)
{
	if (P == None || !P.bIsPlayer || P.PlayerReplicationInfo == None)
		return false;
	if (P.PlayerReplicationInfo.bIsSpectator || P.IsA('Spectator'))
		return false;
	return (P.PlayerReplicationInfo.Team < 2);
}

function int CountPlayers(int T)
{
	local Pawn P;
	local int n;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.PlayerReplicationInfo.Team == T)
			n++;
	return n;
}

function int CountAlive(int T)
{
	local Pawn P;
	local int n;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.PlayerReplicationInfo.Team == T && P.Health > 0)
			n++;
	return n;
}

// Speeds are set to 1, not 0: the stock view-bob code divides by GroundSpeed,
// and a zero there turns the bob timer into NaN (this flooded the log).
// Speeds alone do not stop IG+ players: its dodge uses a fixed speed and crouch
// walking still moves. No physics means no walking, crouch-walking, jumping or
// dodging at all (the dodge code refuses to run without walking/falling physics).
// The speeds stay at 1 rather than 0 because the stock view-bob code divides by
// GroundSpeed.
function FreezePawn(Pawn P)
{
	P.GroundSpeed = 1;
	P.AirSpeed = 1;
	P.WaterSpeed = 1;
	P.JumpZ = 0;
	P.Velocity = vect(0, 0, 0);
	P.Acceleration = vect(0, 0, 0);
	if (P.Physics != PHYS_None)
		P.SetPhysics(PHYS_None);
}

function UnfreezePawn(Pawn P)
{
	P.GroundSpeed = P.Default.GroundSpeed;
	P.AirSpeed = P.Default.AirSpeed;
	P.WaterSpeed = P.Default.WaterSpeed;
	P.JumpZ = P.Default.JumpZ;
	if (P.Physics == PHYS_None)
		P.SetPhysics(PHYS_Falling);   // lands at once if standing on the floor
}

function FreezeAll()
{
	local Pawn P;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P))
			FreezePawn(P);
}


//=============================================================================
// Inventory handling
//=============================================================================
// Warm-up (waiting for players) keeps the normal UT spawn inventory.
// During a round every spawn is stripped bare; the loadout is handed out
// when the freeze phase ends (see GoLive).
function AddDefaultInventory(Pawn PlayerPawn)
{
	Super.AddDefaultInventory(PlayerPawn);
	if (PlayerPawn.IsA('Spectator'))
		return;
	if (RoundState != RS_WAITING)
		StripPawn(PlayerPawn);
}

function StripPawn(Pawn P)
{
	local Inventory Inv, Next;

	Inv = P.Inventory;
	while (Inv != None)
	{
		Next = Inv.Inventory;
		Inv.Destroy();
		Inv = Next;
	}
	P.Weapon = None;
	P.PendingWeapon = None;
	P.SelectedItem = None;
}

// Other mutators (e.g. weapon replacers) may swap or delete weapons that get
// spawned. While bGiving is true, BombMutator.AlwaysKeep tells them to leave
// our loadout items alone.
function Weapon GiveWeaponClass(Pawn P, class<Weapon> WC, int Amt)
{
	local Weapon W;

	bGiving = true;
	W = GiveWeaponInner(P, WC, Amt);
	bGiving = false;
	return W;
}

function Weapon GiveWeaponInner(Pawn P, class<Weapon> WC, int Amt)
{
	local Weapon W;

	if (WC == None)
		return None;
	W = Weapon(P.FindInventoryType(WC));
	if (W == None)
	{
		W = Spawn(WC);
		if (W == None)
			return None;
		W.GiveTo(P);
	}
	if (W.AmmoType == None && W.AmmoName != None)
		W.GiveAmmo(P);
	if (Amt > 0 && W.AmmoType != None)
	{
		W.AmmoType.MaxAmmo = Max(W.AmmoType.MaxAmmo, Amt);
		W.AmmoType.AmmoAmount = Amt;
	}
	return W;
}

// 1-50 = Thigh Pads, 51-100 = Body Armor, 101-150 = both.
function GiveArmor(Pawn P, int Amount)
{
	local int body, pads;

	if (Amount <= 0)
		return;
	if (Amount <= 50)
		pads = Amount;
	else if (Amount <= 100)
		body = Amount;
	else if (Amount <= 150)
	{
		body = 100;
		pads = Amount - 100;
	}
	else
	{
		// above 150: a bigger body armor, plus the full thigh pads
		body = Amount - 50;
		pads = 50;
	}
	if (body > 0)
		GiveArmorPiece(P, "Botpack.Armor2", body);
	if (pads > 0)
		GiveArmorPiece(P, "Botpack.ThighPads", pads);
}

function GiveArmorPiece(Pawn P, string ClassName, int Charge)
{
	bGiving = true;
	GiveArmorInner(P, ClassName, Charge);
	bGiving = false;
}

function GiveArmorInner(Pawn P, string ClassName, int Charge)
{
	local class<Pickup> IC;
	local Pickup Inv;

	IC = class<Pickup>(DynamicLoadObject(ClassName, class'Class', true));
	if (IC == None)
	{
		log("[UTBomb] Cannot load armor class " $ ClassName);
		return;
	}
	Inv = Spawn(IC);
	if (Inv == None)
		return;
	Inv.bHeldItem = true;
	Inv.RespawnTime = 0.0;
	Inv.Charge = Charge;
	Inv.GiveTo(P);
	Inv.PickupFunction(P);
}

// The Damage Amplifier item, activated at once (it wears off by itself).
function GiveAmp(Pawn P)
{
	local class<Pickup> IC;
	local Pickup Inv;

	IC = class<Pickup>(DynamicLoadObject("Botpack.UDamage", class'Class', true));
	if (IC == None)
	{
		log("[UTBomb] Cannot load the Damage Amplifier (Botpack.UDamage)");
		return;
	}
	bGiving = true;
	Inv = Spawn(IC);
	if (Inv != None)
	{
		Inv.bHeldItem = true;
		Inv.RespawnTime = 0.0;
		Inv.GiveTo(P);
		Inv.PickupFunction(P);
		if (!Inv.bActive)
			Inv.Activate();
	}
	bGiving = false;
}

function ApplyLoadout(Pawn P)
{
	local int slot, c, mask, i, o, idx, amt, ammoSlot;

	StripPawn(P);

	if (NumClasses == 0)
	{
		GiveWeaponClass(P, class'Enforcer', 0);
		P.SwitchToBestWeapon();
		return;
	}

	c = 0;
	slot = GetSlot(P.PlayerReplicationInfo, true);
	if (slot >= 0)
		c = SelClass[slot];
	if (!ValidClass(c))
		c = 0;
	mask = CWildMask[c];      // the wildcards belong to the class
	ammoSlot = CPackSlot[c];  // so does the tier the Ammo Pack boosts
	if ((mask & WBIT_DEFUSEKIT) != 0 && P.PlayerReplicationInfo.Team != DefendersNow())
	{
		mask = mask - WBIT_DEFUSEKIT;
		mask = mask | WBIT_TRANSLOCATOR;
		if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientMessage("The Defuse Kit only works for defenders. You get the Translocator instead.");
	}
	if (slot >= 0)
		AppliedWild[slot] = mask;
	if (ammoSlot < 0 || ammoSlot > 2 || TCount[c * 3 + ammoSlot] <= 0)
	{
		ammoSlot = 0;
		while (ammoSlot < 2 && TCount[c * 3 + ammoSlot] <= 0)
			ammoSlot++;
	}

	// weapons: tier 1 is fixed, tiers 2 and 3 use the player's choice
	for (i = 0; i < 3; i++)
	{
		if (TCount[c * 3 + i] <= 0)
			continue;
		o = 0;
		if (slot >= 0)
			o = GetSel(slot, c, i);
		idx = (c * 3 + i) * 4 + o;
		amt = TAmmo[idx];
		if ((mask & WBIT_AMMOPACK) != 0 && i == ammoSlot)
			amt = amt * (100 + AmmoPackPercent) / 100;
		GiveWeaponClass(P, TW[idx], amt);
	}

	if (bGiveImpactHammer)
		GiveWeaponClass(P, class'ImpactHammer', 0);
	if ((mask & WBIT_TRANSLOCATOR) != 0)
		GiveWeaponClass(P, class'Translocator', 0);

	if (CAmp[c] > 0)
		GiveAmp(P);

	P.Health = CHealth[c];
	if ((mask & WBIT_KEG) != 0)
		P.Health = Min(P.Health + KegAmount, 500);

	if (slot >= 0)
	{
		if (EffTransUses(c) > 0)
			TransLeft[slot] = EffTransUses(c);
		else
			TransLeft[slot] = -1;     // unlimited
		TransLastLoc[slot] = P.Location;
		TransOut[slot] = 0;
		AppliedClass[slot] = c;
		RegenWait[slot] = 0;
		RegenPrev[slot] = P.Health;
		if ((mask & WBIT_TRANSLOCATOR) == 0)
			TransLeft[slot] = -1;
		UpdateTransCounter(P, slot);
	}
	ApplyClassMovement(P, c);
	ApplyDodgeSettings(P, slot, c);

	GiveArmor(P, CArmor[c]);
	P.SwitchToBestWeapon();
}

// Removes every unheld pickup on the map (weapons, ammo, health, armor,
// dropped weapons from the last round).
function CleanupPickups()
{
	local Inventory Inv;

	foreach AllActors(class'Inventory', Inv)
		if (Inv.Owner == None)
			Inv.Destroy();
}


//=============================================================================
// Spawning rules: no respawns once the round is live
//=============================================================================
function bool RestartPlayer(Pawn aPlayer)
{
	if (RoundState == RS_LIVE || RoundState == RS_ENDED)
	{
		// A dead human pressing Fire ends up here: use it to cycle teammates.
		if (aPlayer.Health <= 0 && aPlayer.IsA('PlayerPawn') && IsParticipant(aPlayer))
			CycleSpectate(PlayerPawn(aPlayer));
		return false;
	}
	return Super.RestartPlayer(aPlayer);
}


//=============================================================================
// Spectating: dead players watch a living TEAMMATE (never the enemy)
//=============================================================================
function Pawn NextTeammate(PlayerPawn V, Pawn Current)
{
	local Pawn P, First;
	local bool bPast;

	bPast = (Current == None);
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (P == V || !IsParticipant(P) || P.Health <= 0)
			continue;
		if (P.PlayerReplicationInfo.Team != V.PlayerReplicationInfo.Team)
			continue;
		if (First == None)
			First = P;
		if (bPast)
			return P;
		if (P == Current)
			bPast = true;
	}
	return First;
}

function SetSpectateTarget(PlayerPawn PP, Pawn T)
{
	if (T == None)
	{
		PP.ViewTarget = None;
		return;
	}
	PP.ViewTarget = T;
	PP.bBehindView = false;
	PP.ClientMessage("Watching " $ T.PlayerReplicationInfo.PlayerName $ " (Fire = next teammate)");
}

function CycleSpectate(PlayerPawn PP)
{
	SetSpectateTarget(PP, NextTeammate(PP, Pawn(PP.ViewTarget)));
}

// Runs every second while the round is live: dead humans that are not
// watching a living teammate get pointed at one.
function UpdateSpectators()
{
	local Pawn P, T;
	local PlayerPawn PP;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		PP = PlayerPawn(P);
		if (PP == None || !IsParticipant(PP) || PP.Health > 0)
			continue;
		T = Pawn(PP.ViewTarget);
		if (T == None || T.Health <= 0 || T.PlayerReplicationInfo == None
			|| T.PlayerReplicationInfo.Team != PP.PlayerReplicationInfo.Team)
			SetSpectateTarget(PP, NextTeammate(PP, None));
	}
}

// Team score = rounds won. Personal score still counts kills.
function ScoreKill(Pawn Killer, Pawn Other)
{
	local int slot;

	Super(DeathMatchPlus).ScoreKill(Killer, Other);

	if (Killer == None || Other == None || Killer == Other
		|| Killer.PlayerReplicationInfo == None || Other.PlayerReplicationInfo == None)
		return;

	if (Killer.PlayerReplicationInfo.Team == Other.PlayerReplicationInfo.Team)
	{
		Killer.PlayerReplicationInfo.Score -= 2;   // cancel the +1, apply -1
	}
	else if (RoundState == RS_LIVE)
	{
		slot = GetSlot(Killer.PlayerReplicationInfo, true);
		if (slot >= 0)
			RoundKills[slot]++;
	}
}


//=============================================================================
// Bomb: carrier, plant, timer, defuse, explosion
// Plant and defuse = hold crouch and stand still. Humans only for now.
//=============================================================================
function int DefendersNow()
{
	return 1 - AttackersNow();
}

function bool IsInteracting(Pawn P)
{
	local PlayerPawn PP;

	PP = PlayerPawn(P);
	if (PP == None)
		return false;
	return (PP.bDuck != 0 && VSize(PP.Velocity) < 40.0);
}

function NotifyTeam(int T, string Msg)
{
	local Pawn P;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.PlayerReplicationInfo.Team == T && P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientMessage(Msg);
}

// Uses mapper-placed BombSite actors if the map has any. Otherwise one site
// is created at the defenders' flag base (CTF maps), or at the centre of the
// defenders' spawn area.
function SetupSitesInner()
{
	local BombSite S;
	local FlagBase FB;
	local PlayerStart PS;
	local vector Sum, Loc;
	local int n, SpawnTeam;
	local bool bFound;

	NumSites = 0;
	foreach AllActors(class'BombSite', S)
	{
		if (S.bAutoSite)
			S.Destroy();
	}
	foreach AllActors(class'BombSite', S)
	{
		if (!S.bAutoSite && NumSites < 8)
		{
			Sites[NumSites] = S;
			NumSites++;
		}
	}
	if (NumSites > 0)
		return;

	// the defenders defend the spawn area they start in
	SpawnTeam = DefendersNow();
	if (bSidesSwapped)
		SpawnTeam = 1 - SpawnTeam;

	foreach AllActors(class'FlagBase', FB)
	{
		if (FB.Team == SpawnTeam)
		{
			Loc = FB.Location;
			bFound = true;
		}
	}
	if (!bFound)
	{
		foreach AllActors(class'PlayerStart', PS)
		{
			if (PS.TeamNumber == SpawnTeam)
			{
				Sum += PS.Location;
				n++;
			}
		}
		if (n == 0)
		{
			foreach AllActors(class'PlayerStart', PS)
			{
				Sum += PS.Location;
				n++;
			}
		}
		if (n == 0)
		{
			log("[UTBomb] No bomb site and no spawn points found on this map");
			return;
		}
		Loc = Sum / float(n);
	}

	S = Spawn(class'BombSite',,, Loc + vect(0, 0, 40));
	if (S != None)
	{
		S.bAutoSite = true;
		S.SiteName = "A";
		Sites[0] = S;
		NumSites = 1;
	}
}

function SetupSites()
{
	local int i;

	SetupSitesInner();
	if (BInfo == None)
		return;
	BInfo.NumSites = NumSites;
	for (i = 0; i < NumSites; i++)
	{
		if (Sites[i] != None)
		{
			BInfo.SiteLoc[i] = Sites[i].Location;
			BInfo.SiteName[i] = Sites[i].SiteName;
		}
	}
}

function BombSite SiteAt(vector L)
{
	local int i;
	local float dx, dy;

	for (i = 0; i < NumSites; i++)
	{
		if (Sites[i] == None)
			continue;
		dx = L.X - Sites[i].Location.X;
		dy = L.Y - Sites[i].Location.Y;
		if (Sqrt(dx * dx + dy * dy) <= Sites[i].Radius && Abs(L.Z - Sites[i].Location.Z) <= 150.0)
			return Sites[i];
	}
	return None;
}

function ResetBomb()
{
	local int i;

	PlanterName = "";
	DefuserName = "";
	for (i = 0; i < 32; i++)
		RoundKills[i] = 0;
	if (PlantedBombActor != None)
		PlantedBombActor.Destroy();
	if (DroppedBomb != None)
		DroppedBomb.Destroy();
	PlantedBombActor = None;
	DroppedBomb = None;
	BombCarrier = None;
	PlantedSite = None;
	bBombPlanted = false;
	bBombCarried = false;
	bCarrierInSite = false;
	bPlanting = false;
	bDefusing = false;
	PlantProgress = 0.0;
	DefuseProgress = 0.0;
	LastPlantMsg = 0;
	LastDefuseMsg = 0;
	SetupSites();
}

// One random human attacker gets the bomb when the round goes live.
function AssignBomb()
{
	local Pawn P, Pick;
	local int n;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.Health > 0 && P.PlayerReplicationInfo.Team == AttackersNow() && P.IsA('PlayerPawn'))
		{
			n++;
			if (Rand(n) == 0)
				Pick = P;
		}
	}
	BombCarrier = Pick;
	bBombCarried = (Pick != None);
	if (Pick == None)
	{
		BroadcastMessage("No human attacker to carry the bomb this round.");
		return;
	}
	LastCarrierLoc = Pick.Location;
	GiveBombItem(Pick);
	NotifyTeam(AttackersNow(), Pick.PlayerReplicationInfo.PlayerName $ " is carrying the bomb.");
	PlayerPawn(Pick).ClientMessage("You have the bomb! Take it to the bomb site, then hold crouch and stand still to plant.");
	PlayerPawn(Pick).ReceiveLocalizedMessage(class'BombMessage', 0);
	PlayAnnouncerFor(Pick, AnnCarry);
}

function GiveBombItem(Pawn P)
{
	local BombItem B;

	if (P == None)
		return;
	B = Spawn(class'BombItem');
	if (B == None)
		return;
	B.bHeldItem = true;
	B.RespawnTime = 0.0;
	B.GiveTo(P);
}

function RemoveBombItem(Pawn P)
{
	local Inventory Inv;

	if (P == None)
		return;
	Inv = P.FindInventoryType(class'BombItem');
	if (Inv != None)
		Inv.Destroy();
}

function DropBomb()
{
	RemoveBombItem(BombCarrier);
	bBombCarried = false;
	BombCarrier = None;
	bPlanting = false;
	bCarrierInSite = false;
	PlantProgress = 0.0;
	LastPlantMsg = 0;
	DroppedBomb = Spawn(class'BombActor',,, LastCarrierLoc);
	if (DroppedBomb != None)
		DroppedBomb.SetPhysics(PHYS_Falling);
	NotifyTeam(AttackersNow(), "The bomb has been dropped!");
	PlayAnnouncerTeam(AttackersNow(), AnnDropped);
}

function PlantBomb(BombSite S)
{
	local vector L;

	L = BombCarrier.Location;
	L.Z -= BombCarrier.CollisionHeight - 6.0;
	PlantedBombActor = Spawn(class'BombActor',,, L);
	if (PlantedBombActor != None)
	{
		PlantedBombActor.bArmed = true;
		PlantedBombActor.SecondsLeft = BombTime;
	}
	PlanterName = BombCarrier.PlayerReplicationInfo.PlayerName;
	RemoveBombItem(BombCarrier);
	PlantedSite = S;
	bBombPlanted = true;
	bBombCarried = false;
	BombCarrier = None;
	bPlanting = false;
	PlantProgress = 0.0;
	DefuseProgress = 0.0;
	StateTimer = BombTime;     // the HUD clock now shows the bomb countdown
	// the attackers planted it, so they know where. Defenders only hear that it is down.
	NotifyTeam(AttackersNow(), "THE BOMB HAS BEEN PLANTED at site " $ S.SiteName $ "!");
	if (bDefendersSeeBomb)
		NotifyTeam(DefendersNow(), "THE BOMB HAS BEEN PLANTED at site " $ S.SiteName $ "!");
	else
		NotifyTeam(DefendersNow(), "THE BOMB HAS BEEN PLANTED! Find it.");
	BroadcastLocalizedMessage(class'BombMessage', 1);
	PlayAnnouncer(AnnPlanted);
}

function DefuseBomb(Pawn Who)
{
	if (Who != None && Who.PlayerReplicationInfo != None)
		DefuserName = Who.PlayerReplicationInfo.PlayerName;
	if (PlantedBombActor != None)
		PlantedBombActor.bArmed = false;
	BroadcastMessage("The bomb has been DEFUSED!", true);
	BroadcastLocalizedMessage(class'BombMessage', 2);
	PlayAnnouncer(AnnDefused);
	EndRound(DefendersNow(), "bomb defused");
}

function SpawnExplosionFX(vector L)
{
	local class<Actor> EC;
	local Actor E;

	EC = class<Actor>(DynamicLoadObject("Botpack.UT_SpriteBallExplosion", class'Class', true));
	if (EC != None)
	{
		E = Spawn(EC,,, L);
		if (E != None)
			E.DrawScale = 6.0;
	}
	EC = class<Actor>(DynamicLoadObject("Botpack.ShockWave", class'Class', true));
	if (EC != None)
		Spawn(EC,,, L);
}

function ExplodeBomb()
{
	local vector L;

	if (PlantedBombActor == None)
	{
		EndRound(AttackersNow(), "bomb exploded");
		return;
	}
	L = PlantedBombActor.Location;
	PlantedBombActor.bArmed = false;
	SpawnExplosionFX(L);
	FlashAll(-1.0, vect(1000, 900, 700));
	ShakeAll(1.5, 800.0, 40.0);
	PlantedBombActor.HurtRadius(BombDamage, BombRadius, 'Exploded', 200000.0, L);
	PlantedBombActor.Destroy();
	PlantedBombActor = None;
	BroadcastMessage("THE BOMB EXPLODED!", true);
	BroadcastLocalizedMessage(class'BombMessage', 3);
	PlayAnnouncer(AnnExploded);
	EndRound(AttackersNow(), "bomb exploded");
}

function UpdateCarry(float Delta)
{
	local Pawn P;
	local BombSite S;
	local float moved, expected;

	// bomb lying on the floor: any living human attacker can pick it up
	if (!bBombCarried)
	{
		if (DroppedBomb == None)
			return;
		for (P = Level.PawnList; P != None; P = P.NextPawn)
		{
			if (IsParticipant(P) && P.Health > 0 && P.PlayerReplicationInfo.Team == AttackersNow()
				&& P.IsA('PlayerPawn') && VSize(P.Location - DroppedBomb.Location) < 90.0)
			{
				BombCarrier = P;
				bBombCarried = true;
				LastCarrierLoc = P.Location;
				GiveBombItem(P);
				DroppedBomb.Destroy();
				DroppedBomb = None;
				NotifyTeam(AttackersNow(), P.PlayerReplicationInfo.PlayerName $ " picked up the bomb.");
				PlayerPawn(P).ReceiveLocalizedMessage(class'BombMessage', 0);
				PlayAnnouncerFor(P, AnnCarry);
				return;
			}
		}
		return;
	}

	// carrier died or left: drop it
	if (BombCarrier == None || BombCarrier.Health <= 0 || !IsParticipant(BombCarrier))
	{
		DropBomb();
		return;
	}

	// Teleporting (translocator, map teleporters) leaves the bomb behind:
	// a jump much bigger than the carrier's speed allows means a teleport.
	moved = VSize(BombCarrier.Location - LastCarrierLoc);
	expected = VSize(BombCarrier.Velocity) * Delta;
	if (moved > expected * 2.0 + 100.0)
	{
		DropBomb();      // drops at LastCarrierLoc, the spot they left
		return;
	}
	LastCarrierLoc = BombCarrier.Location;

	S = SiteAt(BombCarrier.Location);
	if (S != None && !bCarrierInSite)
		PlayerPawn(BombCarrier).ClientMessage("Bomb site " $ S.SiteName $ ": hold crouch and stand still to plant.");
	bCarrierInSite = (S != None);

	if (S != None && IsInteracting(BombCarrier))
	{
		if (!bPlanting)
		{
			bPlanting = true;
			PlayerPawn(BombCarrier).ClientMessage("Planting... keep crouching and stay still.");
		}
		PlantProgress += Delta;
		if (PlantProgress >= PlantTime)
		{
			PlantBomb(S);
			return;
		}
		if (int(PlantProgress) > LastPlantMsg)
		{
			LastPlantMsg = int(PlantProgress);
			PlayerPawn(BombCarrier).ClientMessage("Planting... " $ LastPlantMsg $ "/" $ PlantTime);
		}
	}
	else if (bPlanting)
	{
		bPlanting = false;
		PlantProgress = 0.0;
		LastPlantMsg = 0;
		PlayerPawn(BombCarrier).ClientMessage("Plant interrupted.");
	}
}

function UpdateDefuse(float Delta)
{
	local Pawn P, Who;
	local float Need;

	if (PlantedBombActor == None)
		return;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!IsParticipant(P) || P.Health <= 0 || P.PlayerReplicationInfo.Team != DefendersNow())
			continue;
		if (!P.IsA('PlayerPawn'))
			continue;
		if (VSize(P.Location - PlantedBombActor.Location) > 150.0)
			continue;
		if (!IsInteracting(P))
			continue;
		Who = P;
		break;
	}

	if (Who != None)
	{
		Need = DefuseTime;
		if (HasKit(Who))
			Need = Need * DefuseKitPercent / 100.0;
		if (!bDefusing)
		{
			bDefusing = true;
			PlayerPawn(Who).ClientMessage("Defusing... keep crouching and stay still.");
		}
		DefuseProgress += Delta;
		if (DefuseProgress >= Need)
		{
			DefuseBomb(Who);
			return;
		}
		if (int(DefuseProgress) > LastDefuseMsg)
		{
			LastDefuseMsg = int(DefuseProgress);
			PlayerPawn(Who).ClientMessage("Defusing... " $ LastDefuseMsg $ "/" $ int(Need + 0.5));
		}
	}
	else if (bDefusing)
	{
		bDefusing = false;
		DefuseProgress = 0.0;
		LastDefuseMsg = 0;
	}
}

function bool HasKit(Pawn P)
{
	local int slot;

	slot = GetSlot(P.PlayerReplicationInfo, false);
	return (slot >= 0 && (AppliedWild[slot] & WBIT_DEFUSEKIT) != 0);
}

function FlashAll(float Scale, vector Fog)
{
	local Pawn P;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientInstantFlash(Scale, Fog);
}

function ShakeAll(float Time, float Roll, float Vert)
{
	local Pawn P;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ShakeView(Time, Roll, Vert);
}

// Last 10 seconds of the bomb: countdown plus a red screen pulse that grows.
function bool CanSeeTimer(int T)
{
	if (BombTimerShown == 0)
		return false;
	if (BombTimerShown == 1)
		return true;
	if (BombTimerShown == 2)
		return (T == AttackersNow());
	return (T == DefendersNow());
}

function bool ViewerSeesTimer(Pawn P)
{
	if (!IsParticipant(P))
		return (BombTimerShown == 1);
	return CanSeeTimer(P.PlayerReplicationInfo.Team);
}

function BombDrama(int T)
{
	local Pawn P;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (P.IsA('PlayerPawn') && ViewerSeesTimer(P))
		{
			PlayerPawn(P).ClientMessage(T $ "...");
			PlayerPawn(P).ClientInstantFlash(-0.12 - (10 - T) * 0.03, vect(500, 0, 0));
		}
	}
}

function Sound LoadAnnouncer(string N)
{
	if (N == "")
		return None;
	return Sound(DynamicLoadObject(N, class'Sound', true));
}

function PlayAnnouncer(string N)
{
	local Sound S;
	local Pawn P;

	S = LoadAnnouncer(N);
	if (S == None)
		return;
	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientPlaySound(S, true, true);
}

function PlayAnnouncerTeam(int T, string N)
{
	local Sound S;
	local Pawn P;

	S = LoadAnnouncer(N);
	if (S == None)
		return;
	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.PlayerReplicationInfo.Team == T && P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientPlaySound(S, true, true);
}

function PlayAnnouncerFor(Pawn P, string N)
{
	local Sound S;

	S = LoadAnnouncer(N);
	if (S != None && P != None && P.IsA('PlayerPawn'))
		PlayerPawn(P).ClientPlaySound(S, true, true);
}

function BuildSummary()
{
	local Pawn P;
	local int slot, best;
	local string S, BestName;

	if (PlanterName != "")
		S = "Planted by " $ PlanterName $ ". ";
	if (DefuserName != "")
		S = S $ "Defused by " $ DefuserName $ ". ";
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!IsParticipant(P))
			continue;
		slot = GetSlot(P.PlayerReplicationInfo, false);
		if (slot >= 0 && RoundKills[slot] > best)
		{
			best = RoundKills[slot];
			BestName = P.PlayerReplicationInfo.PlayerName;
		}
	}
	if (best == 1)
		S = S $ "Round MVP: " $ BestName $ " (1 kill).";
	else if (best > 1)
		S = S $ "Round MVP: " $ BestName $ " (" $ best $ " kills).";
	if (S != "")
		BroadcastMessage(S);
}

//=============================================================================
// Client sync: class data, round state, per-player menu
//=============================================================================
// The same data FillInfo sends for the normal classes, for one class index.
// Tells every client which class each player has, so that each client can put the
// class skins on the players it sees. A class chosen during a live round only
// shows from the next round.
function SyncSkins()
{
	local Pawn P;
	local int slot, c, n;

	if (BInfo == None)
		return;
	for (n = 0; n < 32; n++)
	{
		BInfo.SkinPID[n] = -1;
		BInfo.SkinCls[n] = -1;
		BInfo.SkinTex[n] = None;
	}
	n = 0;
	for (P = Level.PawnList; P != None && n < 32; P = P.NextPawn)
	{
		if (!IsParticipant(P) || P.PlayerReplicationInfo == None)
			continue;
		slot = GetSlot(P.PlayerReplicationInfo, false);
		if (slot < 0)
			continue;
		c = SelClass[slot];
		if ((RoundState == RS_LIVE || RoundState == RS_ENDED) && AppliedClass[slot] >= 0)
			c = AppliedClass[slot];
		BInfo.SkinPID[n] = P.PlayerReplicationInfo.PlayerID;
		BInfo.SkinCls[n] = c;
		// A client clears a player's own picture when that player comes into view
		// (the game sets a plain default skin on the new pawn), so the server
		// sends it along for the top bar.
		BInfo.SkinTex[n] = P.PlayerReplicationInfo.TalkTexture;
		n++;
	}
}

function FillInfoClass(int i)
{
	local int t, k, o;

	BInfo.ClsName[i] = CName[i];
	BInfo.ClsArmor[i] = CArmor[i];
	BInfo.ClsWild[i] = CWildMask[i];
	BInfo.ClsTex[i] = CTex[i];
	BInfo.ClsTrans[i] = EffTransUses(i);
	BInfo.ClsHealth[i] = CHealth[i];
	BInfo.ClsModel[i] = CModel[i];
	BInfo.ClsSkin[i] = CSkin[i];
	BInfo.ClsFace[i] = CFace[i];
	BInfo.ClsPortrait[i] = CPortrait[i];
	BInfo.ClsSpeed[i] = CSpeed[i];
	BInfo.ClsRegen[i] = CRegen[i];
	BInfo.ClsSelf[i] = CSelf[i];
	BInfo.ClsHammerSelf[i] = CHammerSelf[i];
	BInfo.ClsWall[i] = CWall[i];
	BInfo.ClsDodges[i] = CDodges[i];
	for (t = 0; t < 3; t++)
	{
		k = i * 3 + t;
		BInfo.ClsTCount[k] = TCount[k];
		if (TCount[k] > 0)
		{
			BInfo.ClsWeap[k] = TName[k * 4];
			BInfo.ClsAmmo[k] = TAmmo[k * 4];
		}
		for (o = 0; o < 4; o++)
			BInfo.SetOption(k * 4 + o, TName[k * 4 + o], TAmmo[k * 4 + o], TShort[k * 4 + o]);
	}
}

function FillInfo()
{
	local int i, o;

	if (BInfo == None)
		return;
	BInfo.NumClasses = NumClasses;
	for (i = 0; i < NumClasses; i++)
	{
		BInfo.ClsName[i] = CName[i];
		BInfo.ClsArmor[i] = CArmor[i];
		BInfo.ClsWild[i] = CWildMask[i];
		BInfo.ClsTex[i] = CTex[i];
		BInfo.ClsTrans[i] = EffTransUses(i);
		BInfo.ClsHealth[i] = CHealth[i];
		BInfo.ClsModel[i] = CModel[i];
		BInfo.ClsSkin[i] = CSkin[i];
		BInfo.ClsFace[i] = CFace[i];
		BInfo.ClsPortrait[i] = CPortrait[i];
		BInfo.ClsSpeed[i] = CSpeed[i];
		BInfo.ClsRegen[i] = CRegen[i];
		BInfo.ClsSelf[i] = CSelf[i];
		BInfo.ClsHammerSelf[i] = CHammerSelf[i];
		BInfo.ClsWall[i] = CWall[i];
		BInfo.ClsDodges[i] = CDodges[i];
	}
	for (i = 0; i < NumClasses * 3; i++)
	{
		BInfo.ClsTCount[i] = TCount[i];
		if (TCount[i] > 0)
		{
			BInfo.ClsWeap[i] = TName[i * 4];     // the default weapon, for the card icons
			BInfo.ClsAmmo[i] = TAmmo[i * 4];
		}
		for (o = 0; o < 4; o++)
		{
			BInfo.SetOption(i * 4 + o, TName[i * 4 + o], TAmmo[i * 4 + o], TShort[i * 4 + o]);
		}
	}
	if (bSuperLoaded)
		FillInfoClass(SUPER_IDX);
	BInfo.AmmoPackPct = AmmoPackPercent;
	BInfo.KegAmt = KegAmount;
	BInfo.DefuseKitPct = DefuseKitPercent;
	BInfo.HudBarMode = HudBarMode;
	BInfo.HudBarScale = HudBarScale;
	BInfo.HudBarY = HudBarY;
	BInfo.HudBarFont = HudBarFont;
	BInfo.HudMaxPort = HudMaxPortraits;
	BInfo.HudShowNames = HudShowNames;
	BInfo.bDefSeeBomb = bDefendersSeeBomb;
	BInfo.HudBannerFont = HudBannerFont;
	BInfo.HudBannerY = HudBannerY;
	BInfo.HudMarkerFont = HudMarkerFont;
	BInfo.HudTransFont = HudTransFont;
	BInfo.HudTransX = HudTransX;
	BInfo.HudTransY = HudTransY;
}

function SyncInfo()
{
	if (BInfo == None)
		return;
	BInfo.RoundState = RoundState;
	BInfo.RoundNum = RoundNumber;
	if (Teams[0] != None)
		BInfo.Score0 = int(Teams[0].Score);
	if (Teams[1] != None)
		BInfo.Score1 = int(Teams[1].Score);
	BInfo.Alive0 = CountAlive(0);
	BInfo.Alive1 = CountAlive(1);
	BInfo.AttackTeam = AttackersNow();
	BInfo.SecondsLeft = StateTimer;
	BInfo.WarmReady = ReadyCount();
	BInfo.WarmTotal = HumanCount();
	if (RoundState == RS_WAITING && bReadyUp && !bMatchStarted)
	{
		if (StartCountdown > 0)
			BInfo.WarmState = 2;
		else
			BInfo.WarmState = 1;
	}
	else
		BInfo.WarmState = 0;
	BInfo.WarmCountdown = Max(StartCountdown, 0);
	BInfo.WarmReason = WaitReason();
	BInfo.bOT = bOT;
	BInfo.OTScore0 = OTScore[0];
	BInfo.OTScore1 = OTScore[1];
	BInfo.bTimerVis0 = CanSeeTimer(0);
	BInfo.bTimerVis1 = CanSeeTimer(1);
}

event PostLogin(PlayerPawn NewPlayer)
{
	local int slot;

	Super.PostLogin(NewPlayer);
	GetClient(NewPlayer, true);

	// joined while a round is running: they are removed a moment later (see
	// ProcessLateJoiners) and watch their team until the next round
	if (RoundState == RS_LIVE || RoundState == RS_ENDED)
	{
		slot = GetSlot(NewPlayer.PlayerReplicationInfo, true);
		if (slot >= 0)
			LateKill[slot] = 1;
	}
}

// Runs once a second. A player who joined in the middle of a round is killed
// once, so that they cannot walk around unarmed and unclassed. They then
// follow a teammate like any dead player and respawn properly next round.
function ProcessLateJoiners()
{
	local Pawn P;
	local int slot;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!P.IsA('PlayerPawn') || !IsParticipant(P))
			continue;
		slot = GetSlot(P.PlayerReplicationInfo, false);
		if (slot < 0 || LateKill[slot] == 0)
			continue;
		LateKill[slot] = 0;
		if (P.Health > 0 && (RoundState == RS_LIVE || RoundState == RS_ENDED))
		{
			PlayerPawn(P).ClientMessage("A round is in progress. You join at the start of the next round. Until then you watch your team.");
			P.Died(None, 'Suicided', P.Location);
			// a new player starts with a clean score: undo the suicide penalty
			P.PlayerReplicationInfo.Score = 0;
			P.PlayerReplicationInfo.Deaths = 0;
		}
	}
}

function FillClientPick(BombClient BC, PlayerPawn P)
{
	local int slot, c;

	BC.CurDesc = Describe(P);
	slot = GetSlot(P.PlayerReplicationInfo, true);
	c = 0;
	if (slot >= 0)
		c = SelClass[slot];
	if (!ValidClass(c))
		c = 0;
	BC.CurClass = c;
	if (slot >= 0 && NumClasses > 0)
	{
		BC.CurOpt1 = GetSel(slot, c, 0);
		BC.CurOpt2 = GetSel(slot, c, 1);
		BC.CurOpt3 = GetSel(slot, c, 2);
	}
}

// A leaving player takes their menu helper with them.
function Logout(Pawn Exiting)
{
	local BombClient BC;

	if (Exiting != None && Exiting.IsA('PlayerPawn'))
	{
		BC = GetClient(PlayerPawn(Exiting), false);
		if (BC != None)
			BC.Destroy();
	}
	Super.Logout(Exiting);
}

function BombClient GetClient(PlayerPawn P, bool bCreate)
{
	local BombClient BC;

	if (P == None)
		return None;
	foreach AllActors(class'BombClient', BC)
	{
		if (BC.Owner == P)
			return BC;
	}
	if (!bCreate)
		return None;
	BC = Spawn(class'BombClient', P);
	if (BC != None)
		FillClientPick(BC, P);
	return BC;
}

function UpdateClientPick(PlayerPawn P)
{
	local BombClient BC;

	BC = GetClient(P, false);
	if (BC != None)
		FillClientPick(BC, P);
}

function OpenMenu(PlayerPawn P)
{
	local BombClient BC;

	BC = GetClient(P, true);
	if (BC != None)
		BC.ClientOpenMenu();
}

// who is dead and who carries the bomb, for the portrait bar
function SyncPlayers()
{
	local Pawn P;
	local int i, k;

	if (BInfo == None)
		return;
	for (i = 0; i < 32; i++)
		BInfo.DeadID[i] = 0;
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.Health <= 0 && k < 32)
		{
			BInfo.DeadID[k] = P.PlayerReplicationInfo.PlayerID + 1;
			k++;
		}
	}
	for (i = 0; i < 32; i++)
		BInfo.ReadyID[i] = 0;
	k = 0;
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.IsA('PlayerPawn') && k < 32)
		{
			if (PlayerPawn(P).bReadyToPlay)
			{
				BInfo.ReadyID[k] = P.PlayerReplicationInfo.PlayerID + 1;
				k++;
			}
		}
	}
	if (bBombCarried && BombCarrier != None && BombCarrier.PlayerReplicationInfo != None)
		BInfo.CarrierID = BombCarrier.PlayerReplicationInfo.PlayerID + 1;
	else
		BInfo.CarrierID = 0;
}

// The Translocator has no ammo in UT99, so uses are counted here. A use is a
// big jump in position while the player had the disc out on the tick before.
// (Recalling the disc with alt-fire moves nobody, so it is not counted.)
function UpdateTranslocators(float Delta)
{
	local Pawn P;
	local Inventory Inv;
	local Translocator T;
	local int slot;
	local float moved, expected;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!IsParticipant(P) || P.Health <= 0)
			continue;
		slot = GetSlot(P.PlayerReplicationInfo, false);
		if (slot < 0 || TransLeft[slot] < 0)
			continue;          // unlimited, nothing to count

		// a plain loop: IG+ replaces the Translocator with a subclass of it
		T = None;
		for (Inv = P.Inventory; Inv != None; Inv = Inv.Inventory)
		{
			T = Translocator(Inv);
			if (T != None)
				break;
		}

		moved = VSize(P.Location - TransLastLoc[slot]);
		expected = VSize(P.Velocity) * Delta;
		if (T != None && TransOut[slot] != 0 && moved > expected * 2.0 + 100.0)
			UsedTranslocator(P, T, slot);

		TransLastLoc[slot] = P.Location;
		if (T != None && T.bTTargetOut)
			TransOut[slot] = 1;
		else
			TransOut[slot] = 0;
	}
}

// Tells the player's HUD how many translocations are left (-1 = no counter).
function UpdateTransCounter(Pawn P, int slot)
{
	local BombClient BC;

	if (!P.IsA('PlayerPawn'))
		return;
	BC = GetClient(PlayerPawn(P), false);
	if (BC == None)
		return;
	if (slot >= 0 && TransLeft[slot] >= 0)
		BC.TransLeft = TransLeft[slot];
	else
		BC.TransLeft = -1;
}

function UsedTranslocator(Pawn P, Translocator T, int slot)
{
	TransLeft[slot]--;
	UpdateTransCounter(P, slot);
	if (TransLeft[slot] > 0)
	{
		if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ClientMessage("Translocator uses left: " $ TransLeft[slot]);
		return;
	}
	if (P.IsA('PlayerPawn'))
		PlayerPawn(P).ClientMessage("That was your last translocation this round.");
	T.Destroy();
	P.SwitchToBestWeapon();
}

//=============================================================================
// Class movement: speed, regeneration, IG+ dodges
//=============================================================================
// Speed is a percentage of the normal values. The game sends GroundSpeed and
// friends to the owning player, so their own movement stays in step.
function ApplyClassMovement(Pawn P, int c)
{
	local float f;

	f = CSpeed[c] / 100.0;
	P.GroundSpeed = P.Default.GroundSpeed * f;
	P.AirSpeed = P.Default.AirSpeed * f;
	P.WaterSpeed = P.Default.WaterSpeed * f;
}

// IG+ only: wall dodging is a flag on the player, extra dodges a number on the
// player's PlayerReplicationInfo. The mod does not link against IG+, so both are
// set by name. Players without these properties (plain UT, bots) are skipped.
// The player's original values are saved first and put back for classes that
// do not set their own.
function ApplyDodgeSettings(Pawn P, int slot, int c)
{
	local PlayerReplicationInfo PRI;
	local string S;

	PRI = P.PlayerReplicationInfo;
	if (PRI == None || slot < 0)
		return;
	if (OrigSaved[slot] == 0)
	{
		OrigWall[slot] = P.GetPropertyText("bCanWallDodge");
		OrigDodges[slot] = PRI.GetPropertyText("MaxMultiDodges");
		OrigSaved[slot] = 1;
	}
	if (OrigWall[slot] == "" && OrigDodges[slot] == "")
		return;

	if (CWall[c] >= 0)
	{
		if (CWall[c] > 0)
			S = "True";
		else
			S = "False";
		P.SetPropertyText("bCanWallDodge", S);
	}
	else if (OrigWall[slot] != "")
		P.SetPropertyText("bCanWallDodge", OrigWall[slot]);

	if (CDodges[c] >= 0)
		PRI.SetPropertyText("MaxMultiDodges", string(CDodges[c]));
	else if (OrigDodges[slot] != "")
		PRI.SetPropertyText("MaxMultiDodges", OrigDodges[slot]);
}

// Self damage: when a player hurts themselves (rocket jumps, the Impact Hammer
// jump, their own explosions) their class can take some or all of it away.
// Only the health loss changes. The push from the blast or the hammer is a
// separate thing and stays, so the jumps still work.
function int ReduceDamage(int Damage, name DamageType, Pawn Injured, Pawn InstigatedBy)
{
	local int slot, c, pct;

	if (Injured != None && Injured == InstigatedBy && RoundState == RS_LIVE)
	{
		slot = GetSlot(Injured.PlayerReplicationInfo, false);
		if (slot >= 0)
		{
			c = AppliedClass[slot];
			if (ValidClass(c))
			{
				pct = CSelf[c];
				if ((AppliedWild[slot] & WBIT_NOSELFDAMAGE) != 0)
					pct = 0;
				if (DamageType == 'impact' && CHammerSelf[c] < pct)
					pct = CHammerSelf[c];
				if (pct < 100)
					Damage = Damage * pct / 100;
			}
		}
	}
	// No team damage: a player with this wildcard never hurts teammates, so
	// rockets and hammer hits can launch allies. The push stays, only the health
	// loss is removed. (Same effect as FriendlyFireScale=0, but for one class.)
	if (Injured != None && InstigatedBy != None && Injured != InstigatedBy && RoundState == RS_LIVE
		&& Injured.PlayerReplicationInfo != None && InstigatedBy.PlayerReplicationInfo != None
		&& Injured.PlayerReplicationInfo.Team == InstigatedBy.PlayerReplicationInfo.Team)
	{
		slot = GetSlot(InstigatedBy.PlayerReplicationInfo, false);
		if (slot >= 0 && (AppliedWild[slot] & WBIT_NOTEAMDAMAGE) != 0)
			Damage = 0;
	}
	return Super.ReduceDamage(Damage, DamageType, Injured, InstigatedBy);
}

// Once per second while a round is live. Regeneration waits RegenDelay seconds
// after the player last lost health, then heals Regen per second up to
// the class's own health.
function UpdateRegen()
{
	local Pawn P;
	local int slot, c, cap;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!IsParticipant(P) || P.Health <= 0)
			continue;
		slot = GetSlot(P.PlayerReplicationInfo, false);
		if (slot < 0)
			continue;

		if (P.Health < RegenPrev[slot])
			RegenWait[slot] = RegenDelay;
		RegenPrev[slot] = P.Health;

		c = AppliedClass[slot];
		if (!ValidClass(c) || CRegen[c] <= 0)
			continue;
		if (RegenWait[slot] > 0)
		{
			RegenWait[slot]--;
			continue;
		}
		cap = CHealth[c];            // regeneration stops at the class's own health
		if (P.Health < cap)
		{
			P.Health = Min(P.Health + CRegen[c], cap);
			RegenPrev[slot] = P.Health;
		}
	}
}

function Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);

	if (RoundState == RS_FREEZE)
		FreezeAll();
	if (RoundState == RS_LIVE)
		UpdateTranslocators(DeltaTime);

	PlayerSyncTimer -= DeltaTime;
	if (PlayerSyncTimer <= 0.0)
	{
		PlayerSyncTimer = 0.2;
		SyncPlayers();
	}

	// positions and flags for the client HUD markers
	if (BInfo != None)
	{
		BInfo.bCarried = bBombCarried;
		BInfo.bDropped = (DroppedBomb != None);
		BInfo.bPlanted = bBombPlanted;
		if (bBombCarried && BombCarrier != None)
			BInfo.CarrierLoc = BombCarrier.Location;
		if (DroppedBomb != None)
			BInfo.DropLoc = DroppedBomb.Location;
		if (PlantedBombActor != None)
			BInfo.PlantLoc = PlantedBombActor.Location;
	}

	if (RoundState != RS_LIVE || bGameEnded)
		return;
	if (bBombPlanted)
		UpdateDefuse(DeltaTime);
	else
		UpdateCarry(DeltaTime);
}


//=============================================================================
// Round loop (runs once per second)
//=============================================================================
function Timer()
{
	Super.Timer();
	if (bGameEnded)
		return;

	ProcessLateJoiners();
	SyncSkins();

	// a whole team left: stop the round instead of giving rounds away
	if ((RoundState == RS_FREEZE || RoundState == RS_LIVE)
		&& (CountPlayers(0) == 0 || CountPlayers(1) == 0))
	{
		GoWaiting();
		UpdateClock();
		SyncInfo();
		return;
	}

	if (RoundState == RS_WAITING)
	{
		WaitLog--;
		if (WaitLog <= 0)
		{
			WaitLog = 15;
			log("[UTBomb] waiting: team 0 has " $ CountPlayers(0) $ ", team 1 has " $ CountPlayers(1) $ ", ready " $ ReadyCount() $ "/" $ HumanCount() $ ", bReadyUp=" $ bReadyUp $ ", match started=" $ bMatchStarted);
			if (bReadyUp && !bMatchStarted)
			{
				if (!TeamsReady())
					BroadcastMessage("Warm-up: " $ WaitReason() $ ".");
				else if (!AllHumansReady())
					BroadcastMessage("Warm-up: waiting for everyone to ready up (" $ ReadyCount() $ "/" $ HumanCount() $ "). Type ready, or use the class menu.");
			}
		}

		if (!TeamsReady())
		{
			StartCountdown = -1;
		}
		else if (!bReadyUp || bMatchStarted)
		{
			StartRound();
		}
		else if (!AllHumansReady())
		{
			StartCountdown = -1;
		}
		else
		{
			if (StartCountdown < 0)
			{
				StartCountdown = WarmupCountdown;
				BroadcastMessage("Everyone is ready. The match starts in " $ StartCountdown $ " seconds.", true);
			}
			StartCountdown--;
			if (StartCountdown <= 0)
			{
				StartCountdown = -1;
				StartRound();
			}
			else if (StartCountdown <= 5)
			{
				BroadcastMessage(StartCountdown $ "...");
			}
		}
	}
	else if (RoundState == RS_FREEZE)
	{
		FreezeAll();   // also catches bots that respawn late
		StateTimer--;
		if (StateTimer <= 0)
			GoLive();
		else if (StateTimer <= 5)
			BroadcastMessage(StateTimer $ "...");
	}
	else if (RoundState == RS_LIVE)
	{
		StateTimer--;
		CheckElimination();
		UpdateSpectators();
		UpdateRegen();
		if (RoundState == RS_LIVE && bBombPlanted && PlantedBombActor != None)
			PlantedBombActor.SecondsLeft = StateTimer;
		if (RoundState == RS_LIVE && bBombPlanted && StateTimer > 0 && StateTimer <= 10)
			BombDrama(StateTimer);
		if (RoundState == RS_LIVE && StateTimer <= 0)
		{
			if (bBombPlanted)
				ExplodeBomb();
			else
				EndRound(DefendersNow(), "time ran out");
		}
	}
	else if (RoundState == RS_ENDED)
	{
		UpdateSpectators();
		StateTimer--;
		if (StateTimer <= 0)
		{
			if (CountPlayers(0) > 0 && CountPlayers(1) > 0)
				StartRound();
			else
				GoWaiting();
		}
	}
	UpdateClock();
	SyncInfo();
}

// The stock HUD shows a countdown whenever RemainingTime is above zero.
function UpdateClock()
{
	if (RoundState == RS_WAITING && StartCountdown > 0)
	{
		GameReplicationInfo.RemainingTime = StartCountdown;
		GameReplicationInfo.RemainingMinute = StartCountdown;
	}
	else if (RoundState == RS_WAITING || (bBombPlanted && BombTimerShown != 1))
	{
		GameReplicationInfo.RemainingTime = 0;
		GameReplicationInfo.RemainingMinute = 0;
	}
	else
	{
		GameReplicationInfo.RemainingTime = Max(StateTimer, 0);
		GameReplicationInfo.RemainingMinute = Max(StateTimer, 0);
	}
}

// ---- ready-up (before the first round only) ----
function int HumanCount()
{
	local Pawn P;
	local int n;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.IsA('PlayerPawn'))
			n++;
	return n;
}

// "Ready" is PlayerPawn.bReadyToPlay: the same flag IG+ sets with its "ready"
// command, "mutate ready" and saying "r" / "rdy" / "ready" in chat.
function int ReadyCount()
{
	local Pawn P;
	local int n;

	for (P = Level.PawnList; P != None; P = P.NextPawn)
		if (IsParticipant(P) && P.IsA('PlayerPawn') && PlayerPawn(P).bReadyToPlay)
			n++;
	return n;
}

// Bots are always ready. At least one human has to be playing.
function bool AllHumansReady()
{
	local int h;

	h = HumanCount();
	return (h > 0 && ReadyCount() == h);
}

function SetReady(PlayerPawn P, bool b)
{
	if (!IsParticipant(P))
	{
		P.ClientMessage("Spectators do not ready up.");
		return;
	}
	if (RoundState != RS_WAITING || bMatchStarted || !bReadyUp)
	{
		P.ClientMessage("Ready-up is only used in the warm-up before the first round.");
		return;
	}
	P.bReadyToPlay = b;
	if (b)
		BroadcastMessage(P.PlayerReplicationInfo.PlayerName $ " is READY (" $ ReadyCount() $ "/" $ HumanCount() $ ")");
	else
		BroadcastMessage(P.PlayerReplicationInfo.PlayerName $ " is not ready (" $ ReadyCount() $ "/" $ HumanCount() $ ")");
}

function ToggleReady(PlayerPawn P)
{
	SetReady(P, !P.bReadyToPlay);
}

// Why a round cannot start yet because of the team sizes. Empty = nothing missing.
function string WaitReason()
{
	local int a, b;

	a = CountPlayers(0);
	b = CountPlayers(1);
	if (a < 1 || b < 1)
		return "need at least one player on each team (red " $ a $ ", blue " $ b $ ")";
	if (a < MinPlayersPerTeam || b < MinPlayersPerTeam)
		return "need at least " $ MinPlayersPerTeam $ " players per team (red " $ a $ ", blue " $ b $ ")";
	if (bRequireEvenTeams && a != b)
		return "teams must have the same number of players (red " $ a $ ", blue " $ b $ ")";
	return "";
}

// Enough players on each side to start a round?
function bool TeamsReady()
{
	return (WaitReason() == "");
}

// Back to warm-up: one team has no players. Nobody is frozen or unarmed, the
// bomb is cleared, and the next round starts when both teams have a player.
function GoWaiting()
{
	local Pawn P;

	RoundState = RS_WAITING;
	StartCountdown = -1;
	ResetBomb();
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.Health > 0)
		{
			UnfreezePawn(P);
			if (P.Weapon == None)
				ApplyLoadout(P);
		}
	}
	BroadcastMessage("Waiting for players on both teams...");
}

// Puts the super player's own class pick back after their super round.
function RestoreSuper()
{
	if (SuperSlot >= 0 && SelPRI[SuperSlot] != None)
		SelClass[SuperSlot] = SavedClass;
	SuperSlot = -1;
}

// A team that has lost SuperLossStreak rounds in a row gets one random player
// with the super class for the next round. The streak starts again from zero.
function MaybeAssignSuper()
{
	local int t, n, slot;
	local Pawn P, Chosen;

	if (SuperLossStreak <= 0 || !bSuperLoaded || bOT)
		return;
	for (t = 0; t < 2; t++)
	{
		if (LossStreak[t] < SuperLossStreak)
			continue;
		Chosen = None;
		n = 0;
		for (P = Level.PawnList; P != None; P = P.NextPawn)
		{
			if (IsParticipant(P) && P.PlayerReplicationInfo.Team == t)
			{
				n++;
				if (Rand(n) == 0)
					Chosen = P;
			}
		}
		if (Chosen == None)
			continue;
		slot = GetSlot(Chosen.PlayerReplicationInfo, true);
		if (slot < 0)
			continue;

		SuperSlot = slot;
		SavedClass = SelClass[slot];
		SelClass[slot] = SUPER_IDX;
		LossStreak[t] = 0;
		if (Chosen.IsA('Bot'))
			RandomizeOptions(slot, SUPER_IDX);

		BroadcastMessage(Chosen.PlayerReplicationInfo.PlayerName $ " gets the SUPER CLASS this round! (" $ Teams[t].TeamName $ " lost " $ SuperLossStreak $ " rounds in a row)", true);
		if (Chosen.IsA('PlayerPawn'))
			PlayerPawn(Chosen).ReceiveLocalizedMessage(class'BombMessage', 5);
		UpdateClientPick(PlayerPawn(Chosen));
		return;
	}
}

function StartRound()
{
	local Pawn P;
	local int slot;
	local BombClient MenuBC;

	if (HalftimeAfterRound > 0 && RoundNumber == HalftimeAfterRound)
	{
		bSidesSwapped = !bSidesSwapped;
		BroadcastMessage("HALFTIME - the teams switch sides!", true);
	}
	if (bOTSwapPending)
	{
		bOTSwapPending = false;
		bSidesSwapped = !bSidesSwapped;
		BroadcastMessage("OVERTIME - the teams switch sides!", true);
	}
	else if (bOT && OvertimeSwapAfter > 0 && OTRound >= OvertimeSwapAfter && !bOTMidSwapped)
	{
		bOTMidSwapped = true;
		bSidesSwapped = !bSidesSwapped;
		BroadcastMessage("OVERTIME - the teams switch sides!", true);
	}
	bMatchStarted = true;
	StartCountdown = -1;
	RoundNumber++;
	RoundState = RS_FREEZE;
	StateTimer = FreezeTime;
	CleanupPickups();
	ResetBomb();
	RestoreSuper();
	MaybeAssignSuper();

	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (!IsParticipant(P))
			continue;

		// bots pick a random class every round
		if (P.IsA('Bot') && NumClasses > 0)
		{
			slot = GetSlot(P.PlayerReplicationInfo, true);
			if (slot >= 0 && slot != SuperSlot)
			{
				SelClass[slot] = Rand(NumClasses);
				SelWild[slot] = -1;
				SelAmmoSlot[slot] = 0;
				RandomizeOptions(slot, SelClass[slot]);
			}
		}

		if (P.IsA('PlayerPawn'))
		{
			PlayerPawn(P).ViewTarget = None;
			PlayerPawn(P).bBehindView = false;
			UpdateTransCounter(P, -1);
		}

		// Alive players are moved to a spawn. Dead humans are respawned.
		// Dead bots respawn on their own: they keep retrying RestartPlayer.
		if (P.Health > 0)
			RestartPlayer(P);
		else if (P.IsA('PlayerPawn'))
			PlayerPawn(P).ServerReStartPlayer();

		FreezePawn(P);

		if (P.IsA('PlayerPawn'))
		{
			if (P.PlayerReplicationInfo.Team == AttackersNow())
				PlayerPawn(P).ClientMessage("You are ATTACKING. Your class: " $ Describe(P));
			else
				PlayerPawn(P).ClientMessage("You are DEFENDING. Your class: " $ Describe(P));

			// the class menu opens by itself (each player can turn that off in the menu)
			MenuBC = GetClient(PlayerPawn(P), true);
			if (MenuBC != None)
				MenuBC.ClientAutoMenu();
		}
	}

	SyncSkins();
	BroadcastMessage("Round " $ RoundNumber $ ": pick a class (mutate class N). " $ FreezeTime $ " seconds.", true);
	BroadcastMessage(Teams[0].TeamName $ " " $ int(Teams[0].Score) $ " - " $ int(Teams[1].Score) $ " " $ Teams[1].TeamName $ "   (" $ Teams[AttackersNow()].TeamName $ " attack)");
}

function GoLive()
{
	local Pawn P;
	local BombClient MenuBC;

	RoundState = RS_LIVE;
	StateTimer = RoundTime;
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.Health > 0)
		{
			UnfreezePawn(P);
			ApplyLoadout(P);
		}
	}
	for (P = Level.PawnList; P != None; P = P.NextPawn)
	{
		if (IsParticipant(P) && P.IsA('PlayerPawn'))
		{
			MenuBC = GetClient(PlayerPawn(P), false);
			if (MenuBC != None)
				MenuBC.ClientCloseMenu();
		}
	}
	SyncSkins();
	AssignBomb();
	NotifyTeam(AttackersNow(), "Attack: the bomb site is the glowing rotating marker at the enemy base.");
	NotifyTeam(DefendersNow(), "Defend: the bomb site is the glowing rotating marker at your base.");
	BroadcastMessage("GO! One life per round.", true);
}

function CheckElimination()
{
	local int a, d;

	a = CountAlive(AttackersNow());
	d = CountAlive(1 - AttackersNow());
	if (bBombPlanted)
	{
		// after the plant, dead attackers do not matter: the bomb still counts
		if (d == 0)
			EndRound(AttackersNow(), "all defenders eliminated");
		return;
	}
	if (a == 0 && d == 0)
		EndRound(-1, "");
	else if (d == 0)
		EndRound(AttackersNow(), "all defenders eliminated");
	else if (a == 0)
		EndRound(1 - AttackersNow(), "all attackers eliminated");
}

function EndRound(int Winner, string Reason)
{
	RoundState = RS_ENDED;
	StateTimer = PostRoundTime;

	if (Winner < 0)
	{
		BroadcastMessage("Round drawn.", true);
		BuildSummary();
		return;
	}

	Teams[Winner].Score += 1;
	LossStreak[Winner] = 0;
	LossStreak[1 - Winner]++;
	BroadcastMessage(Teams[Winner].TeamName $ " win the round (" $ Reason $ ").", true);
	BuildSummary();
	BroadcastMessage(Teams[0].TeamName $ " " $ int(Teams[0].Score) $ " - " $ int(Teams[1].Score) $ " " $ Teams[1].TeamName);

	if (bOT)
	{
		// overtime is its own small match: first to OvertimeRoundsToWin
		OTScore[Winner]++;
		OTRound++;
		BroadcastMessage("Overtime: " $ Teams[0].TeamName $ " " $ OTScore[0] $ " - " $ OTScore[1] $ " " $ Teams[1].TeamName);
		if (OTScore[Winner] >= OvertimeRoundsToWin)
			EndGame("teamscorelimit");
		return;
	}

	if (Teams[Winner].Score >= RoundsToWin)
	{
		EndGame("teamscorelimit");
		return;
	}

	// level one round before the end: overtime
	if (OvertimeRoundsToWin > 0 && int(Teams[0].Score) == RoundsToWin - 1 && int(Teams[1].Score) == RoundsToWin - 1)
	{
		bOT = true;
		bOTSwapPending = true;
		bOTMidSwapped = false;
		OTScore[0] = 0;
		OTScore[1] = 0;
		OTRound = 0;
		LossStreak[0] = 0;       // no super class in overtime
		LossStreak[1] = 0;
		BroadcastMessage("OVERTIME! First to " $ OvertimeRoundsToWin $ " rounds wins the match.", true);
	}
}


defaultproperties
{
	GameName="Bomb Defusal"
	BeaconName="Bomb"
	MapPrefix="BMB"
	MaxTeams=2
	MaxTeamSize=5
	TimeLimit=0
	FragLimit=0
	GoalTeamScore=0
	RoundsToWin=10
	FreezeTime=15
	RoundTime=90
	HalftimeAfterRound=9
	OvertimeRoundsToWin=3
	OvertimeSwapAfter=3
	PlantTime=3
	DefuseTime=5
	BombTime=40
	BombDamage=500
	BombRadius=900
	DefuseKitPercent=50
	BombTimerShown=1
	bDefendersSeeBomb=False
	bReadyUp=True
	WarmupCountdown=10
	MinPlayersPerTeam=1
	bRequireEvenTeams=False
	HudBarMode=1
	HudBarScale=85
	HudBarY=6
	HudBarFont=2
	HudMaxPortraits=5
	HudShowNames=0
	HudBannerFont=3
	HudBannerY=80
	HudMarkerFont=1
	HudTransFont=2
	HudTransX=97
	HudTransY=55
	bSpawnInTeamArea=True
	PostRoundTime=5
	AttackerTeam=0
	KegAmount=100
	AmmoPackPercent=50
	bGiveImpactHammer=True
	TranslocatorUses=0
	RegenDelay=3
	SuperLossStreak=5
}
