/*
 *
 *	InkMod Build - Entity Remove Commands
 *
**/
#define _ink_build_modify_remove_

float CleanStartPos[MAXPLAYERS + 1][3];


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

public Action Command_CleanArea(int client, int args)
{
	if (CleanStartPos[client][0] == 0) {
		Ink_GetClientAim(client, CleanStartPos[client]);
		CreateTimer(0.1, DrawCleanArea, client, TIMER_REPEAT);

		return Plugin_Handled;
	}

	float areaPoints[2][3];
	AddVectors(CleanStartPos[client], ZERO_VECTOR, areaPoints[0]);
	Ink_GetClientAim(client, areaPoints[1]);

	int count;

	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
		if (!IsValidEntity(ent)) {
			continue;
		}

		if (!Ink_CheckEntOwner(ent, client, ADMFLAG_KICK)) {
			continue;
		}

		float entOrigin[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);

		if (InLand(entOrigin, areaPoints)) {
			count++;
			Ink_RemoveEnt(ent, false);
		}
	}

	if (count == 0) {
		Ink_ClientMsg(client, "Didn't find any entities for cleanup.");
	} else {
		Ink_ClientMsg(client, "Cleaned up {green}%i{default} entities.", count);
	}
	CleanStartPos[client][0] = 0;
	CleanStartPos[client][1] = 0;
	CleanStartPos[client][2] = 0;

	return Plugin_Handled;
}

public Action DrawCleanArea(Handle timer, int client)
{
	if (CleanStartPos[client][0] == 0) {
		return Plugin_Stop;
	}

	float areaPoints[4][3];
	Ink_GetClientAim(client, areaPoints[2]);

	AddVectors(CleanStartPos[client], ZERO_VECTOR, areaPoints[0]);
	areaPoints[0][2]++;
	for (int i = 1; i < 4; i++) {
		areaPoints[i][2] = areaPoints[0][2];
	}

	// draw square
	areaPoints[1][0] = areaPoints[0][0];
	areaPoints[1][1] = areaPoints[2][1];
	areaPoints[3][0] = areaPoints[2][0];
	areaPoints[3][1] = areaPoints[0][1];
	TE_SetupBeamPoints(areaPoints[0], areaPoints[1], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
	TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(areaPoints[1], areaPoints[2], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
	TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(areaPoints[2], areaPoints[3], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
	TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(areaPoints[3], areaPoints[0], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
	TE_SendToClient(client, 0.0);

	return Plugin_Continue;
}