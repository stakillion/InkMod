/*
 *
 *	InkMod Build - Entity Spawn: Gate
 *
**/
#define _ink_build_spawn_gate_


stock int Ink_CreateGate(const char[] modelPath, const char[] defaultAnim = "idle_closed")
{
	// create entity
	int ent = CreateEntityByName("prop_dynamic_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply entity properties for prop_gate
	DispatchKeyValue(ent, "classname", "prop_gate");

	// set collision
	DispatchKeyValue(ent, "DefaultAnim", defaultAnim);
	Entity_SetSolidType(ent, SOLID_VPHYSICS);
	Entity_SetCollisionGroup(ent, COLLISION_GROUP_NONE);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// create object data
	Ink_GetObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnGate(int client, int args)
{
	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	if (!Ink_CheckClientLimit(client, "prop_gate")) {
		return Plugin_Handled;
	}

	int type = 1;
	if (args > 0) {
		type = GetCmdArgInt(1);
	}

	// create entity
	int ent = INVALID_ENT_REFERENCE;
	if (type == 2) {
		ent = Ink_CreateGate("models/combine_gate_citizen.mdl");
	} else if (type == 3) {
		ent = Ink_CreateGate("models/combine_gate_vehicle.mdl");
	} else {
		ent = Ink_CreateGate("models/props_combine/combine_door01.mdl");
	}

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning gate prop.");
		return Plugin_Handled;
	}

	Entity_SetName(ent, "gate%i", EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	Ink_ClientMsg(client, "Created gate prop. To use, you must {green}!link{default} it to a {green}!button{default} entity.")
	return Plugin_Handled;
}

public Action OnGateUse(int entity, int activator, int caller, UseType type, float value)
{
	float time = GetGameTime();
	if (UseTime[entity] > time - 2.5) {
		return Plugin_Handled;
	}
	UseTime[entity] = time;

	char state[32];
	GetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", state, sizeof(state));

	if (StrEqual(state, "idle_closed")) {
		SetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", "idle_open")
		SetVariantString("Open");
		AcceptEntityInput(entity, "SetAnimation");
	} else {
		SetEntPropString(entity, Prop_Data, "m_iszDefaultAnim", "idle_closed")
		SetVariantString("Close");
		AcceptEntityInput(entity, "SetAnimation");
	}

	return Plugin_Handled;
}