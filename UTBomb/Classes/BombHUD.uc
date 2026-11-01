//=============================================================================
// BombHUD.uc
// Client-side HUD overlay:
//   - a top bar with the team scores (rounds won), the round / bomb timer and
//     the players of both teams as portraits (dimmed when dead), or as plain
//     text if you prefer
//   - a "bomb planted" banner with the countdown
//   - markers in the world for the bomb site, carrier, dropped and planted bomb
// Registers itself with the local player's HUD as a HUD mutator.
//
// PLAYER SETTINGS live in System\UTBombClient.ini, section [UTBomb.BombHUD].
// Every number is -1 by default, which means "use the server's default".
// Put a real value in to override it on your own machine only.
//=============================================================================
class BombHUD extends Mutator config(UTBombClient);

// -1 = server default
var() config int BarMode;        // 0 off, 1 portraits, 2 text
var() config int BarScale;       // percent, 100 = normal
var() config int BarY;           // pixels from the top of the screen
var() config int BarFont;        // 0 small, 1 medium, 2 big, 3 huge
var() config int MaxPortraits;   // players shown per team, 1 to 8
var() config int ShowNames;      // 0 off, 1 on
var() config int ShowBanner;     // 0 off, 1 on
var() config int BannerFont;
var() config int BannerY;
var() config int ShowMarkers;    // 0 off, 1 on
var() config int MarkerFont;
var() config int ShowDistance;   // 0 off, 1 on
var() config int ShowTrans;      // translocator counter: 0 off, 1 on
var() config int AutoMenu;       // open the class menu at the start of each round: 0 off, anything else on
var() config int TransFont;      // 0 small ... 3 huge
var() config int TransX;         // percent from the left, the text ends there
var() config int TransY;         // percent from the top
// optional texture names, Package.Texture. Empty = automatic / none.
var() config string BoxTexture;      // solid texture used for the translucent boxes
var() config string ScoreIconRed;    // e.g. your own skull for the red score box
var() config string ScoreIconBlue;

var bool       bRegistered;
var PlayerPawn LocalPP;
var BombInfo   BInfo;
var Texture    PortTex[16];       // class pictures for the top bar
var float      PortRetry[16];
var BombClient MyClient;
var bool       bTexTried;
var Texture    BoxTex;
var Texture    IconR;
var Texture    IconB;

simulated function Tick(float DeltaTime)
{
	local PlayerPawn P;

	if (bRegistered || Level.NetMode == NM_DedicatedServer)
		return;

	foreach AllActors(class'PlayerPawn', P)
	{
		if (Viewport(P.Player) != None && P.myHUD != None)
		{
			NextHUDMutator = P.myHUD.HUDMutator;
			P.myHUD.HUDMutator = Self;
			bHUDMutator = true;
			LocalPP = P;
			bRegistered = true;
			return;
		}
	}
}

simulated function FindInfo()
{
	local BombInfo B;

	foreach AllActors(class'BombInfo', B)
	{
		BInfo = B;
		return;
	}
}

simulated function LoadTextures()
{
	if (bTexTried)
		return;
	bTexTried = true;

	if (BoxTexture != "")
		BoxTex = Texture(DynamicLoadObject(BoxTexture, class'Texture', true));
	if (BoxTex == None)
		BoxTex = Texture(DynamicLoadObject("Engine.WhiteSquareTexture", class'Texture', true));
	if (BoxTex == None)
		BoxTex = Texture(DynamicLoadObject("UWindow.WhiteTexture", class'Texture', true));
	if (BoxTex == None)
		BoxTex = Texture(DynamicLoadObject("UWindow.BlackTexture", class'Texture', true));
	log("[UTBomb HUD] box texture: " $ BoxTex);

	if (ScoreIconRed != "")
		IconR = Texture(DynamicLoadObject(ScoreIconRed, class'Texture', true));
	if (ScoreIconBlue != "")
		IconB = Texture(DynamicLoadObject(ScoreIconBlue, class'Texture', true));
}

simulated function SetCol(Canvas C, int R, int G, int B)
{
	C.DrawColor.R = R;
	C.DrawColor.G = G;
	C.DrawColor.B = B;
}

// player value if set, otherwise the server's default
simulated function int Eff(int PlayerVal, int ServerVal)
{
	if (PlayerVal >= 0)
		return PlayerVal;
	return ServerVal;
}

