/*
 *
 *	InkMod Build - Entity Spawn: Vehicle
 *
**/
#define _ink_build_spawn_vehicle_


#define EF_BONEMERGE		1
#define EF_NODRAW			32
#define EF_PARENT_ANIMATES	512

#define VEHICLE_TYPE_NONE				0
#define VEHICLE_TYPE_CAR_WHEELS			1
#define VEHICLE_TYPE_CAR_RAYCAST		2
#define VEHICLE_TYPE_JETSKI_RAYCAST		4
#define VEHICLE_TYPE_AIRBOAT_RAYCAST	8


stock int Ink_CreateVehicle(const char[] modelPath, const char[] scriptPath, int vehicleType)
{
	int ent;
	// create entity
	switch (vehicleType) {
		case VEHICLE_TYPE_NONE: {
			ent = CreateEntityByName("prop_vehicle_prisoner_pod");
		}
		case VEHICLE_TYPE_AIRBOAT_RAYCAST: {
			ent = CreateEntityByName("prop_vehicle_airboat");
		}
		default: {
			ent = CreateEntityByName("prop_vehicle_driveable");
		}
	}

	if (ent == INVALID_ENT_REFERENCE) {
		return INVALID_ENT_REFERENCE;
	}

	// apply model
	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	// apply vehicle script
	DispatchKeyValue(ent, "vehiclescript", scriptPath);

	if (vehicleType != VEHICLE_TYPE_NONE) {
		SetEntProp(ent, Prop_Data, "m_nVehicleType", vehicleType);
	}

	// always think
	DispatchKeyValue(ent, "spawnflags", "1");

	// hooks
	//SDKHook(ent, SDKHook_Think, Vehicle_OnThink);
	HookSingleEntityOutput(ent, "PlayerOn", Vehicle_OnEnter);
	HookSingleEntityOutput(ent, "PlayerOff", Vehicle_OnExit);

	// spawn
	DispatchSpawn(ent);
	ActivateEntity(ent);

	// stop rolling away
	AcceptEntityInput(ent, "TurnOff");
	AcceptEntityInput(ent, "TurnOn");

	if (vehicleType != VEHICLE_TYPE_NONE) {
		SetEntPropFloat(ent, Prop_Data, "m_flMinimumSpeedToEnterExit", 30.0);
	}

	// create object data
	GetInkObject(ent, true);

	return ent;
}

// spawn command
public Action Command_SpawnVehicle(int client, int args)
{
	if (args < 1) {
		Ink_ClientMsg(client, "Usage: {green}!vehicle{default} <vehicle name>");
		return Plugin_Handled;
	}

	if (!Ink_LimitClientSpeed(client)) {
		return Plugin_Handled;
	}

	char alias[64];
	GetCmdArg(1, alias, sizeof(alias));
	String_ToLower(alias, alias, sizeof(alias));

	// get prop data
	char model[PLATFORM_MAX_PATH], script[PLATFORM_MAX_PATH];
	int type;
	bool enabled;

	Ink_VehicleFromAlias(alias, model, sizeof(model), script, sizeof(script), type, enabled);

	// perform checks
	if (type == -1) {
		Ink_ClientMsg(client, "Vehicle not found: {green}%s{default}.", alias);
		return Plugin_Handled;
	}
	if (!enabled && !CheckCommandAccess(client, "ink_root", ADMFLAG_ROOT)) {
		Ink_ClientMsg(client, "This vehicle has been discontinued: {green}%s{default}.", alias);
		return Plugin_Handled;
	}

	// check entity limits
	if (!Ink_CheckClientLimit(client, "prop_vehicle")) {
		return Plugin_Handled;
	}

	// create entity
	int ent = Ink_CreateVehicle(model, script, type);

	if (ent == INVALID_ENT_REFERENCE) {
		Ink_ClientMsg(client, "Error spawning vehicle: {green}%s{default}.", alias);
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

public void Vehicle_OnEnter(const char[] output, int ent, int client, float delay)
{
	// disable client-side prediction for less stuttering
	if (!IsFakeClient(client)) {
		SendConVarValue(client, FindConVar("sv_client_predict"), "0");
	}

	// enable bonemerge & unhide
	int clientEffects = GetEntProp(client, Prop_Send, "m_fEffects");
	clientEffects |= EF_BONEMERGE;
	clientEffects &= ~EF_NODRAW;
	SetEntProp(client, Prop_Send, "m_fEffects", clientEffects);

	// make playermodel visible to self
	//SetEntProp(client, Prop_Send, "m_iObserverMode", 1);

	// hide weapon
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", false);

	// make the player look forward
	TeleportEntity(client, NULL_VECTOR, view_as<float>({0.0, 90.0, 0.0}), NULL_VECTOR);
}

public void Vehicle_OnExit(const char[] output, int ent, int client, float delay)
{
	// re-enable prediction
	if (!IsFakeClient(client)) {
		SendConVarValue(client, FindConVar("sv_client_predict"), "-1");
	}

	// unhide weapon
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", true);

	// set view to normal
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
}