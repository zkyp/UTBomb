//=============================================================================
// BombClassClient.uc
// Contents of the class menu: one card per class (stock weapon icons, or a
// custom picture if the class line has Icon=Package.Texture), plus wildcard
// buttons. Buttons just run the same "mutate" commands you can type.
//=============================================================================
class BombClassClient extends UWindowDialogClientWindow;

const CardW = 232;
const CardH = 80;

var BombInfo   BI;
var BombClient BC;
var UWindowSmallButton ClassBtn[16];
var UWindowSmallButton DoneBtn;
var UWindowSmallButton HudBtn;
var UWindowSmallButton T1Btn;
var UWindowCheckbox    AutoC;
var UWindowSmallButton T2Btn;
var UWindowSmallButton T3Btn;
var UWindowSmallButton ReadyBtn;
var Texture WeapTex[48];
var Texture ClassImg[16];
var Texture CardBG;
var int WildY;

function BombInfo GetInfo()
{
	local BombInfo B;

	foreach GetPlayerOwner().AllActors(class'BombInfo', B)
		return B;
	return None;
}

function BombClient GetClient()
{
	local BombClient K;

	foreach GetPlayerOwner().AllActors(class'BombClient', K)
	{
		if (K.Owner == GetPlayerOwner())
			return K;
	}
	return None;
}

function LoadTextures()
{
	local int i;
	local class<Weapon> WC;

	CardBG = Texture(DynamicLoadObject("UWindow.BlackTexture", class'Texture', true));
	for (i = 0; i < BI.NumClasses * 3; i++)
	{
		if (BI.ClsWeap[i] != "")
		{
			WC = class<Weapon>(DynamicLoadObject(BI.ClsWeap[i], class'Class', true));
			if (WC != None)
				WeapTex[i] = WC.Default.Icon;
		}
	}
	for (i = 0; i < BI.NumClasses; i++)
	{
		if (BI.ClsTex[i] != "")
			ClassImg[i] = Texture(DynamicLoadObject(BI.ClsTex[i], class'Texture', true));
	}
}

function BombHUD GetHud()
{
	local BombHUD K;

	foreach GetPlayerOwner().AllActors(class'BombHUD', K)
		return K;
	return None;
}

function UWindowSmallButton MakeButton(float X, float Y, float W, string Txt)
{
	local UWindowSmallButton B;

	B = UWindowSmallButton(CreateControl(class'UWindowSmallButton', X, Y, W, 16));
	B.SetText(Txt);
	return B;
}

function Created()
{
	local int i, rows;
	local float cx, cy;
	local BombHUD H2;

	Super.Created();
	BI = GetInfo();
	BC = GetClient();
	if (BI == None)
		return;
	LoadTextures();

	for (i = 0; i < BI.NumClasses; i++)
	{
		cx = 8 + (i % 2) * (CardW + 6);
		cy = 22 + (i / 2) * CardH;
		ClassBtn[i] = MakeButton(cx + CardW - 62, cy + 46, 58, "Pick");
	}

	rows = (BI.NumClasses + 1) / 2;
	WildY = 22 + rows * CardH + 8;

	T1Btn = MakeButton(100, WildY + 28, 300, "Tier 1");
	T2Btn = MakeButton(100, WildY + 50, 300, "Tier 2");
	T3Btn = MakeButton(100, WildY + 72, 300, "Tier 3");
	DoneBtn = MakeButton(408, WildY + 98, 70, "Done");
	HudBtn = MakeButton(8, WildY + 98, 100, "HUD settings");
	ReadyBtn = MakeButton(112, WildY + 98, 110, "Ready / not ready");

	// the player's own setting, saved in UTBombClient.ini
	H2 = GetHud();
	AutoC = UWindowCheckbox(CreateControl(class'UWindowCheckbox', 8, WildY + 124, 380, 1));
	AutoC.SetText("Open this menu at the start of every round");
	AutoC.SetFont(F_Normal);
	AutoC.bChecked = (H2 == None || H2.AutoMenu != 0);
}

function Command(string Cmd)
{
	GetPlayerOwner().ConsoleCommand(Cmd);
}

