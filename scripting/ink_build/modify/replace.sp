/*
 *
 *	InkMod Build - Entity Replace Commands=
 *
**/
#define _ink_build_modify_replace_


public Action Command_ReplaceEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!replace{default} <prop name>");
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

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
	if (StrContains(entClass, "prop_physics") == -1 && StrContains(entClass, "prop_door") == -1 && StrContains(entClass, "prop_light") == -1) {
		Ink_ClientEntMsg(client, ent, "Unable to replace model on {entity}.");
		return Plugin_Handled;
	}

	char alias[64];
	GetCmdArg(1, alias, sizeof(alias));
	String_ToLower(alias, alias, sizeof(alias));

	// get prop data
	char model[PLATFORM_MAX_PATH], animation[32];
	bool enabled;
	int type, solid;

	if ((type = Ink_ModelFromAlias(alias, model, sizeof(model), animation, sizeof(animation), solid, enabled)) == -1) {
		Ink_ClientMsg(client, "Prop not found: {green}%s{default}.", alias);
		return Plugin_Handled;
	}
	if (!enabled && !CheckCommandAccess(client, "ink_root", ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This prop has been discontinued: {green}%s{default}.", alias);
		return Plugin_Handled;
	}

	PrecacheModel(model, true);
	SetEntityModel(ent, model);
	ActivateEntity(ent);

	Entity_SetName(ent, "%s%i", alias, EntIndexToEntRef(ent));

	Ink_ClientEntMsg(client, ent, "Set model on {entity} to {green}%s{default}.", alias);
	Ink_ToolEffect(client, hitPos);

	return Plugin_Handled;
}
