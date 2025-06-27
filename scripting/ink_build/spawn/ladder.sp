/*
 *
 *	InkMod Build - Entity Spawn: Ladder
 *
**/
#define _ink_build_spawn_ladder_


stock int Ink_CreateLadder(const char[] modelPath)
{
	// create entity
	int ent = CreateEntityByName("prop_physics_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for prop_ladder
	DispatchKeyValue(ent, "classname", "prop_ladder");

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// create ladder entity
	int ladder = CreateEntityByName("func_useableladder");
	DispatchKeyValue(ladder, "point0", "30 0 0");
	DispatchKeyValue(ladder, "point1", "30 0 128");
	DispatchKeyValue(ladder, "StartDisabled", "0");
	DispatchSpawn(ladder);
	ActivateEntity(ladder);

	Entity_SetParent(ladder, ent);
	TeleportEntity(ladder, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnLadder(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "prop_ladder")) {
		return Plugin_Handled;
	}

	// create entity
	int ent = INVALID_ENT_REFERENCE;
	switch (GetCmdArgInt(1)) {
		case 0: {
			ent = Ink_CreateLadder("models/props_c17/metalladder001.mdl");
		}
		case 1: {
			ent = Ink_CreateLadder("models/props_c17/metalladder002.mdl");
		}
	}

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning ladder cel.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "ladder%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	return Plugin_Handled;
}
