/*
 *
 *	InkMod Build - Land Areas
 *
**/
#define _ink_build_land_


int CurrentLand[MAX_EDICTS + 1] = {-1, ...};
bool ClearLand[MAXPLAYERS + 1];


void Land_ClientEntered(int client, int land)
{
	char landName[32];
	GetClientName(land, landName, sizeof(landName));
	Ink_ClientMsg(client, "You have entered {green}%s{default}'s land.", landName);
}

void Land_EntityEntered(int ent, int land)
{

}

void Land_ClientExited(int client, int land)
{
	char landName[32];
	GetClientName(land, landName, sizeof(landName));
	Ink_ClientMsg(client, "You have left {green}%s{default}'s land.", landName);
}

void Land_EntityExited(int ent, int land)
{

}

public Action Command_Land(int client, int args)
{
	char cmdArg[16];
	GetCmdArg(1, cmdArg, sizeof(cmdArg));
	
	if (StrEqual(cmdArg, "#clear", false)) {
		Object[client].Remove("land.origin");
		Object[client].Remove("land.offset");
		Ink_ClientMsg(client, "Cleared land.");

		return Plugin_Handled;
	}

	float landPoints[2][3];

	if (!Object[client].GetArray("land.origin", landPoints[0], 3)) {
		Ink_GetClientAim(client, landPoints[0]);

		// check for intersection of other land areas:
		for (int player = 1; player <= MaxClients; player++) {
			if (player == client || !IsClientInGame(player)) {
				continue;
			}

			float playerLandPoints[2][3];
			if (!Object[player].GetArray("land.offset", playerLandPoints[1], 3) 
			 || !Object[player].GetArray("land.origin", playerLandPoints[0], 3)) {
				continue;
			}

			if (InLand(landPoints[0], playerLandPoints)) {
				char playerName[32];
				GetClientName(player, playerName, sizeof(playerName));
				Ink_ClientMsg(client, "Land is intercepting {green}%s{default}'s land.", playerName);
				Ink_ClientMsg(client, "Do {green}!land #clear{default} to cancel land creation.");
				return Plugin_Handled;
			}
		}

		Object[client].SetArray("land.origin", landPoints[0], 3);
		Ink_ClientMsg(client, "Creating land. Do {green}!land{default} again to confirm.");

	} else if (!Object[client].GetArray("land.offset", landPoints[1], 3)) {
		Object[client].GetArray("land.origin", landPoints[0], 3);
		Ink_GetClientAim(client, landPoints[1]);
		landPoints[1][2] = landPoints[0][2];

		// clamp land size:
		int maxSize = GetConVarInt(ink_maxlandsize);
		for (int i; i < 2; i++) {
			if (landPoints[1][i] > landPoints[0][i] + maxSize) {
				landPoints[1][i] = landPoints[0][i] + maxSize;
			} else if (landPoints[1][i] < landPoints[0][i] - maxSize) {
				landPoints[1][i] = landPoints[0][i] - maxSize;
			}
		}

		for (int player = 1; player <= MaxClients; player++) {
			if (player == client || !IsClientInGame(player)) {
				continue;
			}

			// check for interception of other players:
			float playerPos[3];
			GetClientAbsOrigin(player, playerPos);

			if (InLand(playerPos, landPoints)) {
				Ink_ClientMsg(client, "Land is intercepting another player.");
				Ink_ClientMsg(client, "Do {green}!land #clear{default} to cancel land creation.");
				return Plugin_Handled;
			}

			// check for interception of other land areas:
			float playerLandPoints[2][3];
			if (!Object[player].GetArray("land.offset", playerLandPoints[1], 3) 
			 || !Object[player].GetArray("land.origin", playerLandPoints[0], 3)) {
				continue
			}

			if (IntersectingLand(landPoints, playerLandPoints)) {
				char playerName[32];
				GetClientName(player, playerName, sizeof(playerName));
				Ink_ClientMsg(client, "Land is intercepting {green}%s{default}'s land.", playerName);
				Ink_ClientMsg(client, "Do {green}!land #clear{default} to cancel land creation.");
				return Plugin_Handled;
			}
		}

		// check for interception of entities belonging to other players:
		for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
			if (!IsValidEntity(ent) || Object[ent] == null) {
				continue;
			}

			if (!Ink_CheckEntOwner(ent, client)) {
				float entOrigin[3];
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);

				if (InLand(entOrigin, landPoints)) {
					Ink_ClientEntMsg(client, ent, "Land is intercepting another player's {entity}.");
					Ink_ClientMsg(client, "Do {green}!land #clear{default} to cancel land creation.");
				}
			}
		}

		Object[client].SetArray("land.offset", landPoints[1], 3);
		Ink_ClientMsg(client, "Land created.");

	} else if (!ClearLand[client]) {
		ClearLand[client] = true;
		Ink_ClientMsg(client, "Clearing land. Do {green}!land{default} again to confirm.");
	} else {
		Object[client].Remove("land.origin");
		Object[client].Remove("land.offset");
		ClearLand[client] = false;
		Ink_ClientMsg(client, "Land cleared.");
	}

	return Plugin_Handled;
}

