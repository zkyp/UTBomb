//=============================================================================
// BombClient.uc
// One per player, owned by that player's PlayerPawn. Lets the server open the
// class menu on that player's screen and tells it the player's current pick.
//=============================================================================
class BombClient extends ReplicationInfo;

var string CurDesc;
var int    CurClass;      // the class this player picked (0-based)
var int    CurOpt1;       // chosen weapon option for tier 1 (only the super class has a choice)
var int    CurOpt2;       // chosen weapon option for tier 2
var int    CurOpt3;       // ... and for tier 3
var int    TransLeft;     // translocations left this round, -1 = no counter

// menu windows that were hidden while the class menu is open (the main menu bar),
// so that they can be shown again afterwards
var UWindowWindow HiddenWin[8];
var int           HiddenCount;

// class skins: this PC puts the skin of its class on every player in view
var Pawn     SkPawn[32];        // pawns already dressed
var int      SkClass[32];       // ... in the skin of this class
var float    SkAge[32];         // seconds since
var Mesh     SkOwnMesh[32];     // how the pawn looked before we touched it:
var Texture  SkOwnSkin[32];
var Texture  SkOwnMulti[256];   // 8 per entry
var float    SkTimer;
var float    SkLogTimer;
var bool     bSkinDebug;          // writes what the skin code does to the game log
var bool     bSkLoggedStart;
var int      SkNext;
var BombInfo SkInfo;

replication
{
	reliable if (Role == ROLE_Authority)
		CurDesc, CurClass, CurOpt1, CurOpt2, CurOpt3, TransLeft, ClientOpenMenu, ClientAutoMenu, ClientCloseMenu;
}

simulated function float MenuHeight()
{
	local BombInfo B, Found;
	local int rows;

	foreach AllActors(class'BombInfo', B)
		Found = B;
	rows = 3;
	if (Found != None)
		rows = (Found.NumClasses + 1) / 2;
	return 22 + rows * 80 + 8 + 140 + 36;
}

// The class window is created FIRST, inside the (still hidden) UWindow root,
// and only then is the menu shown. That is the same situation as pressing the
// key a second time, which was the case that always worked.
// Log lines are tagged [UTBomb menu] in UnrealTournament.log.
simulated function ClientOpenMenu()
{
	local PlayerPawn PP;
	local WindowConsole C;

	if (Level.NetMode == NM_DedicatedServer)
	{
		log("[UTBomb menu] ClientOpenMenu ran on the server instead of the player's PC");
		return;
	}
	PP = PlayerPawn(Owner);
	if (PP == None || PP.Player == None)
	{
		log("[UTBomb menu] no owner or player");
		return;
	}
	C = WindowConsole(PP.Player.Console);
	if (C == None)
	{
		log("[UTBomb menu] console is not a WindowConsole");
		return;
	}

	RestoreMenus();      // in case an earlier call left something hidden

	if (!C.bCreatedRoot || C.Root == None)
		C.CreateRootWindow(None);
	if (C.Root == None)
	{
		log("[UTBomb menu] no root window");
		return;
	}

	if (C.Root.FindChildWindow(class'BombClassWindow') == None)
	{
		log("[UTBomb menu] creating class window, root size " $ C.Root.WinWidth $ " x " $ C.Root.WinHeight);
		C.Root.CreateWindow(class'BombClassWindow', 40, 30, 490, MenuHeight());
	}
	else
		log("[UTBomb menu] class window already exists");

	C.bQuickKeyEnable = false;
	C.LaunchUWindow();

	// the class window should be alone on screen, without the normal menu bar behind it
	HideOtherWindows(C.Root);
}

simulated function BombHUD FindHud()
{
	local BombHUD H;

	foreach AllActors(class'BombHUD', H)
		return H;
	return None;
}

// Hides every window on the root except our own. They are remembered and shown
// again when our window is gone (see Tick).
simulated function HideOtherWindows(UWindowRootWindow R)
{
	local UWindowWindow W;

	HiddenCount = 0;
	for (W = R.LastChildWindow; W != None; W = W.PrevSiblingWindow)
	{
		if (W.Class == class'BombClassWindow' || W.Class == class'BombHudWindow')
			continue;
		if (W.bWindowVisible && HiddenCount < 8)
		{
			HiddenWin[HiddenCount] = W;
			HiddenCount++;
			W.HideWindow();
		}
	}
}

