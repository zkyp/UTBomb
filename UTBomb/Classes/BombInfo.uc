//=============================================================================
// BombInfo.uc
// One replicated actor that carries everything clients need: the class list
// (for the menu) and the live round/bomb state (for the HUD). Written by
// BombGame on the server, read by BombHUD and the class menu on clients.
//=============================================================================
class BombInfo extends ReplicationInfo;

// class data (set once at startup)
var int    NumClasses;
var string ClsName[16];
var int    ClsArmor[16];
var int    ClsWild[16];
var int    ClsTrans[16];    // translocations per round, 0 = unlimited
var int    ClsSelf[16];     // self damage in percent
var int    ClsHammerSelf[16];
var int    ClsSpeed[16];    // percent
var int    ClsRegen[16];    // health per second
var int    ClsWall[16];     // -1 server default, 0 off, 1 on
var int    ClsDodges[16];   // -1 server default
var string ClsTex[16];       // optional custom picture, Package.Texture
var string ClsWeap[48];      // full weapon class names, 3 per class
var int    ClsAmmo[48];
var int    ClsTCount[48];   // weapon options per class*3 + tier
var string ClsTWeap[192];   // option weapons: ((class*3 + tier)*4) + option
var int    ClsTAmmo[192];
var string ClsTShort[192];  // short names, for the buttons
var int    ClsHealth[16];
var string ClsModel[16];    // class skins: body, skin and face (see UTBombClasses.ini)
var string ClsSkin[16];
var string ClsFace[16];
var string ClsPortrait[16];
var int    SkinPID[32];     // player ids ...
var int    SkinCls[32];     // ... and the class each of them has (-1 = none)
var Texture SkinTex[32];    // ... and the player's own picture, as the server knows it
var int    AmmoPackPct;
var int    KegAmt;
var int    DefuseKitPct;

// live state
var int    RoundState;
var int    RoundNum;
var int    Score0;
var int    Score1;
var int    Alive0;
var int    Alive1;
var int    AttackTeam;
var int    SecondsLeft;
var bool   bPlanted;
var bool   bCarried;
var bool   bDropped;
var bool   bOT;            // overtime is being played
var int    OTScore0;        // overtime rounds won
var int    OTScore1;
var bool   bDefSeeBomb;     // may defenders see where the planted bomb is
var bool   bTimerVis0;      // may team 0 see the bomb countdown
var bool   bTimerVis1;
var int    HudBarMode;      // server defaults for the client HUD
var int    HudBarScale;
var int    HudBarY;
var int    HudBarFont;
var int    HudMaxPort;
var int    HudShowNames;
var int    HudBannerFont;
var int    HudBannerY;
var int    HudMarkerFont;
var int    HudTransFont;    // translocator counter
var int    HudTransX;       // percent from the left (the text ends there)
var int    HudTransY;       // percent from the top
var string WarmReason;      // why the match cannot start yet, empty if nothing is missing
var int    WarmState;       // 0 = none, 1 = waiting for ready-up, 2 = start countdown running
var int    WarmReady;
var int    WarmTotal;
var int    WarmCountdown;
var int    ReadyID[32];     // PlayerID + 1 of every player who is ready
var int    DeadID[32];      // PlayerID + 1 of every dead player, 0 = unused
var int    CarrierID;       // PlayerID + 1 of the bomb carrier, 0 = nobody
var vector CarrierLoc;
var vector DropLoc;
var vector PlantLoc;
var int    NumSites;
var vector SiteLoc[8];
var string SiteName[8];

replication
{
	reliable if (Role == ROLE_Authority)
		NumClasses, ClsName, ClsArmor, ClsWild, ClsTrans, ClsSelf, ClsHammerSelf, ClsSpeed, ClsRegen, ClsWall, ClsDodges, ClsTex, ClsWeap, ClsAmmo, ClsTCount, ClsTWeap, ClsTAmmo, ClsTShort, ClsHealth, ClsModel, ClsSkin, ClsFace, ClsPortrait, SkinPID, SkinCls, SkinTex,
		AmmoPackPct, KegAmt, DefuseKitPct,
		RoundState, RoundNum, Score0, Score1, Alive0, Alive1, AttackTeam, SecondsLeft,
		bPlanted, bCarried, bDropped, CarrierLoc, DropLoc, PlantLoc,
		bOT, OTScore0, OTScore1, bDefSeeBomb, bTimerVis0, bTimerVis1, HudBarMode, HudBarScale, HudBarY, HudBarFont, HudMaxPort, HudShowNames,
		HudBannerFont, HudBannerY, HudMarkerFont, HudTransFont, HudTransX, HudTransY, DeadID, CarrierID,
		WarmState, WarmReady, WarmTotal, WarmCountdown, ReadyID, WarmReason,
		NumSites, SiteLoc, SiteName;
}

// UnrealScript does not allow reaching into a big array (over 255 bytes) of
// ANOTHER object, so the weapon options are written and read through functions.
function SetOption(int idx, string W, int Ammo, string Short)
{
	ClsTWeap[idx] = W;
	ClsTAmmo[idx] = Ammo;
	ClsTShort[idx] = Short;
}

simulated function string OptWeap(int idx)
{
	return ClsTWeap[idx];
}

simulated function int OptAmmo(int idx)
{
	return ClsTAmmo[idx];
}

simulated function string OptShort(int idx)
{
	return ClsTShort[idx];
}

defaultproperties
{
	NetUpdateFrequency=10.0
}
