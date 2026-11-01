//=============================================================================
// BombSite.uc
// A plant zone, shown in game as a rotating glowing marker.
// Place it in UnrealEd (Actor class browser > Info > BombSite), set SiteName
// ("A", "B") and Radius. If a map has no BombSite actors, the gametype
// creates one automatically at the defenders' base.
//=============================================================================
class BombSite extends Info;

var() string SiteName;
var() float  Radius;
var bool     bAutoSite;     // created by the gametype, not placed by a mapper

simulated function PostBeginPlay()
{
	SetupLook();
}

simulated event PostNetBeginPlay()
{
	SetupLook();
}

simulated function SetupLook()
{
	local class<Inventory> IC;

	// In the editor the site is a sprite icon (DT_Sprite, hidden). In a running
	// game it becomes the rotating marker model, or stays invisible if the
	// model cannot be loaded.
	bHidden = False;
	DrawType = DT_None;
	IC = class<Inventory>(DynamicLoadObject("Botpack.UDamage", class'Class', true));
	if (IC != None && IC.Default.PickupViewMesh != None)
	{
		Mesh = IC.Default.PickupViewMesh;
		DrawType = DT_Mesh;
	}
}

defaultproperties
{
	SiteName="A"
	Radius=250.0
	bHidden=True
	DrawType=DT_Sprite
	Texture=Texture'Engine.S_Actor'
	DrawScale=1.6
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
	Physics=PHYS_Rotating
	bFixedRotationDir=True
	RotationRate=(Yaw=12000)
	LightType=LT_Pulse
	LightEffect=LE_None
	LightBrightness=255
	LightHue=40
	LightSaturation=0
	LightRadius=35
	LightPeriod=32
}
