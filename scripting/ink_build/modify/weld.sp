/*
 *
 *	InkMod Build - Entity Weld Commands
 *
**/
#define _ink_build_modify_weld_


public Action Command_ParentEnt(int client, int args)
{
	static int weldEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

	// find entity under the player's crosshair
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (!Ink_CheckEntOwner(ent, client)) {
		Ink_ClientMsg(client, "This entity doesn't belong to you.");
		return Plugin_Handled;
	}

	// if client is not currently welding an entity, set weld ent
	if (weldEnt[client] == INVALID_ENT_REFERENCE) {

		int entParent = Ink_GetEntParent(ent);
		if (entParent != INVALID_ENT_REFERENCE) {
			Ink_ClientMsg(client, "This entity is already welded. Do {green}!release{default} on parent to unweld.");
			return Plugin_Handled;
		}

		if (Entity_GetNextChild(ent) != INVALID_ENT_REFERENCE) {
			Ink_ClientMsg(client, "This entity is a parent. Do {green}!release{default} to unparent welded entities.");
			return Plugin_Handled;
		}

		// set weld ent
		weldEnt[client] = EntIndexToEntRef(ent);

		Ink_ClientMsg(client, "Selected entity to weld. Now do {green}!weld{default} on target.");

		return Plugin_Handled;
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_light") == 0 || StrContains(entClass, "prop_ladder") == 0) {
		weldEnt[client] = INVALID_ENT_REFERENCE;
		Ink_ClientEntMsg(client, ent, "{entity} cannot become a move parent.");
		return Plugin_Handled;
	}

	// get weld ent
	int firstEnt = EntRefToEntIndex(weldEnt[client]);
	if (firstEnt == INVALID_ENT_REFERENCE) {
		weldEnt[client] = INVALID_ENT_REFERENCE;
		Ink_ClientMsg(client, "Couldn't find selected entity.");
		return Plugin_Handled;
	}

	ent = Ink_GetEntTopParent(ent);

	float firstEntOrigin[3], entOrigin[3];
	GetEntPropVector(firstEnt, Prop_Data, "m_vecAbsOrigin", firstEntOrigin);
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
	// don't parent if the distance is too great
	if (GetVectorDistance(firstEntOrigin, entOrigin) > 500) {
		weldEnt[client] = INVALID_ENT_REFERENCE;

		Ink_ClientMsg(client, "Unable to weld - distance too large.");
		return Plugin_Handled;
	}

	// freeze entity
	Ink_SetEntFrozen(ent, true);

	// set parent
	Ink_SetEntParent(firstEnt, ent);

	weldEnt[client] = INVALID_ENT_REFERENCE;

	Ink_ClientEntMsg(client, firstEnt, "Welded {entity} to target.");
	Ink_WeldEffect(firstEnt, ent);
	return Plugin_Handled;
}

public Action Command_UnparentEnt(int client, int args)
{
	if (args > 0) {
		char cmdArg[16];
		GetCmdArg(1, cmdArg, sizeof(cmdArg));

		if (StrEqual(cmdArg, "all", false)) {
			int entCount = Weld_ReleaseAll(client);

			Ink_ClientMsg(client, "Released {green}%i{default} entities.", entCount);

			return Plugin_Handled;
		}
	}

	// find entity under the player's crosshair
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (!Ink_CheckEntOwner(ent, client)) {
		Ink_ClientMsg(client, "This entity doesn't belong to you.");
		return Plugin_Handled;
	}

	int entCount = Weld_ReleaseEnt(ent);

	if (entCount > 0) {
		Ink_ClientEntMsg(client, ent, "Released {green}%i{default} entities from {entity}.", entCount);
	} else {
		Ink_ClientMsg(client, "Nothing is welded to this entity.");
	}

	return Plugin_Handled;
}

int Weld_ReleaseEnt(int ent)
{
	int count = 0;

	for (int child = Entity_GetNextChild(ent); child != INVALID_ENT_REFERENCE; child = Entity_GetNextChild(ent, ++child)) {
		Ink_ClearEntParent(child);
		count++;
	}

	return count;
}

int Weld_ReleaseAll(int client)
{
	int count = 0;

	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {

		if (!Ink_CheckEntOwner(ent, client)) {
			continue;
		}

		int entParent = Ink_GetEntParent(ent);
		if (entParent == INVALID_ENT_REFERENCE) {
			continue;
		}

		Ink_ClearEntParent(ent);

		count++;
	}

	return count;
}
