/*
 *
 *	InkMod Build - Entity Stocks
 *	Stocks for handling of entity data
 *
**/
#define _ink_build_stocks_entity_


stock void Ink_RemoveEnt(int ent, bool dissolve = false)
{
	// check for child entities
	for (int child = Entity_GetNextChild(ent); child != INVALID_ENT_REFERENCE; child = Entity_GetNextChild(ent, ++child)) {
		// if it's an entity we care about, we're saving it
		if (Object[child] != null) {
			Ink_ClearEntParent(child);
		}
	}

	if (dissolve) {
		// create dissolver entity if it does not exist
		int dissolver = EntRefToEntIndex(InkDissolver);
		if (dissolver == INVALID_ENT_REFERENCE) {

			dissolver = CreateEntityByName("env_entity_dissolver");

			DispatchKeyValue(dissolver, "target", "dissolving");
			DispatchKeyValue(dissolver, "magnitude", "0");
			DispatchKeyValue(dissolver, "dissolvetype", "3");

			DispatchSpawn(dissolver);

			InkDissolver = EntIndexToEntRef(dissolver);
		}

		// dissolve
		Entity_SetName(ent, "dissolving");
		AcceptEntityInput(dissolver, "dissolve");
	} else {
		CreateTimer(0.1, Ink_EntityKill, EntIndexToEntRef(ent));
	}
}

public Action Ink_EntityKill(Handle timer, int ent)
{
	ent = EntRefToEntIndex(ent);
	if (ent != INVALID_ENT_REFERENCE) {
		AcceptEntityInput(ent, "Kill");
	}

	return Plugin_Handled;
}

stock bool Ink_GetEntFrozen(int ent, bool obj = true)
{
	if (obj) {
		int movetype;
		Object[ent].GetValue("movetype", movetype);
		return !movetype;
	}

	return !GetEntityMoveType(ent);
}
stock void Ink_SetEntFrozen(int ent, bool freeze, bool obj = true)
{
	if (freeze) {
		SetEntityMoveType(ent, MOVETYPE_NONE);
		Entity_DisableMotion(ent);

		if (obj) {
			Object[ent].SetValue("movetype", view_as<int>(MOVETYPE_NONE));
		}
	} else {
		SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
		Entity_EnableMotion(ent);

		if (obj) {
			Object[ent].SetValue("movetype", view_as<int>(MOVETYPE_VPHYSICS));
		}
	}
}

stock float Ink_GetEntPlaybackRate(int ent, bool obj = true)
{
	if (obj) {
		float playbackRate = 1.0;
		Object[ent].GetValue("playbackrate", playbackRate);
		return playbackRate;
	}

	return GetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate");
}
stock void Ink_SetEntPlaybackRate(int ent, float rate, bool obj = true)
{
	SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", rate);

	if (obj) {
		if (rate != 1.0) {
			Object[ent].SetValue("playbackrate", rate);
		} else {
			Object[ent].Remove("playbackrate");
		}
	}
}

stock void Ink_GetEntColor(int ent, int color[4], bool obj = true)
{
	if (obj) {
		// retrieve color stored in object
		color = {255, 255, 255, 255};
		Object[ent].GetArray("rendercolor", color, 4);
		return;
	}

	GetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);
}
stock void Ink_SetEntColor(int ent, int color[4], bool obj = true)
{
	int objColor[4];
	Ink_GetEntColor(ent, objColor);

	int entColor[4];
	Ink_GetEntColor(ent, entColor, false);

	// set entity render color if stored value matches
	if (entColor[0] == objColor[0] && entColor[1] == objColor[1] && entColor[2] == objColor[2] && entColor[3] == objColor[3]) {
		if (color[3] == 255) {
			SetEntityRenderMode(ent, RENDER_NORMAL);
		} else {
			SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		}

		Entity_SetRenderColor(ent, color[0], color[1], color[2], color[3]);
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));
	if (StrContains(entClass, "prop_light") == 0) {
		int light = GetEntPropEnt(ent, Prop_Data, "m_hMoveChild");
		Entity_SetRenderColor(light, color[0], color[1], color[2], color[3]);
	}

	if (obj) {
		Object[ent].SetArray("rendercolor", color, 4);
	}
}

stock int Ink_GetEntSkin(int ent, bool obj = true)
{
	if (obj) {
		int skin;
		Object[ent].GetValue("skin", skin);
		return skin;
	}

	return GetEntProp(ent, Prop_Send, "m_nSkin");
}
stock void Ink_SetEntSkin(int ent, int skin, bool obj = true)
{
	SetEntProp(ent, Prop_Send, "m_nSkin", skin);

	if (obj) {
		if (skin > 0) {
			Object[ent].SetValue("skin", skin);
		} else {
			Object[ent].Remove("skin");
		}
	}
}

