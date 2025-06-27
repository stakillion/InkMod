/*
 *
 *	InkMod Build - Entity Color Commands
 *
**/
#define _ink_build_modify_color_


public Action Command_ColorEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!color{default} <color name / RGB>");
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

	char cmdArg[3][16];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	String_ToLower(cmdArg[0], cmdArg[0], sizeof(cmdArg[]));

	bool useAlias = false;
	int newColor[4] = {255, ...};
	// copy current ent color so the alpha is unchanged
	Ink_GetEntColor(ent, newColor);

	if (!IsCharNumeric(cmdArg[0][0])) {
		// look for a color by alias
		if (Ink_ColorFromAlias(cmdArg[0], newColor)) {
			useAlias = true;
		} else {
			Ink_ClientMsg(client, "Color not found: {green}%s{default}.", cmdArg[0]);
			return Plugin_Handled;
		}
	} else {
		GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));
		GetCmdArg(3, cmdArg[2], sizeof(cmdArg[]));
		for (int x = 0; x < 3; x++) {
			newColor[x] = StringToInt(cmdArg[x]);
			newColor[x] = Math_Clamp(newColor[x], 0, 255);
		}
	}

	// set color
	Ink_SetEntColor(ent, newColor);

	Ink_ToolEffect(client, hitPos);
	if (useAlias) {
		Ink_ClientEntMsg(client, ent, "Set color of {entity} to {green}%s{default}.", cmdArg[0]);
	} else {
		Ink_ClientEntMsg(client, ent, "Set color of {entity} to ({green}%i %i %i{default}).", newColor[0], newColor[1], newColor[2]);
	}

	return Plugin_Handled;
}

public Action Command_AlphaEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!alpha{default} <50 - 255>");
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

	char cmdArg[16];
	GetCmdArgString(cmdArg, sizeof(cmdArg));

	if (!IsCharNumeric(cmdArg[0])) {
		Ink_ClientMsg(client, "Usage: {green}!alpha{default} <50 - 255>");
		return Plugin_Handled;
	}

	int alpha = StringToInt(cmdArg);
	alpha = Math_Clamp(alpha, 50, 255);

	// copy current ent color
	int entColor[4];
	Ink_GetEntColor(ent, entColor);

	// set alpha
	entColor[3] = alpha;
	Ink_SetEntColor(ent, entColor);

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Set alpha of {entity} to {green}%i{default}.", alpha);

	return Plugin_Handled;
}
