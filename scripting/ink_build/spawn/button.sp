/*
 *
 *	InkMod Build - Entity Spawn: Button
 *
**/
#define _ink_build_spawn_button_


stock int Ink_CreateButton(const char[] modelPath)
{
	// create entity
	int ent = CreateEntityByName("prop_physics_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for entity_button
	DispatchKeyValue(ent, "classname", "entity_button");

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// hook use
	SDKHook(ent, SDKHook_Use, OnButtonUse)
	Entity_AddSpawnFlags(ent, 256);

	// create object data
	Ink_CreateObject(ent);

	return ent;
}

// spawn command
public Action Command_SpawnButton(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "entity_button")) {
		return Plugin_Handled;
	}

	// create entity
	int ent = Ink_CreateButton("models/props_combine/combinebutton.mdl");

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning button entity.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "button%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	Ink_ClientMsg(client, "Created button entity. To use, you must {green}!link{default} it to another entity.")
	return Plugin_Handled;
}

public Action OnButtonUse(int entity, int activator, int caller, UseType type, float value)
{
	float time = GetGameTime();
	if (UseTime[entity] > time - 0.5) {
		return Plugin_Handled;
	}
	UseTime[entity] = time;

	int ents[6];
	if (Object[entity].GetArray("links", ents, 6)) {
		for (int i; i < 6; i++) {
			if (ents[i] == 0) {
				continue;
			}

			if (!IsValidEntity(ents[i])) {
				continue;
			}

			Ink_ActivateEnt(ents[i], activator);
		}
	} else {
		Ink_ClientMsg(activator, "This button has no connections. Use the {green}!link{default} command to connect it to another entity.");
	}

	return Plugin_Handled;
}