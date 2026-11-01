//=============================================================================
// BombHudClient.uc
// Contents of the HUD settings window. Every control changes the running HUD
// immediately and saves to System\UTBombClient.ini. "Use server defaults"
// puts every setting back to -1 (= whatever the server says).
//=============================================================================
class BombHudClient extends UWindowDialogClientWindow;

var BombHUD  H;
var BombInfo BI;

var UWindowComboControl   BarModeC, BarFontC, BannerFontC, MarkerFontC;
var UWindowHSliderControl BarScaleS, BarYS, PortraitsS, BannerYS;
var UWindowCheckbox       NamesC, BannerC, MarkersC, DistanceC, TransC;
var UWindowComboControl   TransFontC;
var UWindowHSliderControl TransXS, TransYS;
var UWindowSmallButton    ResetBtn, DoneBtn;
var bool bLoading;

function BombHUD GetHud()
{
	local BombHUD K;

	foreach GetPlayerOwner().AllActors(class'BombHUD', K)
		return K;
	return None;
}

function BombInfo GetInfo()
{
	local BombInfo B;

	foreach GetPlayerOwner().AllActors(class'BombInfo', B)
		return B;
	return None;
}

// player value if set, otherwise the server's default
function int Eff(int PlayerVal, int ServerVal)
{
	if (PlayerVal >= 0)
		return PlayerVal;
	return ServerVal;
}

function int ToInt(bool b)
{
	if (b)
		return 1;
	return 0;
}

function UWindowComboControl MakeCombo(float Y, string Label, string A, string B, string C2, string D)
{
	local UWindowComboControl K;

	K = UWindowComboControl(CreateControl(class'UWindowComboControl', 10, Y, 370, 1));
	K.SetText(Label);
	K.SetFont(F_Normal);
	K.SetEditable(False);
	K.EditBoxWidth = 120;
	K.AddItem(A);
	K.AddItem(B);
	if (C2 != "")
		K.AddItem(C2);
	if (D != "")
		K.AddItem(D);
	return K;
}

function UWindowHSliderControl MakeSlider(float Y, string Label, float Lo, float Hi, int Step)
{
	local UWindowHSliderControl K;

	K = UWindowHSliderControl(CreateControl(class'UWindowHSliderControl', 10, Y, 370, 1));
	K.SetText(Label);
	K.SetFont(F_Normal);
	K.SetRange(Lo, Hi, Step);
	K.SliderWidth = 150;
	return K;
}

function UWindowCheckbox MakeCheck(float Y, string Label)
{
	local UWindowCheckbox K;

	K = UWindowCheckbox(CreateControl(class'UWindowCheckbox', 10, Y, 370, 1));
	K.SetText(Label);
	K.SetFont(F_Normal);
	return K;
}

function Created()
{
	local float Y;

	Super.Created();
	H = GetHud();
	BI = GetInfo();
	if (H == None || BI == None)
		return;

	Y = 22;
	BarModeC    = MakeCombo(Y, "Top bar", "Off", "Portraits", "Text only", "");
	Y += 24;
	BarScaleS   = MakeSlider(Y, "Top bar size (%)", 40, 160, 5);
	Y += 24;
	BarYS       = MakeSlider(Y, "Top bar position (pixels from top)", 0, 200, 2);
	Y += 24;
	BarFontC    = MakeCombo(Y, "Top bar font", "Small", "Medium", "Big", "Huge");
	Y += 24;
	PortraitsS  = MakeSlider(Y, "Portraits per team", 1, 8, 1);
	Y += 24;
	NamesC      = MakeCheck(Y, "Show player names under portraits");
	Y += 30;
	BannerC     = MakeCheck(Y, "Show the BOMB PLANTED banner");
	Y += 24;
	BannerFontC = MakeCombo(Y, "Banner font", "Small", "Medium", "Big", "Huge");
	Y += 24;
	BannerYS    = MakeSlider(Y, "Banner position (pixels from top)", 0, 300, 5);
	Y += 30;
	MarkersC    = MakeCheck(Y, "Show markers in the world");
	Y += 24;
	MarkerFontC = MakeCombo(Y, "Marker font", "Small", "Medium", "Big", "Huge");
	Y += 24;
	DistanceC   = MakeCheck(Y, "Show distance on markers");
	Y += 30;
	TransC      = MakeCheck(Y, "Show the translocator counter");
	Y += 24;
	TransFontC  = MakeCombo(Y, "Counter font", "Small", "Medium", "Big", "Huge");
	Y += 24;
	TransXS     = MakeSlider(Y, "Counter position, from the left (%)", 0, 100, 1);
	Y += 24;
	TransYS     = MakeSlider(Y, "Counter position, from the top (%)", 0, 100, 1);
	Y += 34;

	ResetBtn = UWindowSmallButton(CreateControl(class'UWindowSmallButton', 10, Y, 130, 16));
	ResetBtn.SetText("Use server defaults");
	DoneBtn = UWindowSmallButton(CreateControl(class'UWindowSmallButton', 310, Y, 70, 16));
	DoneBtn.SetText("Done");

	LoadValues();
}

