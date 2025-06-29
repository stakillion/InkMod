/*
 *
 *	InkMod Build - Entity Spawn: Prop
 *
**/
#define _ink_build_spawn_prop_


stock int Ink_CreatePhysicsProp(const char[] modelPath)
{
	// create entity
	int ent = CreateEntityByName("prop_physics_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// set collision
	Entity_SetSolidType(ent, SOLID_VPHYSICS);
	Entity_SetCollisionGroup(ent, COLLISION_GROUP_NONE);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// freeze
	SetEntityMoveType(ent, MOVETYPE_NONE);
	Entity_DisableMotion(ent);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

stock int Ink_CreateDynamicProp(const char[] modelPath, const char[] defaultAnim, int solid = SOLID_VPHYSICS)
{
	// create entity
	int ent = CreateEntityByName("prop_dynamic_override");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// set default animation (required for collision)
	DispatchKeyValue(ent, "DefaultAnim", defaultAnim);

	// set collision
	Entity_SetSolidType(ent, solid);
	Entity_SetCollisionGroup(ent, COLLISION_GROUP_NONE);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

stock int Ink_CreateDollProp(const char[] modelPath)
{
	// create entity
	int ent = CreateEntityByName("cycler");

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	DispatchKeyValue(ent, "classname", "prop_doll");

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// avoid server crash w/ cycler
	DispatchKeyValue(ent, "DefaultAnim", "ragdoll");

	// make prop_dynamic_override animate
	//SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", 1.0);
	//SetEntProp(ent, Prop_Send, "m_bClientSideAnimation", 0);
	//SetEntProp(ent, Prop_Data, "m_bSequenceLoops", 1);

	// set collision
	Entity_SetSolidType(ent, SOLID_BBOX);
	Entity_SetCollisionGroup(ent, COLLISION_GROUP_NONE);

	// hook damage
	SDKHook(ent, SDKHook_OnTakeDamage, OnDollTakeDamage);
	Entity_AddSpawnFlags(ent, 256);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// create object data
	GetInkObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnProp(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!prop{default} <model name>");
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	char alias[64];
	GetCmdArg(1, alias, sizeof(alias));
	String_ToLower(alias, alias, sizeof(alias));

	// get prop data
	char model[PLATFORM_MAX_PATH], animation[32];
	bool enabled;
	int type, solid = 6;

	if ((type = Ink_ModelFromAlias(alias, model, sizeof(model), animation, sizeof(animation), solid, enabled)) == -1) {
		Ink_ClientMsg(client, "Prop not found: {green}%s{default}.", alias);
		return Plugin_Handled;
	}
	if (!enabled && !CheckCommandAccess(client, "ink_root", ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This prop has been discontinued: {green}%s{default}.", alias);
		return Plugin_Handled;
	}

	// create entity
	int ent = INVALID_ENT_REFERENCE;
	if (type == 1) {
		if (!Ink_CheckClientLimit(client, "prop_physics")) {
			return Plugin_Handled;
		}

		ent = Ink_CreatePhysicsProp(model);
	} else if (type == 2) {
		if (!Ink_CheckClientLimit(client, "prop_doll")) {
			return Plugin_Handled;
		}

		ent = Ink_CreateDollProp(model);
	} else if (type == 3) {
		if (!Ink_CheckClientLimit(client, "prop_dynamic")) {
			return Plugin_Handled;
		}

		ent = Ink_CreateDynamicProp(model, animation, solid);
	}

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning prop: {green}%s{default}.", alias);
		return Plugin_Handled;
	}

	Entity_SetName(ent, "%s%i", alias, EntIndexToEntRef(ent));

	// move to player
	float entPos[3], entAng[3];
	Ink_CalcEntSpawnPos(ent, client, entPos, entAng);
	TeleportEntity(ent, entPos, entAng, NULL_VECTOR);
	Ink_SpawnEffect(entPos);

	// give to player
	Ink_SetEntOwner(ent, client);

	return Plugin_Handled;
}

public Action OnDollTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!Ink_CheckEntOwner(victim, attacker)) {
		return Plugin_Handled;
	}

	if (!Entity_HasSpawnFlags(victim, 256)) {
		return Plugin_Handled;
	}

	int sequence = Ink_GetEntSequence(victim);
	Ink_SetEntSequence(victim, sequence + 1);

	return Plugin_Handled;
}