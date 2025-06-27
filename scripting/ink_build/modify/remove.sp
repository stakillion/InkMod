/*
 *
 *	InkMod Build - Entity Remove Commands
 *
**/
#define _ink_build_modify_remove_


public Action Command_RemoveEnt(int client, int args)
{
	if (args > 0) {
		char cmdArg[32];
		GetCmdArg(1, cmdArg, sizeof(cmdArg));
		String_ToLower(cmdArg, cmdArg, sizeof(cmdArg));
		StripQuotes(cmdArg);
		TrimString(cmdArg);

		if (StrEqual(cmdArg, "all", false)) {
			int entCount = Ink_CleanClientEnts(client);
			Ink_ClientMsg(client, "Cleaned up {green}%i{default} entities.", entCount);

			return Plugin_Handled;
		}

		bool buildRemoved = false;
		for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
			if (!IsValidEntity(ent)) {
				continue;
			}

			if (!Ink_CheckEntOwner(ent, client)) {
				continue;
			}

			char globalName[64];
			char entSaveName[2][32]
			GetEntPropString(ent, Prop_Data, "m_iGlobalname", globalName, sizeof(globalName));
			ExplodeString(globalName, "-", entSaveName, 2, sizeof(entSaveName[]));

			if (StrEqual(entSaveName[0], cmdArg, false)) {
				Ink_RemoveEnt(ent, false);
				buildRemoved = true;
			}
		}

		if (buildRemoved) {
			Ink_ClientMsg(client, "Removed all entities of build {green}%s{default}.", cmdArg);
			return Plugin_Handled;
		}
	}

	// find entity under the player's crosshair
	float hitPos[3];
	int ent = Ink_GetClientAim(client, hitPos);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	
	if (!Ink_CheckEntOwner(ent, client, ADMFLAG_KICK)) {
		float landPoints[2][3];
		if (Object[client].GetArray("land.offset", landPoints[1], 3) 
		&& Object[client].GetArray("land.origin", landPoints[0], 3)) {
			if (!InLand(hitPos, landPoints)) {
				Ink_ClientMsg(client, "This entity doesn't belong to you.");
				return Plugin_Handled;
			}
		}
	}

	Ink_RemoveEnt(ent, true);

	Ink_RemoveEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Removed {entity}.");

	return Plugin_Handled;
}
