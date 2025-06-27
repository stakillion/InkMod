/*
 *
 *	InkMod Build - Entity Spawn: Door
 *
**/
#define _ink_build_spawn_door_


stock int Ink_CreateDoor(const char[] modelPath, int hardware = 1)
{
	// create entity
	int ent = CreateEntityByName("prop_door_rotating");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for prop_door
	DispatchKeyValue(ent, "spawnflags", "8192");
	DispatchKeyValue(ent, "distance", "90");
	DispatchKeyValue(ent, "speed", "100");
	DispatchKeyValue(ent, "dmg", "20");
	DispatchKeyValue(ent, "opendir", "0");
	DispatchKeyValue(ent, "returndelay", "-1");
	DispatchKeyValue(ent, "forceclosed", "1");
	DispatchKeyValue(ent, "OnFullyOpen", "!caller,close,,3,-1");

	DispatchKeyValueInt(ent, "hardware", hardware);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnDoor(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "prop_door")) {
		return Plugin_Handled;
	}

	int hardware = 1;
	if (args > 0) {
		hardware = GetCmdArgInt(1);
	}

	// create entity
	int ent = Ink_CreateDoor("models/props_c17/door01_left.mdl", hardware);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning door prop.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "door%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	DispatchSpawn(ent);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	return Plugin_Handled;
}