simulated function Font PickFont(Canvas C, int Size)
{
	local ChallengeHUD CH;

	CH = ChallengeHUD(LocalPP.myHUD);
	if (CH != None && CH.MyFonts != None)
	{
		if (Size >= 3)
			return CH.MyFonts.GetHugeFont(C.ClipX);
		if (Size == 2)
			return CH.MyFonts.GetBigFont(C.ClipX);
		if (Size == 1)
			return CH.MyFonts.GetMediumFont(C.ClipX);
		return CH.MyFonts.GetSmallFont(C.ClipX);
	}
	if (Size >= 3)
		return C.LargeFont;
	if (Size == 2)
		return C.BigFont;
	if (Size == 1)
		return C.MedFont;
	return C.SmallFont;
}

// integer maths only: the % operator returns a float in UnrealScript
simulated function string TimeStr(int S)
{
	local int M, R;

	if (S < 0)
		S = 0;
	M = S / 60;
	R = S - M * 60;
	if (R < 10)
		return M $ ":0" $ R;
	return M $ ":" $ R;
}

simulated function bool TimerVisible(int myTeam)
{
	if (myTeam == 0)
		return BInfo.bTimerVis0;
	if (myTeam == 1)
		return BInfo.bTimerVis1;
	return (BInfo.bTimerVis0 && BInfo.bTimerVis1);
}

simulated function bool IsDead(PlayerReplicationInfo PRI)
{
	local int i;

	for (i = 0; i < 32; i++)
	{
		if (BInfo.DeadID[i] == PRI.PlayerID + 1)
			return true;
	}
	return false;
}

// World position to screen position. Returns false if the point is behind us.
simulated function bool Project(Canvas C, vector W, out float SX, out float SY)
{
	local vector AX, AY, AZ, D, CamLoc;
	local rotator CamRot;
	local actor ViewActor;
	local float fx, Scale;

	LocalPP.PlayerCalcView(ViewActor, CamLoc, CamRot);
	GetAxes(CamRot, AX, AY, AZ);
	D = W - CamLoc;
	fx = D Dot AX;
	if (fx < 1.0)
	{
		if ((D Dot AY) >= 0.0)
			SX = C.ClipX - 40;
		else
			SX = 40;
		SY = C.ClipY - 40;
		return false;
	}
	Scale = (C.ClipX * 0.5) / Tan(LocalPP.FOVAngle * 0.5 * Pi / 180.0);
	SX = C.ClipX * 0.5 + (D Dot AY) / fx * Scale;
	SY = C.ClipY * 0.5 - (D Dot AZ) / fx * Scale;
	SX = FClamp(SX, 40.0, C.ClipX - 40.0);
	SY = FClamp(SY, 40.0, C.ClipY - 40.0);
	return true;
}

simulated function DrawMarker(Canvas C, vector W, string Label, bool bDist, int R, int G, int B)
{
	local float SX, SY, TW, TH;
	local string S;

	Project(C, W, SX, SY);
	S = Label;
	if (bDist && ShowDistance != 0)
		S = S $ " " $ int(VSize(W - LocalPP.Location) / 52.0) $ "m";
	C.Style = 1;
	C.Font = PickFont(C, Eff(MarkerFont, BInfo.HudMarkerFont));
	SetCol(C, R, G, B);
	C.StrLen(S, TW, TH);
	C.SetPos(SX - TW * 0.5, SY - TH * 0.5);
	C.DrawText(S);
}

// text centred inside a rectangle
simulated function DrawIn(Canvas C, string S, float X, float Y, float W, float H)
{
	local float TW, TH;

	C.StrLen(S, TW, TH);
	C.SetPos(X + (W - TW) * 0.5, Y + (H - TH) * 0.5);
	C.DrawText(S);
}

simulated function DrawCentered(Canvas C, string S, float Y)
{
	DrawIn(C, S, 0, Y, C.ClipX, 0);
}

// translucent coloured box
simulated function DrawBox(Canvas C, float X, float Y, float W, float H, int R, int G, int B)
{
	if (BoxTex == None)
		return;
	C.Style = 3;
	SetCol(C, R, G, B);
	C.SetPos(X, Y);
	C.DrawTile(BoxTex, W, H, 0, 0, BoxTex.USize, BoxTex.VSize);
	C.Style = 1;
}