function Notify(UWindowDialogControl C, byte E)
{
	local int i;
	local BombHUD H2;

	Super.Notify(C, E);
	if (C == AutoC && E == DE_Change)
	{
		H2 = GetHud();
		if (H2 != None)
		{
			if (AutoC.bChecked)
				H2.AutoMenu = 1;
			else
				H2.AutoMenu = 0;
			H2.SaveConfig();
		}
		return;
	}
	if (E != DE_Click)
		return;

	for (i = 0; i < 16; i++)
	{
		if (ClassBtn[i] != None && ClassBtn[i] == C)
		{
			Command("mutate class " $ (i + 1));
			return;
		}
	}
	if (C == T1Btn)
	{
		Command("mutate t1next");
		return;
	}
	if (C == T2Btn)
	{
		Command("mutate t2next");
		return;
	}
	if (C == T3Btn)
	{
		Command("mutate t3next");
		return;
	}
	if (C == ReadyBtn)
	{
		Command("mutate readytoggle");
		return;
	}
	if (C == HudBtn)
	{
		if (Root.FindChildWindow(class'BombHudWindow') == None)
			Root.CreateWindow(class'BombHudWindow', 70, 20, 400, 530);
		return;
	}
	if (C == DoneBtn)
		GetParent(class'UWindowFramedWindow').Close();
}

// the optional movement values of a class, shown at the bottom of its card
function string ExtraText(int i)
{
	local string S;

	if (BI.ClsSpeed[i] != 100 && BI.ClsSpeed[i] != 0)
		S = S $ "Speed " $ BI.ClsSpeed[i] $ "%  ";
	if (BI.ClsHealth[i] != 100 && BI.ClsHealth[i] > 0)
		S = S $ "Health " $ BI.ClsHealth[i] $ "  ";
	if (BI.ClsRegen[i] > 0)
		S = S $ "Regen " $ BI.ClsRegen[i] $ "/s  ";
	if (BI.ClsSelf[i] < 100 && BI.ClsSelf[i] >= 0 && (BI.ClsWild[i] & 16) == 0)
		S = S $ "Self dmg " $ BI.ClsSelf[i] $ "%  ";
	if (BI.ClsHammerSelf[i] < 100 && BI.ClsHammerSelf[i] < BI.ClsSelf[i] && (BI.ClsWild[i] & 16) == 0)
		S = S $ "Hammer self dmg " $ BI.ClsHammerSelf[i] $ "%  ";
	if (BI.ClsWall[i] == 1)
		S = S $ "Wall dodge  ";
	if (BI.ClsDodges[i] >= 0)
		S = S $ "Dodges " $ BI.ClsDodges[i] $ "  ";
	return S;
}

// Text on a tier button: the chosen weapon, its ammo and how many choices there are.
function string TierLabel(int t)
{
	local int c, n, o, idx;
	local string S;

	if (BC == None || BI == None)
		return "...";
	c = BC.CurClass;
	if (c < 0 || c > 15)
		c = 0;
	n = BI.ClsTCount[c * 3 + t];
	if (n <= 0)
		return "none";
	if (t == 0)
		o = BC.CurOpt1;
	else if (t == 1)
		o = BC.CurOpt2;
	else
		o = BC.CurOpt3;
	if (o < 0 || o >= n)
		o = 0;
	idx = (c * 3 + t) * 4 + o;
	S = BI.OptShort(idx);
	if (BI.OptAmmo(idx) > 0)
		S = S $ " " $ BI.OptAmmo(idx);
	if (n > 1)
		S = S $ "   (" $ (o + 1) $ "/" $ n $ ")  click to change";
	else
		S = S $ "   (no choice)";
	return S;
}

function UpdateTierButtons()
{
	if (T1Btn != None)
		T1Btn.SetText(TierLabel(0));
	if (T2Btn != None)
		T2Btn.SetText(TierLabel(1));
	if (T3Btn != None)
		T3Btn.SetText(TierLabel(2));
}

function string JoinPart(string S, string Part)
{
	if (S == "")
		return Part;
	return S $ " + " $ Part;
}

