//=============================================================================
// BombActor.uc
// The visible bomb: used for the dropped bomb and for the planted bomb.
// Looks like the Redeemer pickup with a pulsing red light. When armed it
// beeps faster as the timer runs down.
//=============================================================================
class BombActor extends Actor;

var bool  bArmed;
var int   SecondsLeft;
var float BeepTimer;
var Sound BeepSound;

simulated function PostBeginPlay()
{
	SetupLook();
	if (Role == ROLE_Authority)
		BeepSound = Sound(DynamicLoadObject("UnrealShare.Pickups.GenPickSnd", class'Sound', true));
}

simulated event PostNetBeginPlay()
{
	SetupLook();
}

simulated function SetupLook()
{
	local class<Weapon> WC;

	WC = class<Weapon>(DynamicLoadObject("Botpack.WarheadLauncher", class'Class', true));
	if (WC != None && WC.Default.PickupViewMesh != None)
	{
		Mesh = WC.Default.PickupViewMesh;
		DrawType = DT_Mesh;
	}
}

function Tick(float DeltaTime)
{
	local float Interval, Pitch;

	if (!bArmed)
		return;
	BeepTimer -= DeltaTime;
	if (BeepTimer > 0.0)
		return;

	if (SecondsLeft > 20)
		Interval = 1.0;
	else if (SecondsLeft > 10)
		Interval = 0.6;
	else if (SecondsLeft > 5)
		Interval = 0.35;
	else
		Interval = 0.2;
	BeepTimer = Interval;

	Pitch = 1.0 + (1.0 - float(Min(SecondsLeft, 40)) / 40.0) * 0.8;
	PlaySound(BeepSound, SLOT_Misc, 6.0, false, 2500.0, Pitch);
}

defaultproperties
{
	DrawType=DT_None
	DrawScale=0.6
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
	NetUpdateFrequency=10.0
	Physics=PHYS_None
	bCollideWorld=True
	bCollideActors=False
	CollisionRadius=14.0
	CollisionHeight=14.0
	LightType=LT_Pulse
	LightEffect=LE_None
	LightBrightness=220
	LightHue=0
	LightSaturation=0
	LightRadius=10
	LightPeriod=40
}
