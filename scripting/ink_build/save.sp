/*
 *
 *	InkMod Build - Build saving and loading
 *
**/
#define _ink_build_land_save_
#include "ink_build/stocks/duplicator"


char SavingName[MAXPLAYERS + 1][32];
bool SavingState[MAXPLAYERS + 1];


public Action Command_Save(int client, int args)
{
	float landPoints[2][3];
	if (!Object[client].GetArray("land.offset", landPoints[1], 3) 
	 || !Object[client].GetArray("land.origin", landPoints[0], 3)) {
		Ink_ClientMsg(client, "You must set up your {green}!land{default} area first.");
		return Plugin_Handled;
	}

	int entsIn, entsOut;

	if (StrEqual(SavingName[client], "")) {
		GetCmdArg(1, SavingName[client], sizeof(SavingName[]));

		String_ToLower(SavingName[client], SavingName[client], sizeof(SavingName[]));
		StripQuotes(SavingName[client]);
		TrimString(SavingName[client]);

		bool customName = true;
		if (StrEqual(SavingName[client], "")) {
			customName = false;
		} else if (!IsAlphanumeric(SavingName[client])) {
			Ink_ClientMsg(client, "Build name can only contain letters and numbers.");
			strcopy(SavingName[client], sizeof(SavingName[]), "");
			return Plugin_Handled;
		}

		char globalName[64];
		char saveName[2][32];
		for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
			if (!IsValidEntity(ent)) {
				continue;
			}

			if (!Ink_CheckEntOwner(ent, client)) {
				continue;
			}

			float entOrigin[3];
			GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
			if (!InLand(entOrigin, landPoints)) {
				entsOut++;
				continue;
			}

			entsIn++
			GetEntPropString(ent, Prop_Data, "m_iGlobalname", globalName, sizeof(globalName));
			ExplodeString(globalName, "-", saveName, 2, sizeof(saveName[]));

			if (!StrEqual(saveName[0], "")) {
				if (StrEqual(SavingName[client], "")) {
					Format(SavingName[client], sizeof(SavingName[]), saveName[0]);
				} else if (!StrEqual(saveName[0], SavingName[client], false) && !customName) {
					Ink_ClientMsg(client, "Multiple builds found within land area.");
					Ink_ClientMsg(client, "Specify a build name to save.");
					return Plugin_Handled;
				}
			}
		}

		if (entsIn < 1) {
			Ink_ClientMsg(client, "No entities found within land.");
			return Plugin_Handled;
		}

		if (StrEqual(SavingName[client], "")) {
			Ink_ClientMsg(client, "Specify a build name to save.");
			return Plugin_Handled;
		}
	}

	if (!SavingState[client]) {
		if (entsOut < 1) {
			Ink_ClientMsg(client, "Saving {green}%d{default} entities to build {green}%s{default}. (All entities are inside land)", entsIn, SavingName[client]);
		} else if (entsOut == 1) {
			Ink_ClientMsg(client, "Saving {green}%d{default} entities to build {green}%s{default}. ({green}1{default} entity is outside land)", entsIn, SavingName[client]);
		} else {
			Ink_ClientMsg(client, "Saving {green}%d{default} entities to build {green}%s{default}. ({green}%d{default} entities are outside land)", entsIn, SavingName[client], entsOut);
		}

		Ink_ClientMsg(client, "Do {green}!save{default} again to save your build.", SavingName[client]);

		SavingState[client] = true;
		return Plugin_Handled;
	}

	SavingState[client] = false;

	char savePath[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, savePath, sizeof(savePath), "data/inkmod/saves");
	if (!DirExists(savePath)) {
		CreateDirectory(savePath, 511);
	}

	BuildPath(Path_SM, savePath, sizeof(savePath), "data/inkmod/saves/%i", ClientId[client]);
	if (!DirExists(savePath)) {
		CreateDirectory(savePath, 511);
	}

	BuildPath(Path_SM, savePath, sizeof(savePath), "data/inkmod/saves/%i/%s.txt", ClientId[client], SavingName[client]);

	float landCenter[3];
	GetLandCenter(landPoints, landCenter);

	OpenFile(savePath, "w+");
	KeyValues saveKv = new KeyValues("Entities");

	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
		if (!IsValidEntity(ent)) {
			continue;
		}

		if (!Ink_CheckEntOwner(ent, client)) {
			continue;
		}

		float entOrigin[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
		if (!InLand(entOrigin, landPoints)) {
			continue;
		}

		Ink_EntToKeyValues(ent, saveKv, landCenter);

		char newName[64];
		Format(newName, sizeof(newName), "%s%i", SavingName[client], EntIndexToEntRef(ent));
		DispatchKeyValue(ent, "globalname", newName);
	}

	saveKv.ExportToFile(savePath);
	delete saveKv;

	Ink_ClientMsg(client, "Saved build under name {green}%s{default}.", SavingName[client]);

	Format(SavingName[client], sizeof(SavingName[]), "");

	return Plugin_Handled;
}

public Action Command_Load(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!load{default} <save name>");
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	char saveName[32];
	GetCmdArg(1, saveName, sizeof(saveName));
	String_ToLower(saveName, saveName, sizeof(saveName));

	if (!IsAlphanumeric(saveName)) {
		Ink_ClientMsg(client, "Build name can only contain letters and numbers.");
		return Plugin_Handled;
	}

	char savePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, savePath, sizeof(savePath), "data/inkmod/saves/%i/%s.txt", ClientId[client], saveName);
	if (!FileExists(savePath)) {
		Ink_ClientMsg(client, "Could not find build {green}%s{default}.", saveName);
		return Plugin_Handled;
	}

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

		if (StrEqual(entSaveName[0], saveName)) {
			Ink_ClientMsg(client, "Build already loaded: {green}%s{default}.", saveName);
			Ink_ClientMsg(client, "Do {green}!remove %s{default} to remove.", saveName);
			return Plugin_Handled;
		}
	}

	float origin[3];
	Ink_GetClientAim(client, origin);

	KeyValues loadKv = new KeyValues("Entities");
	loadKv.ImportFromFile(savePath);

	if (!loadKv.GotoFirstSubKey(false)) {
		Ink_ClientMsg(client, "Save file {green}%s{default} is corrupt.", saveName);
		delete loadKv;
		return Plugin_Handled;
	}

	do {
		int ent = Ink_KeyValuesToEnt(loadKv, origin);

		char keyName[64], entKey[3][32];
		loadKv.GetSectionName(keyName, sizeof(keyName));
		ExplodeString(keyName, "-", entKey, 3, sizeof(entKey[]));

		char globalName[64];
		Format(globalName, sizeof(globalName), "%s-%i", saveName, entKey[2]);
		DispatchKeyValue(ent, "globalname", globalName);

		Ink_SetEntOwner(ent, client);
	} while (loadKv.GotoNextKey())

	delete loadKv;

	Ink_ClientMsg(client, "Loaded build {green}%s{default}.", saveName);
	return Plugin_Handled;
}