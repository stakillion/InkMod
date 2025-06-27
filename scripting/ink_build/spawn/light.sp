/*
 *
 *	InkMod Build - Entity Spawn: Ladder
 *
**/
#define _ink_build_spawn_light_


stock int Ink_CreateLight(const char[] modelPath, int distance = 500)
{
	// create entity
	int ent = CreateEntityByName("prop_physics_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for prop_light
	DispatchKeyValue(ent, "classname", "prop_light");
	DispatchKeyValue(ent, "rendermode", "1");
	AcceptEntityInput(ent, "disableshadow");

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// create light entity
	int light = CreateEntityByName("light_dynamic");
	DispatchKeyValue(light, "inner_cone", "300");
	DispatchKeyValue(light, "cone", "500");
	DispatchKeyValue(light, "spotlight_radius", "500");
	DispatchKeyValue(light, "brightness", "0.5");
	DispatchKeyValueInt(light, "distance", distance);
	DispatchSpawn(light);
	ActivateEntity(light);

	Entity_SetParent(light, ent);
	TeleportEntity(light, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);

	// hook use
	SDKHook(ent, SDKHook_Use, OnLightUse)
	Entity_AddSpawnFlags(ent, 256);

	// create object data
	GetInkObject(ent, true);
	Ink_SetEntColor(ent, {255, 255, 255, 64});

	return ent;
}

// spawn command
public Action Command_SpawnLight(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "prop_light")) {
		return Plugin_Handled;
	}

	int distance = 500;
	if (args > 1) {
		distance = Math_Clamp(GetCmdArgInt(1), 0, 1000);
	}

	// create entity
	int ent = Ink_CreateLight("models/roller_spikes.mdl", distance);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning light prop.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "light%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	return Plugin_Handled;
}

public Action OnLightUse(int entity, int activator, int caller, UseType type, float value)
{
	int light = GetEntPropEnt(entity, Prop_Data, "m_hMoveChild");
	AcceptEntityInput(light, "toggle");
}