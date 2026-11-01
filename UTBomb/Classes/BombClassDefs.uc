//=============================================================================
// BombClassDefs.uc
// Holds the class lines. They are read from System\UTBombClasses.ini, section
// [UTBomb.BombClassDefs]. The values below are only used if that file is
// missing. See UTBombClasses.ini for how a class line is written.
//=============================================================================
class BombClassDefs extends Object config(UTBombClasses);

var() config string ClassDef[16];   // 15 classes are used, the last line is ignored
var() config string SuperDef;       // the super class, given to a team on a losing streak

defaultproperties
{
	ClassDef(0)="Default  | Armor=100 | T1=Shock:24 | T2=Rocket:18,Flak:20,Pulse:50 | Wild=Translocator:5"
	ClassDef(1)="HammerKing   | Armor=75  | T1=Shock:12 | T2=Flak:24 | Wild=NoSelfDamage"
	ClassDef(2)="SniperNoob | Armor=50  | T1=Sniper:16 | T3=Ripper:30,Bio:20 | Wild=Translocator:6"
	ClassDef(3)="FastGirl | Armor=50  | T2=Flak:12 | T3=Ripper:30,Enforcer:40,Bio:20 | Wild=None | Speed=130 | WallDodge=1 | Dodges=2"
	ClassDef(4)="Spammer  | Armor=150 | T2=Flak:30,Pulse:60,Rocket:18 | T3=Ripper:40,Bio:30 | Wild=AmmoPack | PackSlot=2"
	ClassDef(5)="Booster   | Armor=125 | Health=70 | T1=Shock:20 | T2=Rocket:18 | Wild=NoTeamDamage | Regen=3"
	ClassDef(6)="Fatboy    | Armor=200 | T1=Shock:50 | T2=Minigun:199,Rocket:18,Flak:24 | Wild=Keg | Speed=70"
	SuperDef="SUPER | Armor=150 | Health=125 | Amp=1 | Speed=80 | T1=Sniper:8,Shock:14 | T2=Rocket:24,Flak:30 | T3=Minigun:199,Pulse:60 | Wild=NoSelfDamage,Translocator:5"
}