// mask bits: 1 Translocator, 2 Ammo Pack, 4 Keg, 8 Defuse Kit, 16 no self damage, 32 no team damage
function string WildText(int mask, int uses)
{
	local string S;

	if ((mask & 1) != 0)
	{
		S = "Translocator";
		if (uses > 0)
			S = S $ " x" $ uses;
	}
	if ((mask & 2) != 0)
		S = JoinPart(S, "Ammo Pack +" $ BI.AmmoPackPct $ "%");
	if ((mask & 4) != 0)
		S = JoinPart(S, "Keg +" $ BI.KegAmt $ " health");
	if ((mask & 8) != 0)
		S = JoinPart(S, "Defuse Kit");
	if ((mask & 16) != 0)
		S = JoinPart(S, "No self damage");
	if ((mask & 32) != 0)
		S = JoinPart(S, "No team damage");
	if (S == "")
		return "No wildcard";
	return S;
}

function SetWhite(Canvas C)
{
	C.DrawColor.R = 255;
	C.DrawColor.G = 255;
	C.DrawColor.B = 255;
}

function Paint(Canvas C, float X, float Y)
{
	local int i, k, p;
	local float cx, cy;
	local string S, L1, L2;

	Super.Paint(C, X, Y);
	SetWhite(C);
	C.Font = Root.Fonts[F_Normal];

	if (BI == None)
	{
		ClipText(C, 10, 10, "No class data yet. Close this window and try again.");
		return;
	}

	C.Font = Root.Fonts[F_Bold];
	ClipText(C, 8, 4, "Pick a class (changes apply in the freeze phase of the next round):");

	for (i = 0; i < BI.NumClasses; i++)
	{
		cx = 8 + (i % 2) * (CardW + 6);
		cy = 22 + (i / 2) * CardH;

		if (CardBG != None)
			DrawStretchedTexture(C, cx, cy, CardW, CardH - 4, CardBG);

		SetWhite(C);
		C.Font = Root.Fonts[F_Bold];
		ClipText(C, cx + 4, cy + 1, (i + 1) $ ". " $ BI.ClsName[i]);
		C.Font = Root.Fonts[F_Normal];

		if (ClassImg[i] != None)
		{
			DrawStretchedTexture(C, cx + 4, cy + 18, 120, 40, ClassImg[i]);
		}
		else
		{
			for (k = 0; k < 3; k++)
			{
				if (WeapTex[i * 3 + k] != None)
					DrawStretchedTexture(C, cx + 4 + k * 40, cy + 16, 36, 36, WeapTex[i * 3 + k]);
				if (BI.ClsAmmo[i * 3 + k] > 0)
					ClipText(C, cx + 8 + k * 40, cy + 50, string(BI.ClsAmmo[i * 3 + k]));
			}
		}

		ClipText(C, cx + 130, cy + 18, "Armor " $ BI.ClsArmor[i]);
		ClipText(C, cx + 130, cy + 30, WildText(BI.ClsWild[i], BI.ClsTrans[i]));
		ClipText(C, cx + 4, cy + 64, ExtraText(i));
	}

	BC = GetClient();
	if (BC != None && BC.CurDesc != "")
	{
		S = BC.CurDesc;
		p = InStr(S, " | ");
		if (p > 0)
		{
			L1 = Left(S, p);
			L2 = Mid(S, p + 3);
		}
		else
		{
			L1 = S;
			L2 = "";
		}
		C.Font = Root.Fonts[F_Bold];
		ClipText(C, 8, WildY, "Your pick:");
		C.Font = Root.Fonts[F_Normal];
		ClipText(C, 70, WildY, L1);
		ClipText(C, 70, WildY + 13, L2);
	}

	// tier 1 is fixed to the class; tiers 2 and 3 can be changed
	UpdateTierButtons();
	C.Font = Root.Fonts[F_Normal];
	ClipText(C, 8, WildY + 31, "Tier 1 weapon:");
	ClipText(C, 8, WildY + 53, "Tier 2 weapon:");
	ClipText(C, 8, WildY + 75, "Tier 3 weapon:");
}

defaultproperties
{
}
