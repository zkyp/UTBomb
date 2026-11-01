//=============================================================================
// BombMutator.uc
// Console commands for BombGame, via the standard "mutate" command:
//   mutate classes           list all classes
//   mutate class <n>         pick a class
//   mutate loadout           show your current pick
//   mutate menu              open the class menu (bind this to a key)
//   mutate t1 <weapon> / t2 <weapon> / t3 <weapon>   choose your weapon in a tier
//   mutate t1next / t2next / t3next   go to the next weapon on the list
//   ready (or mutate ready)  ready up for the match (warm-up only), IG+ handles it on IG+ servers
//   mutate bombready / bombunready / readytoggle   same thing, works on any server
//=============================================================================
class BombMutator extends Mutator;

function Mutate(string MutateString, PlayerPawn Sender)
{
	local BombGame G;
	local string Cmd, Arg;
	local int p;

	G = BombGame(Level.Game);
	if (G != None && Sender != None)
	{
		p = InStr(MutateString, " ");
		if (p < 0)
		{
			Cmd = Caps(MutateString);
			Arg = "";
		}
		else
		{
			Cmd = Caps(Left(MutateString, p));
			Arg = Mid(MutateString, p + 1);
		}

		if (Cmd == "CLASSES")
			G.ListClasses(Sender);
		else if (Cmd == "CLASS")
			G.SetPlayerClass(Sender, int(Arg));
		else if (Cmd == "LOADOUT")
			Sender.ClientMessage(G.Describe(Sender));
		else if (Cmd == "MENU")
			G.OpenMenu(Sender);
		else if (Cmd == "READY")
		{
			// IG+ players are handled by IG+ itself (it toggles the same flag)
			if (!Sender.IsA('bbPlayer'))
				G.ToggleReady(Sender);
		}
		else if (Cmd == "BOMBREADY")
			G.SetReady(Sender, true);
		else if (Cmd == "BOMBUNREADY" || Cmd == "UNREADY")
			G.SetReady(Sender, false);
		else if (Cmd == "READYTOGGLE")
			G.ToggleReady(Sender);
		else if (Cmd == "T1")
			G.SetTierByName(Sender, 1, Arg);
		else if (Cmd == "T1NEXT")
			G.CycleTier(Sender, 1);
		else if (Cmd == "T2")
			G.SetTierByName(Sender, 2, Arg);
		else if (Cmd == "T3")
			G.SetTierByName(Sender, 3, Arg);
		else if (Cmd == "T2NEXT")
			G.CycleTier(Sender, 2);
		else if (Cmd == "T3NEXT")
			G.CycleTier(Sender, 3);
	}

	if (NextMutator != None)
		NextMutator.Mutate(MutateString, Sender);
}

// Called for every actor another mutator might want to replace or remove.
// Items we are handing out as part of a loadout are always kept.
function bool AlwaysKeep(Actor Other)
{
	local BombGame G;

	G = BombGame(Level.Game);
	if (G != None && G.bGiving && Other.IsA('Inventory'))
		return true;
	if (NextMutator != None)
		return NextMutator.AlwaysKeep(Other);
	return false;
}

defaultproperties
{
}
