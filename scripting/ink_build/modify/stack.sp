/*
 *
 *	InkMod Build - Entity Stack Commands
 *
**/
#define _ink_build_modify_stack_
#include "ink_build/stocks/duplicator"


public Action Command_StackEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!stack{default} <x> <y> <z>");
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
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

	// check entity limits
	char entClass[64];
	GetEntityClassname(ent, entClass, sizeof(entClass));
	if (!Ink_CheckClientLimit(client, entClass)) {
		return Plugin_Handled;
	}

	float offset[3];
	for (int index = 0; index < 3; index++) {
		offset[index] = GetCmdArgFloat(index + 1);
		if (offset[index] < -500 || offset[index] > 500) {
			Ink_ClientMsg(client, "Unable to stack - distance too large.");
			return Plugin_Handled;
		}
	}

	char alias[2][64];
	GetEntPropString(ent, Prop_Data, "m_iName", alias[0], sizeof(alias[]));
	ExplodeString(alias[0], "-", alias, 2, sizeof(alias[]));
	bool enabled = false;
	Ink_ModelFromAlias(alias[0], "", 0, "", 0, enabled);
	if (!enabled && !CheckCommandAccess(client, "ink_root", ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This prop has been discontinued: {green}%s{default}.", alias[0]);
		return Plugin_Handled;
	}

	// store copy
	KeyValues entCopyKv = Ink_EntToKeyValues(ent);
	if (entCopyKv == view_as<KeyValues>(INVALID_HANDLE)) {
		Ink_ClientEntMsg(client, ent, "Error attempting to duplicate {entity}!");
		return Plugin_Handled;
	}

	float entAngles[3];
	Entity_GetAbsAngles(ent, entAngles);

	// spawn copy
	int entCopy = Ink_KeyValuesToEnt(entCopyKv, offset, entAngles);
	delete entCopyKv;
	if (entCopy == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error attempting to spawn duplicated entity!");
		return Plugin_Handled;
	}

	// give to player
	Ink_SetEntOwner(entCopy, client);

	// sound effect
	switch (GetRandomInt(0, 2)) {
		case 0: {
			EmitSoundToAll("physics/concrete/concrete_impact_soft1.wav", entCopy);
		}
		case 1: {
			EmitSoundToAll("physics/concrete/concrete_impact_soft2.wav", entCopy);
		}
		case 2: {
			EmitSoundToAll("physics/concrete/concrete_impact_soft3.wav", entCopy);
		}
	}

	return Plugin_Handled;
}