// The picture of a class: Portrait=, or the face picture of the skin (base 5 + face).
// Tried again every few seconds until it loads (the data comes from the server).
simulated function Texture ClassPortrait(int c)
{
	local string Pkg, Base, FPkg, FItem;
	local int p;

	if (PortTex[c] != None)
		return PortTex[c];
	if (Level.TimeSeconds < PortRetry[c])
		return None;
	PortRetry[c] = Level.TimeSeconds + 5.0;

	if (BInfo.ClsPortrait[c] != "")
	{
		PortTex[c] = Texture(DynamicLoadObject(BInfo.ClsPortrait[c], class'Texture', true));
		return PortTex[c];
	}
	if (BInfo.ClsSkin[c] == "" || BInfo.ClsFace[c] == "")
		return None;
	p = InStr(BInfo.ClsSkin[c], ".");
	if (p < 0)
		return None;
	Pkg = Left(BInfo.ClsSkin[c], p);
	Base = Mid(BInfo.ClsSkin[c], p + 1);
	p = InStr(BInfo.ClsFace[c], ".");
	if (p < 0)
	{
		FPkg = Pkg;
		FItem = BInfo.ClsFace[c];
	}
	else
	{
		FPkg = Left(BInfo.ClsFace[c], p);
		FItem = Mid(BInfo.ClsFace[c], p + 1);
	}
	PortTex[c] = Texture(DynamicLoadObject(FPkg $ "." $ Base $ "5" $ FItem, class'Texture', true));
	return PortTex[c];
}

// The picture for a player: the picture of their class if it has one, otherwise
// the player's own.
simulated function Texture PortraitFor(PlayerReplicationInfo PRI)
{
	local int i, c, k;
	local Texture T;

	c = -1;
	k = -1;
	for (i = 0; i < 32; i++)
	{
		if (BInfo.SkinPID[i] == PRI.PlayerID)
		{
			c = BInfo.SkinCls[i];
			k = i;
			break;
		}
	}
	if (c >= 0 && c <= 15)
	{
		T = ClassPortrait(c);
		if (T != None)
			return T;
	}
	// the player's own picture: from the server, because the copy on this PC is
	// cleared when the player comes into view
	if (k >= 0 && BInfo.SkinTex[k] != None)
		return BInfo.SkinTex[k];
	return PRI.TalkTexture;
}

simulated function DrawPortrait(Canvas C, PlayerReplicationInfo PRI, float X, float Y, float S, bool bAtkTeam)
{
	local Texture T;
	local bool bDead;
	local float TW, TH;
	local string N;

	bDead = IsDead(PRI);
	if (PRI.Team == 0)
		DrawBox(C, X - 2, Y - 2, S + 4, S + 4, 150, 30, 30);
	else
		DrawBox(C, X - 2, Y - 2, S + 4, S + 4, 30, 80, 160);

	T = PortraitFor(PRI);
	if (T != None)
	{
		if (bDead)
		{
			C.Style = 3;
			SetCol(C, 60, 60, 60);
		}
		else
		{
			C.Style = 1;
			SetCol(C, 255, 255, 255);
		}
		C.SetPos(X, Y);
		C.DrawTile(T, S, S, 0, 0, T.USize, T.VSize);
		C.Style = 1;
	}

	if (!bDead && bAtkTeam && BInfo.CarrierID == PRI.PlayerID + 1)
	{
		C.Font = PickFont(C, 0);
		SetCol(C, 255, 140, 40);
		DrawIn(C, "BOMB", X, Y + S - 14, S, 14);
	}

	if (Eff(ShowNames, BInfo.HudShowNames) != 0)
	{
		N = Left(PRI.PlayerName, 9);
		C.Font = PickFont(C, 0);
		if (bDead)
			SetCol(C, 120, 120, 120);
		else
			SetCol(C, 255, 255, 255);
		C.StrLen(N, TW, TH);
		C.SetPos(X + (S - TW) * 0.5, Y + S + 1);
		C.DrawText(N);
	}
}

simulated function bool IsReady(PlayerReplicationInfo PRI)
{
	local int i;

	for (i = 0; i < 32; i++)
	{
		if (BInfo.ReadyID[i] == PRI.PlayerID + 1)
			return true;
	}
	return false;
}

