/*
 *
 *	Vehicle Fixes
 *
**/
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required


Handle SDKCall_SetupMove;
Handle SDKCall_StudioFrameAdvance;
Handle SDKCall_GetInVehicle;
Handle SDKCall_HandleEntryExitFinish;

DynamicHook DHook_HandlePassengerEntry;
DynamicHook DHook_GetExitAnimToUse;


/***********************
          Init          
***********************/

public void OnAllPluginsLoaded()
{
	GameData gamedata = new GameData("vehiclefix");

	if (GetEngineVersion() == Engine_TF2) {
		// CPlayerMove::SetupMove
		DynamicDetour detour = DynamicDetour.FromConf(gamedata, "CPlayerMove::SetupMove");
		detour.Enable(Hook_Pre, OnPlayerSetupMove);

		// CBaseServerVehicle::SetupMove
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseServerVehicle::SetupMove");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		if ((SDKCall_SetupMove = EndPrepSDKCall()) == null) {
			SetFailState("Failed to create SDKCall: CBaseServerVehicle::SetupMove");
		}
	}

	// CBaseAnimating::StudioFrameAdvance
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((SDKCall_StudioFrameAdvance = EndPrepSDKCall()) == null) {
		SetFailState("Failed to create SDKCall: CBaseAnimating::StudioFrameAdvance");
	}

	// CBasePlayer::GetInVehicle
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBasePlayer::GetInVehicle");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	if ((SDKCall_GetInVehicle = EndPrepSDKCall()) == null) {
		SetFailState("Failed to create SDKCall: CBasePlayer::GetInVehicle");
	}

	// CBaseServerVehicle::HandleEntryExitFinish
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseServerVehicle::HandleEntryExitFinish");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((SDKCall_HandleEntryExitFinish = EndPrepSDKCall()) == null) {
		SetFailState("Failed to create SDKCall: CBaseServerVehicle::HandleEntryExitFinish");
	}

	// CBaseServerVehicle::HandlePassengerEntry
	if ((DHook_HandlePassengerEntry = DynamicHook.FromConf(gamedata, "CBaseServerVehicle::HandlePassengerEntry")) == null) {
		SetFailState("Failed to create DHook: CBaseServerVehicle::HandlePassengerEntry");
	}

	// CBaseServerVehicle::GetExitAnimToUse
	if ((DHook_GetExitAnimToUse = DynamicHook.FromConf(gamedata, "CBaseServerVehicle::GetExitAnimToUse")) == null) {
		SetFailState("Failed to create DHook: CBaseServerVehicle::GetExitAnimToUse");
	}

	delete gamedata;
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (StrContains(classname, "prop_vehicle", false) != -1) {
		SDKHook(ent, SDKHook_SpawnPost, OnVehicleSpawnPost);
		SDKHook(ent, SDKHook_Use, OnVehicleUse);

		// hook think for prop_vehicle_driveable
		if (StrContains(classname, "_driveable", false) != -1) {
			SDKHook(ent, SDKHook_Think, OnVehicleThink);
		}
	}
}

public void OnEntityDestroyed(int ent)
{
	if (ent == -1) {
		return;
	}

	char class[32];
	GetEntityNetClass(ent, class, sizeof(class));
	if (StrContains(class, "CPropVehicle", false) != -1) {
		// force player out
		SDKCall(SDKCall_HandleEntryExitFinish, GetServerVehicle(ent), true, true);
	}
}

public void OnVehicleSpawnPost(int ent)
{
	Address serverVehicle = GetServerVehicle(ent);
	DHook_HandlePassengerEntry.HookRaw(Hook_Pre, serverVehicle, HandlePassengerEntryPre);
	DHook_GetExitAnimToUse.HookRaw(Hook_Post, serverVehicle, GetExitAnimToUsePost);
}


/************************
          Hooks          
************************/

public void OnVehicleThink(int ent)
{
	// make prop_vehicle_driveable animate
	SDKCall(SDKCall_StudioFrameAdvance, ent);
}

public Action OnVehicleUse(int ent, int activator, int caller, UseType type, float value)
{
	int client = GetEntPropEnt(ent, Prop_Data, "m_hPlayer");
	// block use by passenger, or they won't be able to exit
	if (client == activator) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public MRESReturn HandlePassengerEntryPre(Address serverVehicle, DHookParam params)
{
	// skip enter animation
	int client = params.Get(1);
	if (SDKCall(SDKCall_GetInVehicle, client, serverVehicle, 0)) {
		SetEntityMoveType(client, MOVETYPE_NONE);
	}

	return MRES_Supercede;
}

public MRESReturn GetExitAnimToUsePost(Address serverVehicle, DHookReturn ret)
{
	// skip exit animation
	ret.Value = -1;
	return MRES_Override;
}

public MRESReturn OnPlayerSetupMove(DHookParam params)
{
	int client = params.Get(1);

	int ent = GetEntPropEnt(client, Prop_Data, "m_hVehicle");
	if (ent != -1) {
		Address ucmd = params.Get(2);
		Address helper = params.Get(3);
		Address move = params.Get(4);

		// send move to vehicle if we're driving
		SDKCall(SDKCall_SetupMove, GetServerVehicle(ent), client, ucmd, helper, move);
	}
		
	return MRES_Ignored;
}


/************************
          Funcs          
************************/

Address GetServerVehicle(int vehicle)
{
	static int offset = -1;
	if (offset == -1) {
		FindDataMapInfo(vehicle, "m_pServerVehicle", _, _, offset);
	}

	if (offset == -1) {
		LogError("Unable to find offset 'm_pServerVehicle'");
		return Address_Null;
	}

	return view_as<Address>(GetEntData(vehicle, offset));
}
