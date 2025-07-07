/*
 *
 *	InkMod Build - Entity Link Commands
 *
**/
#define _ink_build_modify_link_


public Action Command_LinkEnt(int client, int args)
{
	static int linkEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

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

	char entClass[64];
	GetEntityClassname(ent, entClass, sizeof(entClass));
	bool isEntLinkable = (StrContains(entClass, "prop_door") != -1 || StrContains(entClass, "prop_gate") != -1 || StrContains(entClass, "entity_light") != -1);
	bool isEntButton = (StrContains(entClass, "entity_button") != -1);

	// if client is not currently linking an entity, set first ent
	if (linkEnt[client] == INVALID_ENT_REFERENCE) {

		if (!isEntLinkable && !isEntButton) {
			Ink_ClientEntMsg(client, ent, "Unable to link {entity}.");
			return Plugin_Handled;
		}

		// set first ent
		linkEnt[client] = EntIndexToEntRef(ent);
		Ink_ClientMsg(client, "Selected entity to link. Now do {green}!link{default} on target.");
		return Plugin_Handled;
	}

	// get first ent
	int firstEnt = EntRefToEntIndex(linkEnt[client]);
	if (firstEnt == INVALID_ENT_REFERENCE) {
		linkEnt[client] = INVALID_ENT_REFERENCE;
		Ink_ClientMsg(client, "Couldn't find selected entity.");
		return Plugin_Handled;
	}

	GetEntityClassname(firstEnt, entClass, sizeof(entClass));
	bool isFirstLinkable = (StrContains(entClass, "prop_door") != -1 || StrContains(entClass, "prop_gate") != -1 || StrContains(entClass, "entity_light") != -1);
	bool isFirstButton = (StrContains(entClass, "entity_button") != -1);

	int controller = INVALID_ENT_REFERENCE;
	int target = INVALID_ENT_REFERENCE;

	if (isEntLinkable && isFirstButton) {
		controller = firstEnt;
		target = ent;
	} else if (isFirstLinkable && isEntButton) {
		target = firstEnt;
		controller = ent;
	} else {
		Ink_ClientMsg(client, "These entities can't be connected.");
		return Plugin_Handled;
	}

	int ents[6];
	Object[controller].GetArray("links", ents, 6);
	for (int i; i < 6; i++) {
		if (ents[i] == 0) {
			ents[i] = EntIndexToEntRef(target);
			Object[controller].SetArray("links", ents, 6);
			break;
		} else if (i == 5 && ents[i] != 0) {
			Ink_ClientEntMsg(client, controller, "This {entity} has reached the maximum amount of connections (6). Do {green}!unlink{default} to unlink all connections.");
		}
	}

	linkEnt[client] = INVALID_ENT_REFERENCE;

	Ink_ClientEntMsg(client, firstEnt, "Linked {entity} to target.");
	return Plugin_Handled;
}

public Action Command_UnlinkEnt(int client, int args)
{
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

	char entClass[64];
	GetEntityClassname(ent, entClass, sizeof(entClass));
	bool isEntLinkable = (StrContains(entClass, "prop_door") != -1 || StrContains(entClass, "prop_gate") != -1 || StrContains(entClass, "entity_light") != -1);
	bool isEntButton = (StrContains(entClass, "entity_button") != -1);

	if (isEntButton) {
		Object[ent].Remove("links");
		Ink_ClientEntMsg(client, ent, "Destroyed all connections to this {entity}.");
		return Plugin_Handled;

	} else if (isEntLinkable) {
		Ink_DestroyLinks(ent);
        Ink_ClientEntMsg(client, ent, "Destroyed all connections to this {entity}.");
		return Plugin_Handled;
	}

	Ink_ClientMsg(client, "This entity can't be linked.");
	return Plugin_Handled;
}