simulated function string MainTimeText(int myTeam)
{
	if (BInfo.RoundState == 0)
	{
		if (BInfo.WarmState == 2)
			return string(BInfo.WarmCountdown);
		if (BInfo.WarmState == 1)
			return "READY?";
		return "--:--";
	}
	if (BInfo.bPlanted && !TimerVisible(myTeam))
		return "BOMB";
	return TimeStr(BInfo.SecondsLeft);
}

simulated function string SideText()
{
	local string S;

	if (BInfo.RoundState == 0)
	{
		if (BInfo.WarmState != 0)
			return "Warm-up  |  ready " $ BInfo.WarmReady $ "/" $ BInfo.WarmTotal;
		return "Waiting for players";
	}
	if (BInfo.AttackTeam == 0)
		S = "RED attacks";
	else
		S = "BLUE attacks";
	if (BInfo.bOT)
		return "Round " $ BInfo.RoundNum $ "  |  OVERTIME " $ BInfo.OTScore0 $ "-" $ BInfo.OTScore1 $ "  |  " $ S;
	return "Round " $ BInfo.RoundNum $ "  |  " $ S;
}

simulated function DrawPortraitBar(Canvas C, int myTeam)
{
	local PlayerReplicationInfo PRI;
	local PlayerReplicationInfo L0[8], L1[8];
	local int n0, n1, Slots, i;
	local float Sc, PS, Gap, BoxW, TimerW, CX, Y, X;
	local bool bAtk;

	Slots = Min(Max(Eff(MaxPortraits, BInfo.HudMaxPort), 1), 8);
	foreach AllActors(class'PlayerReplicationInfo', PRI)
	{
		if (PRI.bIsSpectator)
			continue;
		if (PRI.Team == 0 && n0 < Slots)
		{
			L0[n0] = PRI;
			n0++;
		}
		else if (PRI.Team == 1 && n1 < Slots)
		{
			L1[n1] = PRI;
			n1++;
		}
	}

	Sc = (C.ClipX / 1024.0) * Eff(BarScale, BInfo.HudBarScale) / 100.0;
	PS = 56.0 * Sc;
	Gap = 4.0 * Sc;
	BoxW = 72.0 * Sc;
	TimerW = 120.0 * Sc;
	CX = C.ClipX * 0.5;
	Y = Eff(BarY, BInfo.HudBarY);
	bAtk = (myTeam == BInfo.AttackTeam);

	// timer in the middle
	DrawBox(C, CX - TimerW * 0.5, Y, TimerW, PS, 0, 0, 0);
	C.Style = 1;
	C.Font = PickFont(C, Eff(BarFont, BInfo.HudBarFont));
	if (BInfo.bPlanted)
		SetCol(C, 255, 60, 60);
	else
		SetCol(C, 255, 255, 255);
	DrawIn(C, MainTimeText(myTeam), CX - TimerW * 0.5, Y, TimerW, PS * 0.7);
	C.Font = PickFont(C, 0);
	SetCol(C, 220, 220, 220);
	DrawIn(C, SideText(), CX - TimerW * 0.5, Y + PS * 0.62, TimerW, PS * 0.38);

	// red team (left)
	for (i = 0; i < n0; i++)
	{
		X = CX - TimerW * 0.5 - (n0 - i) * (PS + Gap);
		DrawPortrait(C, L0[i], X, Y, PS, bAtk && BInfo.AttackTeam == 0);
	}
	X = CX - TimerW * 0.5 - n0 * (PS + Gap) - BoxW - Gap;
	DrawBox(C, X, Y, BoxW, PS, 150, 30, 30);
	C.Style = 1;
	C.Font = PickFont(C, Eff(BarFont, BInfo.HudBarFont));
	SetCol(C, 255, 255, 255);
	if (IconR != None)
	{
		C.SetPos(X + 2, Y + 2);
		C.DrawTile(IconR, PS - 4, PS - 4, 0, 0, IconR.USize, IconR.VSize);
		DrawIn(C, string(BInfo.Score0), X + PS * 0.8, Y, BoxW - PS * 0.8, PS);
	}
	else
		DrawIn(C, string(BInfo.Score0), X, Y, BoxW, PS);

	// blue team (right)
	for (i = 0; i < n1; i++)
	{
		X = CX + TimerW * 0.5 + Gap + i * (PS + Gap);
		DrawPortrait(C, L1[i], X, Y, PS, bAtk && BInfo.AttackTeam == 1);
	}
	X = CX + TimerW * 0.5 + Gap + n1 * (PS + Gap);
	DrawBox(C, X, Y, BoxW, PS, 30, 80, 160);
	C.Style = 1;
	C.Font = PickFont(C, Eff(BarFont, BInfo.HudBarFont));
	SetCol(C, 255, 255, 255);
	if (IconB != None)
	{
		C.SetPos(X + 2, Y + 2);
		C.DrawTile(IconB, PS - 4, PS - 4, 0, 0, IconB.USize, IconB.VSize);
		DrawIn(C, string(BInfo.Score1), X + PS * 0.8, Y, BoxW - PS * 0.8, PS);
	}
	else
		DrawIn(C, string(BInfo.Score1), X, Y, BoxW, PS);
}

