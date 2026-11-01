//=============================================================================
// BombHudWindow.uc
// The HUD settings window frame. The contents are in BombHudClient.
//=============================================================================
class BombHudWindow extends UWindowFramedWindow;

function Created()
{
	bStatusBar = False;
	bSizable = False;
	Super.Created();
}

// The HUD settings window is opened from the class menu. When it is closed and the
// class menu is already gone, leave the menu system too.
function Close(optional bool bByParent)
{
	local UWindowRootWindow R;

	R = Root;
	Super.Close(bByParent);
	if (R != None && R.Console != None && R.FindChildWindow(class'BombClassWindow') == None)
		R.Console.CloseUWindow();
}

defaultproperties
{
	ClientClass=class'BombHudClient'
	WindowTitle="Bomb Defusal - HUD settings"
}