function LoadValues()
{
	bLoading = true;
	BarModeC.SetSelectedIndex(Min(Max(Eff(H.BarMode, BI.HudBarMode), 0), 2));
	BarScaleS.SetValue(Eff(H.BarScale, BI.HudBarScale));
	BarYS.SetValue(Eff(H.BarY, BI.HudBarY));
	BarFontC.SetSelectedIndex(Min(Max(Eff(H.BarFont, BI.HudBarFont), 0), 3));
	PortraitsS.SetValue(Eff(H.MaxPortraits, BI.HudMaxPort));
	NamesC.bChecked = (Eff(H.ShowNames, BI.HudShowNames) != 0);
	BannerC.bChecked = (H.ShowBanner != 0);
	BannerFontC.SetSelectedIndex(Min(Max(Eff(H.BannerFont, BI.HudBannerFont), 0), 3));
	BannerYS.SetValue(Eff(H.BannerY, BI.HudBannerY));
	MarkersC.bChecked = (H.ShowMarkers != 0);
	MarkerFontC.SetSelectedIndex(Min(Max(Eff(H.MarkerFont, BI.HudMarkerFont), 0), 3));
	DistanceC.bChecked = (H.ShowDistance != 0);
	TransC.bChecked = (H.ShowTrans != 0);
	TransFontC.SetSelectedIndex(Min(Max(Eff(H.TransFont, BI.HudTransFont), 0), 3));
	TransXS.SetValue(Eff(H.TransX, BI.HudTransX));
	TransYS.SetValue(Eff(H.TransY, BI.HudTransY));
	bLoading = false;
}

function ResetToServer()
{
	H.BarMode = -1;
	H.BarScale = -1;
	H.BarY = -1;
	H.BarFont = -1;
	H.MaxPortraits = -1;
	H.ShowNames = -1;
	H.ShowBanner = -1;
	H.BannerFont = -1;
	H.BannerY = -1;
	H.ShowMarkers = -1;
	H.MarkerFont = -1;
	H.ShowDistance = -1;
	H.ShowTrans = -1;
	H.TransFont = -1;
	H.TransX = -1;
	H.TransY = -1;
	H.SaveConfig();
	LoadValues();
}

function Notify(UWindowDialogControl C, byte E)
{
	Super.Notify(C, E);
	if (H == None || bLoading)
		return;

	if (E == DE_Change)
	{
		if (C == BarModeC)        H.BarMode = BarModeC.GetSelectedIndex();
		else if (C == BarScaleS)  H.BarScale = int(BarScaleS.GetValue());
		else if (C == BarYS)      H.BarY = int(BarYS.GetValue());
		else if (C == BarFontC)   H.BarFont = BarFontC.GetSelectedIndex();
		else if (C == PortraitsS) H.MaxPortraits = int(PortraitsS.GetValue());
		else if (C == NamesC)     H.ShowNames = ToInt(NamesC.bChecked);
		else if (C == BannerC)    H.ShowBanner = ToInt(BannerC.bChecked);
		else if (C == BannerFontC) H.BannerFont = BannerFontC.GetSelectedIndex();
		else if (C == BannerYS)   H.BannerY = int(BannerYS.GetValue());
		else if (C == MarkersC)   H.ShowMarkers = ToInt(MarkersC.bChecked);
		else if (C == MarkerFontC) H.MarkerFont = MarkerFontC.GetSelectedIndex();
		else if (C == DistanceC)  H.ShowDistance = ToInt(DistanceC.bChecked);
		else if (C == TransC)     H.ShowTrans = ToInt(TransC.bChecked);
		else if (C == TransFontC) H.TransFont = TransFontC.GetSelectedIndex();
		else if (C == TransXS)    H.TransX = int(TransXS.GetValue());
		else if (C == TransYS)    H.TransY = int(TransYS.GetValue());
		H.SaveConfig();
	}

	if (E == DE_Click)
	{
		if (C == ResetBtn)
			ResetToServer();
		else if (C == DoneBtn)
			GetParent(class'UWindowFramedWindow').Close();
	}
}

function Paint(Canvas C, float X, float Y)
{
	Super.Paint(C, X, Y);
	C.DrawColor.R = 255;
	C.DrawColor.G = 255;
	C.DrawColor.B = 255;
	C.Font = Root.Fonts[F_Normal];
	if (H == None || BI == None)
		ClipText(C, 10, 10, "HUD not ready yet. Close this window and try again.");
	else
		ClipText(C, 10, 4, "Changes apply at once and are saved to UTBombClient.ini.");
}

defaultproperties
{
}
