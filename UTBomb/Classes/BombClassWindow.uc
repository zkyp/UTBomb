//=============================================================================
// BombClassWindow.uc
// The class menu window frame. The contents are in BombClassClient.
//=============================================================================
class BombClassWindow extends UWindowFramedWindow;

function Created()
{
	bStatusBar = False;
	bSizable = False;
	Super.Created();
}

// Closing this window (the X, Escape or the Done button) should take the player
// straight back to the game and not drop them into the normal menu.
function Close(optional bool bByParent)
{
	local UWindowRootWindow R;

	R = Root;
	Super.Close(bByParent);
	if (R != None && R.Console != None && R.FindChildWindow(class'BombHudWindow') == None)
		R.Console.CloseUWindow();
}

defaultproperties
{
	ClientClass=class'BombClassClient'
	WindowTitle="Bomb Defusal - choose your class"
}