stock int Ink_GetEntSequence(int ent, bool obj = true)
{
	if (obj) {
		int sequence;
		Object[ent].GetValue("sequence", sequence);
		return sequence;
	}

	return GetEntProp(ent, Prop_Send, "m_nSequence");
}
stock void Ink_SetEntSequence(int ent, int sequence, bool obj = true)
{
	SetEntProp(ent, Prop_Send, "m_nSequence", sequence);

	if (obj) {
		if (sequence > 0) {
			Object[ent].SetValue("sequence", sequence);
		} else {
			Object[ent].Remove("sequence");
		}
	}
}

stock int Ink_GetEntParent(int ent, bool obj = true)
{
	if (obj) {
		int parent = INVALID_ENT_REFERENCE;
		Object[ent].GetValue("parent", parent);
		return EntRefToEntIndex(parent);
	}

	return Entity_GetParent(ent);
}
stock void Ink_SetEntParent(int ent, int parent, bool obj = true)
{
	Entity_SetParent(ent, parent);

	if (obj) {
		Object[ent].SetValue("parent", EntIndexToEntRef(parent));
	}
}
stock void Ink_ClearEntParent(int ent, bool obj = true)
{
	Entity_ClearParent(ent);

	if (obj) {
		Object[ent].Remove("parent");
	}
}

stock void Ink_SetEntScale(int ent, float scale, bool obj = true)
{
	// get current model scale
	float entScale = GetEntPropFloat(ent, Prop_Data, "m_flModelScale");

	if(scale == entScale) {
		return;
	}

	float entMins[3], entMaxs[3];
	GetEntPropVector(ent, Prop_Send, "m_vecMins", entMins);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", entMaxs);

	// figure out original model bounds
	ScaleVector(entMins, 1/entScale);
	ScaleVector(entMaxs, 1/entScale);

	// calculate new bounds based on original
	ScaleVector(entMins, scale);
	ScaleVector(entMaxs, scale);

	// apply new scale
	if (scale == 1.0) {
		SetEntPropFloat(ent, Prop_Data, "m_flModelScale", 0.9999999);
	} else {
		SetEntPropFloat(ent, Prop_Data, "m_flModelScale", scale);
	}

	ActivateEntity(ent);
	Entity_SetMinMaxSize(ent, entMins, entMaxs);
	
	// immediately update target box
	float entOrigin[3];
	Entity_GetAbsOrigin(ent, entOrigin);
	Entity_SetAbsOrigin(ent, entOrigin);

	if (obj) {
		if (scale != 1.0) {
			Object[ent].SetValue("modelscale", scale);
		} else {
			Object[ent].Remove("modelscale");
		}
	}
}

stock void Ink_SetEntLocked(int ent, bool lock, bool obj = true)
{
	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));

	if (StrContains(entClass, "prop_door") == 0) {
		if (lock) {
			AcceptEntityInput(ent, "Lock");
		} else {
			AcceptEntityInput(ent, "Unlock");
		}
	} else if (StrContains(entClass, "prop_light") == 0 || StrContains(entClass, "prop_doll") == 0 || StrContains(entClass, "prop_internet") == 0) {
		if (lock) {
			Entity_RemoveSpawnFlags(ent, 256);
		} else {
			Entity_AddSpawnFlags(ent, 256);
		}
	}

	if (obj) {
		if (lock) {
			Object[ent].SetValue("locked", 1);
		} else {
			Object[ent].Remove("locked");
		}
	}
}
stock bool Ink_GetEntLocked(int ent, bool obj = true)
{
	if (obj) {
		int locked;
		Object[ent].GetValue("locked", locked);
		return view_as<bool>(locked);
	}

	char entClass[64];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));

	if (StrContains(entClass, "prop_door") == 0) {
		return view_as<bool>(GetEntProp(ent, Prop_Data, "m_bLocked"));
	} else if (StrContains(entClass, "prop_light") == 0 || StrContains(entClass, "prop_doll") == 0) {
		return Entity_HasSpawnFlags(ent, 256);
	}

	return false;
}

stock int Ink_GetEntOwner(int ent, int &ownerId = 0)
{
	if (!Object[ent].GetValue("owner", ownerId)) {
		return -1;
	}
	for (int client = 1; client <= MaxClients; client++) {
		if (ownerId == ClientId[client]) {
			// found client
			return client;
		}
	}

	return 0;
}
stock int Ink_SetEntOwner(int ent, int client)
{
	int ownerId;
	int owner = Ink_GetEntOwner(ent, ownerId);

	// if owner is the same as recipient, do nothing
	if (owner == client) {
		return client;
	}

	// store original owner, if changing owners
	if (owner != -1 && !Object[ent].GetValue("creator", owner)) {
		Object[ent].SetValue("creator", ownerId);
	}

	// set new owner
	Object[ent].SetValue("owner", ClientId[client]);

	return client;
}
stock bool Ink_CheckEntOwner(int ent, int client, int override_flags = 0)
{
	if (Object[ent] == null) {
		return false;
	}

	if (override_flags != 0 && CheckCommandAccess(client, "", override_flags, true)) {
		return true;
	}

	int ownerId;
	if (!Object[ent].GetValue("owner", ownerId)) {
		return false;
	}

	return ownerId == ClientId[client];
}