simulated function RestoreMenus()
{
	local int i;

	for (i = 0; i < HiddenCount; i++)
	{
		if (HiddenWin[i] != None)
			HiddenWin[i].ShowWindow();
		HiddenWin[i] = None;
	}
	HiddenCount = 0;
}

// Watches for our window going away (Done button, Escape, anything) and then
// gives the normal menu back.
simulated function int FindSkSlot(Pawn P)
{
	local int i;

	for (i = 0; i < 32; i++)
	{
		if (SkPawn[i] == P)
			return i;
	}
	for (i = 0; i < 32; i++)
	{
		if (SkPawn[i] == None)
			return i;
	}
	i = SkNext;
	SkNext = (SkNext + 1) % 32;
	return i;
}

simulated function Texture LoadSkinTex(string N)
{
	if (N == "")
		return None;
	return Texture(DynamicLoadObject(N, class'Texture', true));
}

// Sets one skin element: the first name, or the second if the first does not exist.
simulated function SetSkinEl(Pawn P, int idx, string Primary, string Fallback)
{
	local Texture Tex;

	Tex = LoadSkinTex(Primary);
	if (Tex == None)
		Tex = LoadSkinTex(Fallback);
	P.MultiSkins[idx] = Tex;
}

// Which skin layout a body uses: 1 male commando, 2 male soldier, 3 female
// commando, 4 female soldier, 5 boss, 0 unknown.
simulated function int BodyKind(string Model)
{
	local string U;

	U = Caps(Model);
	if (InStr(U, "TMALE1") >= 0)
		return 1;
	if (InStr(U, "TMALE2") >= 0)
		return 2;
	if (InStr(U, "TFEMALE1") >= 0)
		return 3;
	if (InStr(U, "TFEMALE2") >= 0)
		return 4;
	if (InStr(U, "TBOSS") >= 0)
		return 5;
	return 0;
}

// Puts the textures of a skin pack on a pawn, element by element, with the names
// the packs use (base1 ... base4, team versions base1T_0, the face base4Name).
// Done by hand because the game's own routine did not find these face textures.
simulated function ApplyPackSkin(Pawn P, int kind, string SkinFull, string FaceFull, int team)
{
	local string Pkg, Base, FPkg, FItem, Tm;
	local int dot;

	dot = InStr(SkinFull, ".");
	Pkg = Left(SkinFull, dot + 1);
	Base = Mid(SkinFull, dot + 1);
	FPkg = Pkg;
	FItem = "";
	if (FaceFull != "")
	{
		dot = InStr(FaceFull, ".");
		if (dot < 0)
			FItem = FaceFull;
		else
		{
			FPkg = Left(FaceFull, dot + 1);
			FItem = Mid(FaceFull, dot + 1);
		}
	}
	Tm = "";
	if (team >= 0 && team < 4)
		Tm = "T_" $ team;

	if (kind == 1)
	{
		// male commando: the face is element 1, the team colours are on 2 and 3
		SetSkinEl(P, 0, Pkg $ Base $ "1", "");
		SetSkinEl(P, 1, FPkg $ Base $ "2" $ FItem, Pkg $ Base $ "2");
		SetSkinEl(P, 2, Pkg $ Base $ "3" $ Tm, Pkg $ Base $ "3");
		SetSkinEl(P, 3, Pkg $ Base $ "4" $ Tm, Pkg $ Base $ "4");
	}
	else if (kind == 3)
	{
		// female commando: no element 2
		SetSkinEl(P, 0, Pkg $ Base $ "1" $ Tm, Pkg $ Base $ "1");
		SetSkinEl(P, 1, Pkg $ Base $ "2" $ Tm, Pkg $ Base $ "2");
		SetSkinEl(P, 3, FPkg $ Base $ "4" $ FItem, Pkg $ Base $ "4");
	}
	else if (kind == 5)
	{
		// boss: four elements, all with team colours, no face
		SetSkinEl(P, 0, Pkg $ Base $ "1" $ Tm, Pkg $ Base $ "1");
		SetSkinEl(P, 1, Pkg $ Base $ "2" $ Tm, Pkg $ Base $ "2");
		SetSkinEl(P, 2, Pkg $ Base $ "3" $ Tm, Pkg $ Base $ "3");
		SetSkinEl(P, 3, Pkg $ Base $ "4" $ Tm, Pkg $ Base $ "4");
	}
	else
	{
		// soldiers (male and female)
		SetSkinEl(P, 0, Pkg $ Base $ "1" $ Tm, Pkg $ Base $ "1");
		SetSkinEl(P, 1, Pkg $ Base $ "2" $ Tm, Pkg $ Base $ "2");
		SetSkinEl(P, 2, Pkg $ Base $ "3", "");
		SetSkinEl(P, 3, FPkg $ Base $ "4" $ FItem, Pkg $ Base $ "4");
	}
}

