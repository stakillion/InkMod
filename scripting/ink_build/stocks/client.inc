/*
 *
 *	InkMod Build - Client Stocks
 *	Stocks for handling of client data
 *
**/
#define _ink_build_stocks_client_


stock int Ink_GetClientById(int id)
{
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientAuthorized(client)) {

			if (id == ClientId[client]) {
				// found client
				return client;
			}
		}
	}

	return 0;
}

stock bool Ink_CheckClientLimit(int client, char[] class, int add = 1, bool notify = true)
{
	int entCount, lightCount, vehicleCount;
	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {

		if (!Ink_CheckEntOwner(ent, client)) {
			continue;
		}

		// found an entity belonging to this player
		entCount++;

		char entClass[64];
		GetEntityClassname(ent, entClass, sizeof(entClass));
		if (StrContains(entClass, "entity_light", false) != -1) {
			lightCount++;
		}
		if (StrContains(entClass, "prop_vehicle", false) != -1) {
			vehicleCount++;
		}
	}

	if (entCount + add > ink_maxplayerents.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of entities: {green}%i{default}.", ink_maxplayerents.IntValue);
		}
		return false;
	}

	if (StrContains(class, "entity_light", false) != -1 && lightCount + add > ink_maxplayerlights.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of lights: {green}%i{default}.", ink_maxplayerlights.IntValue);
		}
		return false;
	}

	if (StrContains(class, "prop_vehicle", false) != -1 && vehicleCount + add > ink_maxplayervehicles.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of vehicles: {green}%i{default}.", ink_maxplayervehicles.IntValue);
		}
		return false;
	}

	return true;
}

stock bool Ink_LimitClientSpeed(int client, float delay = 1.25, bool notify = true)
{
	float time = GetGameTime();
	if (ClientCmdTime[client] < time - delay) {
		ClientCmdTime[client] = time;
		return true;
	} else if (notify) {
		Ink_ClientMsg(client, "You are sending commands too fast!");
	}

	ClientCmdTime[client] = time;
	return false;
}

stock int Ink_CleanClientEnts(int client)
{
	int entCount;
	// loop through all entities, counting any that belong to the player
	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {

		if (!Ink_CheckEntOwner(ent, client)) {
			continue;
		}

		// found an entity belonging to this player
		entCount++;
		Ink_RemoveEnt(ent, false);
	}

	return entCount;
}