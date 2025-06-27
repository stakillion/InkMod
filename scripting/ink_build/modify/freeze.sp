/*
 *
 *	InkMod Build - Entity Freeze Commands
 *
**/
#define _ink_build_modify_freeze_


public Action Command_FreezeEnt(int client, int args)
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

	int entParent = Entity_GetParent(ent);
	if (entParent != INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Unable to change physics of welded entity.");
		return Plugin_Handled;
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_physics") == 0 || StrContains(entClass, "prop_light") == 0 || StrContains(entClass, "prop_ladder") == 0 || StrContains(entClass, "prop_internet") == 0) {
		Ink_SetEntFrozen(ent, true);

	} else if (StrContains(entClass, "prop_doll") == 0) {
		Ink_SetEntPlaybackRate(ent, 0.0);

	} else {
		Ink_ClientEntMsg(client, ent, "Unable to change physics of {entity}.");
		return Plugin_Handled;
	}

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Disabled motion on {entity}.");

	return Plugin_Handled;
}

public Action Command_UnfreezeEnt(int client, int args)
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

	int entParent = Entity_GetParent(ent);
	if (entParent != INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Unable to change physics of parented entity.");
		return Plugin_Handled;
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_physics") == 0 || StrContains(entClass, "prop_light") == 0 || StrContains(entClass, "prop_ladder") == 0 || StrContains(entClass, "prop_internet") == 0) {
		Ink_SetEntFrozen(ent, false);

	} else if (StrContains(entClass, "prop_doll", false) == 0) {
		Ink_SetEntPlaybackRate(ent, 1.0);

	} else {
		Ink_ClientEntMsg(client, ent, "Unable to change physics of {entity}.");
		return Plugin_Handled;
	}

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Enabled motion on {entity}.");

	return Plugin_Handled;
}
