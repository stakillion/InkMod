/*
 *
 *	InkMod Build - Entity Spawn: Ladder
 *
**/
#define _ink_build_spawn_internet_


stock int Ink_CreateInternet(const char[] modelPath)
{
	// create entity
	int ent = CreateEntityByName("prop_physics_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for prop_internet
	DispatchKeyValue(ent, "classname", "prop_internet");

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// hook use
	SDKHook(ent, SDKHook_Use, OnInternetUse)
	Entity_AddSpawnFlags(ent, 256);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnInternet(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "prop_internet")) {
		return Plugin_Handled;
	}

	// create entity
	int ent = Ink_CreateInternet("models/props_lab/monitor02.mdl");

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning internet prop.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "internet%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	return Plugin_Handled;
}

public Action Command_SetURLEnt(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!seturl{default} <internet URL>");
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
	if (StrContains(entClass, "prop_internet") != 0) {
		Ink_ClientEntMsg(client, ent, "This command can only be used on {green}!internet{default} props.");
		return Plugin_Handled;
	}

	char cmdArg[256];
	GetCmdArgString(cmdArg, sizeof(cmdArg));
	Object[ent].SetString("url", cmdArg, true);

	Ink_ToolEffect(client, hitPos);
	Ink_ClientEntMsg(client, ent, "Set URL on internet prop to {green}%s{default}.", cmdArg);

	return Plugin_Handled;
}

public Action OnInternetUse(int entity, int activator, int caller, UseType type, float value)
{
	char url[256];
	if (!Object[entity].GetString("url", url, sizeof(url))) {
		Ink_ClientMsg(activator, "Do {green}!seturl{default} to attach a URL to this internet prop.");
		return Plugin_Continue;
	}

	if (StrContains(url, "://") == -1) {
		Format(url, sizeof(url), "http://%s", url);
	}

	KeyValues kv = new KeyValues("data");
	kv.SetString("title", "Internet");
	kv.SetNum("type", MOTDPANEL_TYPE_URL);
	kv.SetString("msg", url);

	ShowVGUIPanel(activator, "info", kv, true);
	delete kv;
}