/*
 *
 *	InkMod Build - Client Stocks
 *	Stocks for handling of client data
 *
**/
#define _ink_build_stocks_client_


#define INK_CLIENTMSG_TAG "{blue}[Ink]{default}"


stock void Ink_ClientMsg(int client, const char[] message, any:...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 3);

	CPrintToChat(client, "%s %s", INK_CLIENTMSG_TAG, buffer);
}

stock void Ink_ClientEntMsg(int client, int ent, const char[] message, any:...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 4);

	if (ent != -1) {

		char entName[64];
		GetEntityClassname(ent, entName, sizeof(entName));

		char explodedName[2][64];
		ExplodeString(entName, "_", explodedName, 2, sizeof(explodedName[]));
		Format(entName, sizeof(entName), "%s %s", explodedName[1], explodedName[0]);

		ReplaceString(buffer, sizeof(buffer), "{entity}", entName, false);
	}

	Ink_ClientMsg(client, buffer);
}

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
		if (StrContains(entClass, "prop_light", false) != -1) {
			lightCount++;
		}
		if (StrContains(entClass, "vehicle", false) != -1) {
			vehicleCount++;
		}
	}

	if (entCount + add > ink_maxplayerents.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of entities: {green}%i{default}.", entCount);
		}
		return false;
	}

	if (StrContains(class, "prop_light", false) != -1 && lightCount + add > ink_maxplayerlights.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of lights: {green}%i{default}.", lightCount);
		}
		return false;
	}

	if (StrContains(class, "prop_vehicle", false) != -1 && vehicleCount + add > ink_maxplayervehicles.IntValue) {
		if (notify) {
			Ink_ClientMsg(client, "Reached maximum number of vehicles: {green}%i{default}.", vehicleCount);
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