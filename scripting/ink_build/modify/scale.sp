/*
 *
 *	InkMod Build - Entity Scale Command
 *
**/
#define _ink_build_modify_scale_


public Action Command_ScaleEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!scale{default} <scale percentage>");
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

	// get player requested scale
	char cmdArg[16];
	GetCmdArgString(cmdArg, sizeof(cmdArg));
	int cmdArgInt = StringToInt(cmdArg);
	float newScale = float(cmdArgInt)/100;

	// get current entity scale
	float entScale = GetEntPropFloat(ent, Prop_Data, "m_flModelScale");
	float entMins[3], entMaxs[3];
	Entity_GetMinSize(ent, entMins);
	Entity_GetMaxSize(ent, entMaxs);

	// get original model bounds
	ScaleVector(entMins, 1/entScale);
	ScaleVector(entMaxs, 1/entScale);

	// get original model radius
	float entSize[3];
	SubtractVectors(entMaxs, entMins, entSize);
	float entRadius = GetVectorLength(entSize)/2;

	// get bounds of scaled model
	ScaleVector(entMins, newScale);
	ScaleVector(entMaxs, newScale);

	// get radius of scaled model
	SubtractVectors(entMaxs, entMins, entSize);
	float newRadius = GetVectorLength(entSize)/2;

	// limit new model scale based on radius
	float minRadius = Math_Max(12.5, entRadius);
	float maxRadius = Math_Min(200.0, entRadius);

	if (newRadius > maxRadius) {
		Ink_ClientMsg(client, "Requested scale {green}%i%%{default} is too large!", cmdArgInt);
		return Plugin_Handled;
	}
	if (newRadius < minRadius) {
		Ink_ClientMsg(client, "Requested scale {green}%i%%{default} is too small!", cmdArgInt);
		return Plugin_Handled;
	}

	// set new scale
	Ink_SetEntScale(ent, newScale);

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Set scale of {entity} to {green}%i%s{default}.", cmdArgInt, "%%");

	return Plugin_Handled;
}
