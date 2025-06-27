/*
 *
 *	InkMod Build - Entity Skin Command
 *
**/
#define _ink_build_modify_skin_


public Action Command_SkinEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!skin{default} <skin number>");
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

	char cmdArg[16];
	GetCmdArgString(cmdArg, sizeof(cmdArg));

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	bool isDoll = (StrContains(entClass, "prop_doll", false) == 0);

	int skin;
	if (cmdArg[0] == '+' || cmdArg[0] == '-') {
		if (isDoll) {
			skin = Ink_GetEntSequence(ent) + StringToInt(cmdArg);
		} else {
			skin = Ink_GetEntSkin(ent) + StringToInt(cmdArg);
		}
	} else {
		skin = StringToInt(cmdArg);
	}
	skin = Math_Min(skin, 0);

	// set skin
	if (isDoll) {
		// set sequence if it's a doll prop
		Ink_SetEntSequence(ent, skin);
		Ink_ClientEntMsg(client, ent, "Set sequence of {entity} to {green}%i{default}.", skin);

	} else {
		Ink_SetEntSkin(ent, skin);
		Ink_ClientEntMsg(client, ent, "Set skin of {entity} to {green}%i{default}.", skin);
	}

	return Plugin_Handled;
}