public Action DrawLand(Handle timer, int ent)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (Object[client] == null) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}

		float landPoints[4][3];
		if (!Object[client].GetArray("land.origin", landPoints[0], 3)) {
			// if no land is set, skip this client
			continue;
		} else if (Object[client].GetArray("land.offset", landPoints[2], 3)) {
			// if land is already set, draw the land
			landPoints[0][2]++;
			for (int i = 1; i < 4; i++) {
				landPoints[i][2] = landPoints[0][2];
			}

			// draw square
			landPoints[1][0] = landPoints[0][0];
			landPoints[1][1] = landPoints[2][1];
			landPoints[3][0] = landPoints[2][0];
			landPoints[3][1] = landPoints[0][1];
			TE_SetupBeamPoints(landPoints[0], landPoints[1], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToAll(0.0);
			TE_SetupBeamPoints(landPoints[1], landPoints[2], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToAll(0.0);
			TE_SetupBeamPoints(landPoints[2], landPoints[3], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToAll(0.0);
			TE_SetupBeamPoints(landPoints[3], landPoints[0], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToAll(0.0);
		} else {
			// otherwise the client is currently creating their land, so draw it for them
			Ink_GetClientAim(client, landPoints[2]);

			// clamp land size:
			int maxSize = GetConVarInt(ink_maxlandsize);
			for (int i; i < 2; i++) {
				if (landPoints[2][i] > landPoints[0][i] + maxSize) {
					landPoints[2][i] = landPoints[0][i] + maxSize;
				} else if (landPoints[2][i] < landPoints[0][i] - maxSize) {
					landPoints[2][i] = landPoints[0][i] - maxSize;
				}
			}

			landPoints[0][2]++;
			for (int i = 1; i < 4; i++) {
				landPoints[i][2] = landPoints[0][2];
			}

			// draw square
			landPoints[1][0] = landPoints[0][0];
			landPoints[1][1] = landPoints[2][1];
			landPoints[3][0] = landPoints[2][0];
			landPoints[3][1] = landPoints[0][1];
			TE_SetupBeamPoints(landPoints[0], landPoints[1], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToClient(client, 0.0);
			TE_SetupBeamPoints(landPoints[1], landPoints[2], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToClient(client, 0.0);
			TE_SetupBeamPoints(landPoints[2], landPoints[3], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToClient(client, 0.0);
			TE_SetupBeamPoints(landPoints[3], landPoints[0], BeamSprite, HaloSprite, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, {255, 0, 0, 255}, 10);
			TE_SendToClient(client, 0.0);
		}
	}

	return Plugin_Handled;
}

stock int FindCurrentLand(int ent)
{
	int land = -1;
	float entOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);

	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || Object[client] == null) {
			continue;
		}

		float landPoints[2][3];
		if (!Object[client].GetArray("land.offset", landPoints[1], 3) 
		 || !Object[client].GetArray("land.origin", landPoints[0], 3)) {
			continue;
		}

		if (InLand(entOrigin, landPoints)) {
			land = client;
		}
	}

	if (land != CurrentLand[ent]) {
		if (land != -1) {
			if (1 <= ent <= MaxClients) {
				Land_ClientEntered(ent, land);
			} else {
				Land_EntityEntered(ent, land);
			}
		}
		if (CurrentLand[ent] != -1) {
			if (1 <= ent <= MaxClients) {
				Land_ClientExited(ent, CurrentLand[ent]);
			} else {
				Land_EntityExited(ent, CurrentLand[ent]);
			}
		}

		CurrentLand[ent] = land;
	}

	return land;
}

stock bool InLand(float pos[3], float land[2][3])
{
	float low[2] = {999999.0, ...}, high[2] = {-999999.0, ...}
	for (int i; i < 2; i++) {
		if (low[i] > land[0][i]) {
			low[i] = land[0][i];
		}
		if (high[i] < land[0][i]) {
			high[i] = land[0][i];
		}
		if (low[i] > land[1][i]) {
			low[i] = land[1][i];
		}
		if (high[i] < land[1][i]) {
			high[i] = land[1][i];
		}
	}

	if (pos[0] > low[0] && pos[0] < high[0] && pos[1] > low[1] && pos[1] < high[1]) {
		return true;
	}

	return false;
}

stock bool IntersectingLand(float land1[2][3], float land2[2][3])
{
	float land1Low[2] = {999999.0, ...}, land1High[2] = {-999999.0, ...};
	for (int i; i < 2; i++) {
		if (land1Low[i] > land1[0][i]) {
			land1Low[i] = land1[0][i];
		}
		if (land1High[i] < land1[0][i]) {
			land1High[i] = land1[0][i];
		}
		if (land1Low[i] > land1[1][i]) {
			land1Low[i] = land1[1][i];
		}
		if (land1High[i] < land1[1][i]) {
			land1High[i] = land1[1][i];
		}
	}

	float land2Low[2] = {999999.0, ...}, land2High[2] = {-999999.0, ...}
	for (int i; i < 2; i++) {
		if (land2Low[i] > land2[0][i]) {
			land2Low[i] = land2[0][i];
		}
		if (land2High[i] < land2[0][i]) {
			land2High[i] = land2[0][i];
		}
		if (land2Low[i] > land2[1][i]) {
			land2Low[i] = land2[1][i];
		}
		if (land2High[i] < land2[1][i]) {
			land2High[i] = land2[1][i];
		}
	}

	if (land1High[0] > land2Low[0] && land1Low[0] < land2High[0] && land1High[1] > land2Low[1] && land1Low[1] < land2High[1]) {
		return true;
	}

	return false;
}

stock void GetLandCenter(float land[2][3], float pos[3])
{
	float low[2] = {999999.0, ...}, high[2] = {-999999.0, ...}
	for (int i; i < 2; i++) {
		if (low[i] > land[0][i]) {
			low[i] = land[0][i];
		}
		if (high[i] < land[0][i]) {
			high[i] = land[0][i];
		}
		if (low[i] > land[1][i]) {
			low[i] = land[1][i];
		}
		if (high[i] < land[1][i]) {
			high[i] = land[1][i];
		}
	}

	pos[0] = (low[0] + high[0]) / 2;
	pos[1] = (low[1] + high[1]) / 2;
	pos[2] = land[0][2];
}