simulated function DrawTextBar(Canvas C, int myTeam)
{
	local string L1, L2;
	local float Y;

	Y = Eff(BarY, BInfo.HudBarY);
	L1 = "RED " $ BInfo.Score0 $ "    " $ MainTimeText(myTeam) $ "    " $ BInfo.Score1 $ " BLUE";
	L2 = SideText() $ "  |  alive " $ BInfo.Alive0 $ " v " $ BInfo.Alive1;

	C.Style = 1;
	C.Font = PickFont(C, Eff(BarFont, BInfo.HudBarFont));
	if (BInfo.bPlanted)
		SetCol(C, 255, 60, 60);
	else
		SetCol(C, 255, 255, 255);
	DrawCentered(C, L1, Y);

	C.Font = PickFont(C, 1);
	SetCol(C, 220, 220, 220);
	DrawCentered(C, L2, Y + 34);
}

simulated function DrawBanner(Canvas C, bool bShowTime)
{
	local string S;

	S = "BOMB PLANTED";
	if (bShowTime)
		S = S $ "  " $ TimeStr(BInfo.SecondsLeft);
	C.Style = 1;
	C.Font = PickFont(C, Eff(BannerFont, BInfo.HudBannerFont));
	SetCol(C, 255, 60, 60);
	DrawCentered(C, S, Eff(BannerY, BInfo.HudBannerY));
}

simulated function DrawDropped(Canvas C)
{
	C.Style = 1;
	C.Font = PickFont(C, Eff(BannerFont, BInfo.HudBannerFont));
	SetCol(C, 255, 140, 40);
	DrawCentered(C, "THE BOMB IS DROPPED - PICK IT UP", Eff(BannerY, BInfo.HudBannerY));
}

simulated function DrawReason(Canvas C, float Y)
{
	if (BInfo.WarmState == 1 && BInfo.WarmReason != "")
	{
		C.Font = PickFont(C, 1);
		SetCol(C, 255, 120, 120);
		DrawCentered(C, "Cannot start yet: " $ BInfo.WarmReason, Y);
	}
}

simulated function DrawWarmup(Canvas C)
{
	local float Y;

	C.Style = 1;
	Y = Eff(BannerY, BInfo.HudBannerY);
	C.Font = PickFont(C, Eff(BannerFont, BInfo.HudBannerFont));
	if (BInfo.WarmState == 2)
	{
		SetCol(C, 80, 255, 80);
		DrawCentered(C, "MATCH STARTS IN " $ BInfo.WarmCountdown, Y);
	}
	else if (IsReady(LocalPP.PlayerReplicationInfo))
	{
		SetCol(C, 80, 255, 80);
		DrawCentered(C, "YOU ARE READY  (" $ BInfo.WarmReady $ "/" $ BInfo.WarmTotal $ ")", Y);
		DrawReason(C, Y + 40);
	}
	else
	{
		SetCol(C, 255, 200, 60);
		DrawCentered(C, "WARM-UP: ready up!  (" $ BInfo.WarmReady $ "/" $ BInfo.WarmTotal $ ")", Y);
		C.Font = PickFont(C, 1);
		SetCol(C, 220, 220, 220);
		DrawCentered(C, "Open the class menu and press Ready, or type: ready", Y + 40);
		DrawReason(C, Y + 62);
	}
}

