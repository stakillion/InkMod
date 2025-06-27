/*
 *
 *	InkMod Build - Entity Move Commands
 *
**/
#define _ink_build_modify_move_


public Action Command_SmoveEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!smove{default} <x> <y> <z>");
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

	int entParent = Entity_GetParent(ent);
	if (entParent != INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Unable to move welded entity.");
		return Plugin_Handled;
	}

	float offset[3];
	char cmdArg[16];

	for (int index = 0; index < 3; index++) {
		GetCmdArg(index + 1, cmdArg, sizeof(cmdArg));
		offset[index] = StringToFloat(cmdArg);

		if (offset[index] < -500 || offset[index] > 500) {
			Ink_ClientMsg(client, "Unable to move - distance too large.");
			return Plugin_Handled;
		}
	}

	float entOrigin[3];
	Entity_GetAbsOrigin(ent, entOrigin);

	AddVectors(entOrigin, offset, entOrigin);
	TeleportEntity(ent, entOrigin, NULL_VECTOR, NULL_VECTOR);

	return Plugin_Handled;
}

public Action Command_MoveToEnt(int client, int args)
{
	static int movetoEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

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

	// if client is not currently 'MoveTo'ing an entity, set MoveTo ent
	if (movetoEnt[client] == INVALID_ENT_REFERENCE) {

		int entParent = Entity_GetParent(ent);
		if (entParent != INVALID_ENT_REFERENCE) {
			Ink_ClientMsg(client, "Unable to move welded entity.");
			return Plugin_Handled;
		}

		movetoEnt[client] = EntIndexToEntRef(ent);

		Ink_ClientEntMsg(client, ent, "Selected {entity} to move. Now do {green}!moveto{default} on target.");

		return Plugin_Handled;
	}
	// or move select MoveTo ent to target

	int firstEnt = EntRefToEntIndex(movetoEnt[client]);
	if (firstEnt == INVALID_ENT_REFERENCE) {
		movetoEnt[client] = INVALID_ENT_REFERENCE;

		Ink_ClientMsg(client, "Couldn't find selected MoveTo entity.");
		return Plugin_Handled;
	}

	float firstEntOrigin[3], entOrigin[3];
	GetEntPropVector(firstEnt, Prop_Data, "m_vecAbsOrigin", firstEntOrigin);
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
	// don't move if the distance is too great
	if (GetVectorDistance(firstEntOrigin, entOrigin) > 500) {
		movetoEnt[client] = INVALID_ENT_REFERENCE;

		Ink_ClientMsg(client, "Unable to move - distance too large.");
		return Plugin_Handled;
	}

	// teleport entity to target
	TeleportEntity(firstEnt, entOrigin, NULL_VECTOR, NULL_VECTOR);

	movetoEnt[client] = INVALID_ENT_REFERENCE;

	Ink_ClientEntMsg(client, firstEnt, "Moved {entity} to target.");

	return Plugin_Handled;
}

public Action Command_DropEnt(int client, int args)
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

	int entParent = Entity_GetParent(ent);
	if (entParent != INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Unable to move welded entity.");
		return Plugin_Handled;
	}

	float entOrigin[3], clientOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
	GetClientEyePosition(client, clientOrigin);
	entOrigin[2] = Math_Min(entOrigin[2], clientOrigin[2]);

	Handle trace = TR_TraceRayFilterEx(entOrigin, view_as<float>({90.0,0.0,0.0}), MASK_SHOT_HULL|MASK_SHOT, RayType_Infinite, Filter_Dissolving, ent);

	if (!TR_DidHit(trace)) {
		Ink_ClientEntMsg(client, ent, "Unable to drop {entity} - couldn't find the ground.");
		delete trace;
		return Plugin_Handled;
	}

	float hitPos[3];
	TR_GetEndPosition(hitPos, trace);
	delete trace;

	float entMins[3];
	GetEntPropVector(ent, Prop_Send, "m_vecMins", entMins);

	hitPos[2] -= entMins[2];
	Entity_SetAbsOrigin(ent, hitPos);

	return Plugin_Handled;
}
