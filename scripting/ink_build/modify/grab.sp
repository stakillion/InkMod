/*
 *
 *	InkMod Build - Entity Grab Commands
 *
**/
#define _ink_build_modify_grab_
#include "ink_build/stocks/duplicator"


int GrabEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
float GrabOffset[MAXPLAYERS + 1][3];


public Action Command_MoveEnt(int client, int args)
{
	int ent = EntRefToEntIndex(GrabEnt[client]);

	// if client is currently moving an entity, stop moving
	if (ent != INVALID_ENT_REFERENCE) {
		EndGrab(client);
		return Plugin_Handled;
	}
	// do not start move if command is -move
	char cmdName[8];
	GetCmdArg(0, cmdName, sizeof(cmdName));
	if (StrEqual(cmdName, "-move", false)) {
		return Plugin_Handled;
	}

	// find entity under the player's crosshair
	ent = Ink_GetClientAim(client);

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
		Ink_ClientMsg(client, "Unable to move parented entity.");
		return Plugin_Handled;
	}

	// start grab
	StartGrab(client, ent);

	return Plugin_Handled;
}

public Action Command_CopyEnt(int client, int args)
{
	int ent = EntRefToEntIndex(GrabEnt[client]);

	// if client is currently moving an entity, stop moving
	if (ent != INVALID_ENT_REFERENCE) {
		EndGrab(client);
		return Plugin_Handled;
	}
	// do not start copy if command is -copy
	char cmdName[8];
	GetCmdArg(0, cmdName, sizeof(cmdName));
	if (StrEqual(cmdName, "-copy", false)) {
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	// find entity under the player's crosshair
	ent = Ink_GetClientAim(client);

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

	// spawn copy
	int entCopy = Ink_KeyValuesToEnt(entCopyKv);
	delete entCopyKv;
	if (entCopy == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error attempting to spawn duplicated entity!");
		return Plugin_Handled;
	}

	// give to player
	Ink_SetEntOwner(entCopy, client);

	// start grab
	StartGrab(client, entCopy, {96, 64, 255, 200});

	return Plugin_Handled;
}

void StartGrab(int client, int ent, int color[4] = {0, 255, 128, 200})
{
	// freeze entity
	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_physics", false) == 0) {
		Ink_SetEntFrozen(ent, true, false);
	}

	// color entity
	SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);

	GrabEnt[client] = EntIndexToEntRef(ent);

	float entOrigin[3], clientOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
	GetClientAbsOrigin(client, clientOrigin);

	SubtractVectors(clientOrigin, entOrigin, entOrigin);
	GrabOffset[client] = entOrigin;

	// start tick
	RequestFrame(GrabTick, client);
}

void EndGrab(int client)
{
	int ent = EntRefToEntIndex(GrabEnt[client]);
	GrabEnt[client] = INVALID_ENT_REFERENCE;

	// restore movetype
	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_physics", false) == 0) {
		bool frozen = Ink_GetEntFrozen(ent);
		Ink_SetEntFrozen(ent, frozen, false);
	}

	// restore color
	int entColor[4];
	Ink_GetEntColor(ent, entColor);

	if (entColor[3] == 255) {
		SetEntityRenderMode(ent, RENDER_NORMAL);
	}
	Entity_SetRenderColor(ent, entColor[0], entColor[1], entColor[2], entColor[3]);
}

public void GrabTick(int client)
{
	// if stored grab entity is not valid, break
	int ent = EntRefToEntIndex(GrabEnt[client]);
	if (ent == INVALID_ENT_REFERENCE) {
		GrabEnt[client] = INVALID_ENT_REFERENCE;
		return;
	}

	// get client origin
	float clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);

	// set new entity origin relative to player
	float entOrigin[3];
	SubtractVectors(clientOrigin, GrabOffset[client], entOrigin);
	TeleportEntity(ent, entOrigin, NULL_VECTOR, NULL_VECTOR);

	// tick
	RequestFrame(GrabTick, client);
}