// Puts the skin of class c on a pawn. A class without a skin (like Default) gives
// the pawn its own look back.
simulated function DressPawn(Pawn P, int k, int c)
{
	local class<PlayerPawn> MC;
	local Texture OldTalk;
	local int i, kind;

	if (c >= 0 && c <= 15 && SkInfo.ClsSkin[c] != "" && SkInfo.ClsModel[c] != "")
	{
		MC = class<PlayerPawn>(DynamicLoadObject(SkInfo.ClsModel[c], class'Class', true));
		if (MC != None)
		{
			P.Mesh = MC.Default.Mesh;
			for (i = 0; i < 8; i++)
				P.MultiSkins[i] = None;
			kind = BodyKind(SkInfo.ClsModel[c]);
			if (kind > 0)
			{
				ApplyPackSkin(P, kind, SkInfo.ClsSkin[c], SkInfo.ClsFace[c], P.PlayerReplicationInfo.Team);
				if (bSkinDebug)
					log("[UTBomb skin] elements: 0=" $ P.MultiSkins[0] $ " 1=" $ P.MultiSkins[1] $ " 2=" $ P.MultiSkins[2] $ " 3=" $ P.MultiSkins[3]);
			}
			else
			{
				// a body we do not know: let the game do it
				OldTalk = P.PlayerReplicationInfo.TalkTexture;
				MC.static.SetMultiSkin(P, SkInfo.ClsSkin[c], SkInfo.ClsFace[c], P.PlayerReplicationInfo.Team);
				P.PlayerReplicationInfo.TalkTexture = OldTalk;
			}
			return;
		}
	}
	P.Mesh = SkOwnMesh[k];
	P.Skin = SkOwnSkin[k];
	for (i = 0; i < 8; i++)
		P.MultiSkins[i] = SkOwnMulti[k * 8 + i];
}

simulated function ApplySkins()
{
	local BombInfo Inf;
	local Pawn P;
	local int i, k, c, id, nPawns, nEntries;

	if (SkInfo == None)
	{
		foreach AllActors(class'BombInfo', Inf)
		{
			SkInfo = Inf;
			break;
		}
	}
	if (SkInfo == None)
	{
		if (bSkinDebug && SkLogTimer <= 0)
		{
			log("[UTBomb skin] no BombInfo found yet");
			SkLogTimer = 10;
		}
		return;
	}

	// a short summary every 10 seconds
	if (bSkinDebug && SkLogTimer <= 0)
	{
		nPawns = 0;
		nEntries = 0;
		for (i = 0; i < 32; i++)
		{
			if (SkInfo.SkinCls[i] >= 0)
				nEntries++;
		}
		foreach AllActors(class'Pawn', P)
		{
			if (P.PlayerReplicationInfo != None)
				nPawns++;
		}
		log("[UTBomb skin] summary: pawns with a player record=" $ nPawns $ ", class entries from the server=" $ nEntries $ ", classes with a skin: 0=[" $ SkInfo.ClsSkin[0] $ "] 1=[" $ SkInfo.ClsSkin[1] $ "] 3=[" $ SkInfo.ClsSkin[3] $ "] 6=[" $ SkInfo.ClsSkin[6] $ "]");
		SkLogTimer = 10;
	}

	foreach AllActors(class'Pawn', P)
	{
		if (P.PlayerReplicationInfo == None || P.PlayerReplicationInfo.bIsSpectator || P.Mesh == None)
			continue;
		id = P.PlayerReplicationInfo.PlayerID;
		c = -1;
		for (i = 0; i < 32; i++)
		{
			if (SkInfo.SkinPID[i] == id)
			{
				c = SkInfo.SkinCls[i];
				break;
			}
		}
		if (c < 0)
			continue;

		k = FindSkSlot(P);
		if (SkPawn[k] != P)
		{
			// the first time we see this pawn: remember its own look
			if (P.MultiSkins[1] == None && P.Skin == None)
			{
				if (bSkinDebug)
					log("[UTBomb skin] " $ P.PlayerReplicationInfo.PlayerName $ ": has no skin textures yet, waiting");
				continue;
			}
			SkPawn[k] = P;
			SkClass[k] = -2;
			SkAge[k] = 0;
			SkOwnMesh[k] = P.Mesh;
			SkOwnSkin[k] = P.Skin;
			for (i = 0; i < 8; i++)
				SkOwnMulti[k * 8 + i] = P.MultiSkins[i];
				}
		if (SkClass[k] != c || SkAge[k] > 5.0)
		{
			if (bSkinDebug && SkClass[k] != c)
				log("[UTBomb skin] dressing " $ P.PlayerReplicationInfo.PlayerName $ " (id " $ id $ ") as class " $ c $ ", skin [" $ SkInfo.ClsSkin[c] $ "], body [" $ SkInfo.ClsModel[c] $ "], team " $ P.PlayerReplicationInfo.Team);
			DressPawn(P, k, c);
			SkClass[k] = c;
			SkAge[k] = 0;
		}
	}
}

