//=============================================================================
// BombItem.uc
// Shown in the carrier's inventory bar so they can see they carry the bomb.
// Purely a display item: the real bomb state lives in BombGame.
//=============================================================================
class BombItem extends Pickup;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	SetupIcon();
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	SetupIcon();
}

simulated function SetupIcon()
{
	local class<Weapon> WC;

	WC = class<Weapon>(DynamicLoadObject("Botpack.WarheadLauncher", class'Class', true));
	if (WC != None)
		Icon = WC.Default.Icon;
}

// pressing the activate key does nothing
function Activate()
{
}

defaultproperties
{
	ItemName="Bomb"
	PickupMessage="You have the bomb"
	bActivatable=True
	bAutoActivate=False
}
