/*
 *
 *	InkMod Build - Entity Ownership Commands
 *
**/
#define _ink_build_modify_owner_


int NewOwner[MAX_EDICTS + 1] = {-1, ...};


public Action Command_GetEntOwner(int client, int args)
{
	// get client aim target
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}

	int ownerId;
	int owner = Ink_GetEntOwner(ent, ownerId);

	// owner error
	if (owner == -1) {
		Ink_ClientMsg(client, "This entity is not owned by anyone.");
		return Plugin_Handled;
	}
	if (owner == 0) {
		Ink_ClientMsg(client, "This entity's owner is disconnected [{green}%i{default}]", ownerId);
		return Plugin_Handled;
	}

	char ownerName[64];
	GetClientName(owner, ownerName, sizeof(ownerName));

	// respond with owner name
	Ink_ClientMsg(client, "This entity is owned by {green}%s{default} [{green}%i{default}]", ownerName, ClientId[owner]);
	return Plugin_Handled;
}

public Action Command_GiveEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!give{default} <player name> or #cancel");
		return Plugin_Handled;
	}

	// find entity under the player's crosshair
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (!Ink_CheckEntOwner(ent, client, ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This entity doesn't belong to you.");
		return Plugin_Handled;
	}

	int entParent = Entity_GetParent(ent);
	if (entParent != INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Unable to change owner of welded entity.");
		return Plugin_Handled;
	}

	// find recipient based on given name
	char targetName[64];
	GetCmdArgString(targetName, sizeof(targetName));
	if (StrEqual(targetName, "#cancel", false)) {
		if (NewOwner[ent] == -1) {
			return Plugin_Handled;
		}

		Ink_ClientMsg(client, "Cancelled entity ownership offer.");
		NewOwner[ent] = -1;
	}

	int targetClient = Client_FindByName(targetName);

	if (targetClient == -1) {
		Ink_ClientMsg(client, "Could not find a player matching \"{green}%s{default}\"", targetName);
		return Plugin_Handled;
	}
	if (targetClient == Ink_GetEntOwner(ent)) {
		Ink_ClientMsg(client, "You already own this entity!");
		return Plugin_Handled;
	}

	GetClientName(targetClient, targetName, sizeof(targetName));
	Ink_ClientEntMsg(client, ent, "Offering {entity} to {green}%s{default}.", targetName);
	Ink_ClientEntMsg(client, ent, "Do {green}!give #cancel{default} to stop ownership offer.");

	char ownerName[64];
	GetClientName(client, ownerName, sizeof(ownerName));
	Ink_ClientMsg(targetClient, "{green}%s{default} has offered an entity to you. Do {green}!claim{default} on it to accept.", ownerName);
	NewOwner[ent] = targetClient;

	return Plugin_Handled;
}

public Action Command_ClaimEnt(int client, int args)
{
	// find entity under the player's crosshair
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (NewOwner[ent] != client && !CheckCommandAccess(client, "ink_root", ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This entity is not available to claim.");
		return Plugin_Handled;
	}

	// check entity limits
	char entClass[64];
	GetEntityClassname(ent, entClass, sizeof(entClass));
	if (!Ink_CheckClientLimit(client, entClass)) {
		return Plugin_Handled;
	}

	if (Object[ent] == null) {
		Object[ent] = GetInkObject(ent, true);
		Ink_SetEntOwner(ent, client);
		Ink_ClientEntMsg(client, ent, "Accepted {entity} from the map.");
		return Plugin_Handled;
	}

	int owner = Ink_GetEntOwner(ent);

	char clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
	Ink_ClientEntMsg(owner, ent, "Gave {entity} to {green}%s{default}.", clientName);

	char ownerName[64];
	GetClientName(owner, ownerName, sizeof(ownerName));
	Ink_ClientEntMsg(client, ent, "Accepted {entity} from {green}%s{default}.", ownerName);

	Ink_SetEntOwner(ent, client);
	NewOwner[ent] = -1;

	return Plugin_Handled;
}