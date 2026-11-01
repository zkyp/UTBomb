//=============================================================================
// BombMessage.uc
// Big centre-screen messages for bomb events, same style as the CTF
// "You have the flag" message.
//=============================================================================
class BombMessage extends CriticalEventPlus;

static function string GetString(optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	switch (Switch)
	{
		case 0:
			return "You have the bomb!";
		case 1:
			return "The bomb has been planted!";
		case 2:
			return "The bomb has been defused!";
		case 3:
			return "The bomb exploded!";
		case 4:
			return "The bomb was dropped!";
		case 5:
			return "You are the SUPER CLASS this round!";
	}
	return "";
}

defaultproperties
{
}
