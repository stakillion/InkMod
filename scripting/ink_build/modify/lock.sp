/*
 *
 *	InkMod Build - Entity Lock Commands
 *
**/
#define _ink_build_modify_lock_


public Action Command_LockEnt(int client, int args)
{
	// find entity under the player's crosshair
	float hitPos[3];
	int ent = Ink_GetClientAim(client, hitPos);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (!Ink_CheckEntOwner(ent, client)) {
		Ink_ClientMsg(client, "This entity doesn't belong to you.");
		return Plugin_Handled;
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_door") == -1 && StrContains(entClass, "prop_light") == -1 && StrContains(entClass, "prop_doll") == -1 && StrContains(entClass, "prop_internet") == -1) {
		Ink_ClientEntMsg(client, ent, "Unable to lock {entity}.");
		return Plugin_Handled;
	}

	Ink_SetEntLocked(ent, true);

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Locked {entity}.");

	return Plugin_Handled;
}

public Action Command_UnlockEnt(int client, int args)
{
	// find entity under the player's crosshair
	float hitPos[3];
	int ent = Ink_GetClientAim(client, hitPos);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "You're not looking at anything.");
		return Plugin_Handled;
	}
	if (!Ink_CheckEntOwner(ent, client)) {
		Ink_ClientMsg(client, "This entity doesn't belong to you.");
		return Plugin_Handled;
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_door") == -1 && StrContains(entClass, "prop_light") == -1 && StrContains(entClass, "prop_doll") == -1 && StrContains(entClass, "prop_internet") == -1) {
		Ink_ClientEntMsg(client, ent, "Unable to unlock {entity}.");
		return Plugin_Handled;
	}

	Ink_SetEntLocked(ent, false);

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Unlocked {entity}.");

	return Plugin_Handled;
}
