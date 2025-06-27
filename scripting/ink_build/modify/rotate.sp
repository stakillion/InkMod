/*
 *
 *	InkMod Build - Entity Rotate Commands
 *
**/
#define _ink_build_modify_rotate_


public Action Command_RotateEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!rotate{default} <roll> <yaw> <pitch>");
		return Plugin_Handled;
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

	float angles[3];
	char cmdArg[16];
	for (int index = 0; index < 3; index++) {
		GetCmdArg(index + 1, cmdArg, sizeof(cmdArg));
		angles[index] = StringToFloat(cmdArg);
	}

	float entAngles[3];
	Entity_GetAbsAngles(ent, entAngles);
	AddVectors(angles, entAngles, angles);

	Entity_SetAbsAngles(ent, angles);
	EmitSoundToAll("buttons/lever7.wav", ent);

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_door") == 0) {
		DispatchSpawn(ent);
	}

	return Plugin_Handled;
}

public Action Command_StandEnt(int client, int args)
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

	Entity_SetAbsAngles(ent, ZERO_VECTOR);
	EmitSoundToAll("buttons/lever7.wav", ent);

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_door") == 0) {
		DispatchSpawn(ent);
	}

	return Plugin_Handled;
}