simulated event Tick(float Delta)
{
	local PlayerPawn PP;
	local WindowConsole C;
	local int i;

	if (Level.NetMode == NM_DedicatedServer)
		return;

	if (bSkinDebug && !bSkLoggedStart)
	{
		bSkLoggedStart = true;
		log("[UTBomb skin] the client helper is running (version with client-side class skins)");
	}
	if (SkLogTimer > 0)
		SkLogTimer -= Delta;

	// class skins on every player in view, twice a second
	SkTimer += Delta;
	if (SkTimer >= 0.5)
	{
		for (i = 0; i < 32; i++)
			SkAge[i] += SkTimer;
		SkTimer = 0;
		ApplySkins();
	}

	if (HiddenCount == 0)
		return;
	PP = PlayerPawn(Owner);
	if (PP == None || PP.Player == None)
		return;
	C = WindowConsole(PP.Player.Console);
	if (C == None || C.Root == None || !C.bUWindowActive)
	{
		RestoreMenus();
		return;
	}
	if (C.Root.FindChildWindow(class'BombClassWindow') != None
		|| C.Root.FindChildWindow(class'BombHudWindow') != None)
		return;

	// both of our windows are gone but the menu system is still open: back to the game
	RestoreMenus();
	C.CloseUWindow();
}

// Start of a round: open the class menu, unless the player turned that off.
simulated function ClientAutoMenu()
{
	local BombHUD H;

	if (Level.NetMode == NM_DedicatedServer)
		return;
	H = FindHud();
	if (H != None && H.AutoMenu == 0)
		return;
	ClientOpenMenu();
}

// The round goes live: close our windows and leave the menu system, but only if
// our window was open (never close a menu the player opened for something else).
simulated function ClientCloseMenu()
{
	local PlayerPawn PP;
	local WindowConsole C;
	local UWindowWindow W;
	local bool bClosed;

	if (Level.NetMode == NM_DedicatedServer)
		return;
	PP = PlayerPawn(Owner);
	if (PP == None || PP.Player == None)
		return;
	C = WindowConsole(PP.Player.Console);
	if (C == None || !C.bCreatedRoot || C.Root == None)
		return;

	W = C.Root.FindChildWindow(class'BombHudWindow');
	if (W != None)
	{
		W.Close();
		bClosed = true;
	}
	W = C.Root.FindChildWindow(class'BombClassWindow');
	if (W != None)
	{
		W.Close();
		bClosed = true;
	}
	if (bClosed)
	{
		RestoreMenus();
		C.CloseUWindow();
	}
}

defaultproperties
{
	bSkinDebug=False
	TransLeft=-1
	bAlwaysRelevant=False
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=5.0
}