simulated function FindClient()
{
	local BombClient K;

	foreach AllActors(class'BombClient', K)
	{
		if (K.Owner == LocalPP)
		{
			MyClient = K;
			return;
		}
	}
}

// "TRANSLOCATOR 4": how many translocations are left this round. Only shown to
// players whose class has a limited Translocator.
simulated function DrawTrans(Canvas C)
{
	local string S;
	local float TW, TH;

	if (MyClient == None)
		FindClient();
	if (MyClient == None || MyClient.TransLeft < 0 || LocalPP.Health <= 0)
		return;

	S = "TRANSLOCATOR  " $ MyClient.TransLeft;
	C.Style = 1;
	C.Font = PickFont(C, Eff(TransFont, BInfo.HudTransFont));
	if (MyClient.TransLeft == 0)
		SetCol(C, 255, 70, 70);
	else
		SetCol(C, 255, 255, 255);
	C.StrLen(S, TW, TH);
	C.SetPos(C.ClipX * Eff(TransX, BInfo.HudTransX) / 100.0 - TW, C.ClipY * Eff(TransY, BInfo.HudTransY) / 100.0);
	C.DrawText(S);
}

simulated function DrawAll(Canvas C)
{
	local int myTeam, i, Mode;
	local bool bAtk, bVis;
	local string Lbl;
	local vector Up;

	LoadTextures();
	myTeam = LocalPP.PlayerReplicationInfo.Team;

	Mode = Eff(BarMode, BInfo.HudBarMode);
	if (Mode == 1)
		DrawPortraitBar(C, myTeam);
	else if (Mode == 2)
		DrawTextBar(C, myTeam);

	if (ShowTrans != 0)
		DrawTrans(C);

	if (BInfo.RoundState == 0)
	{
		if (BInfo.WarmState != 0 && ShowBanner != 0)
			DrawWarmup(C);
		return;
	}

	bAtk = (myTeam == BInfo.AttackTeam);
	Up = vect(0, 0, 60);

	if (BInfo.bPlanted)
	{
		bVis = TimerVisible(myTeam);
		if (ShowBanner != 0)
			DrawBanner(C, bVis);
		if (ShowMarkers != 0 && (bAtk || BInfo.bDefSeeBomb || myTeam > 1))
		{
			if (bVis)
				Lbl = string(BInfo.SecondsLeft);
			else
				Lbl = "BOMB";
			DrawMarker(C, BInfo.PlantLoc + Up, Lbl, false, 255, 60, 60);
		}
		return;
	}

	if (ShowMarkers == 0 || myTeam > 1)
		return;

	for (i = 0; i < BInfo.NumSites; i++)
		DrawMarker(C, BInfo.SiteLoc[i] + Up, "SITE " $ BInfo.SiteName[i], true, 255, 220, 60);

	if (bAtk && BInfo.RoundState == 2)
	{
		if (BInfo.bCarried && VSize(BInfo.CarrierLoc - LocalPP.Location) > 80.0)
			DrawMarker(C, BInfo.CarrierLoc + Up, "BOMB CARRIER", true, 255, 140, 40);
		if (BInfo.bDropped)
		{
			if (ShowBanner != 0)
				DrawDropped(C);
			DrawMarker(C, BInfo.DropLoc + Up, "BOMB DROPPED", true, 255, 60, 60);
		}
	}
}

simulated function PostRender(Canvas C)
{
	if (LocalPP != None && LocalPP.PlayerReplicationInfo != None)
	{
		if (BInfo == None)
			FindInfo();
		if (BInfo != None)
			DrawAll(C);
		C.Style = 1;
		SetCol(C, 255, 255, 255);
	}
	if (NextHUDMutator != None)
		NextHUDMutator.PostRender(C);
}

defaultproperties
{
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
	BarMode=-1
	BarScale=-1
	BarY=-1
	BarFont=-1
	MaxPortraits=-1
	ShowNames=-1
	ShowBanner=-1
	BannerFont=-1
	BannerY=-1
	ShowMarkers=-1
	MarkerFont=-1
	ShowDistance=-1
	ShowTrans=-1
	AutoMenu=-1
	TransFont=-1
	TransX=-1
	TransY=-1
}
