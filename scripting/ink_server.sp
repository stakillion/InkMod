/*
 *
 *	InkMod Server
 *	Server modifications for InkMod
 *
**/
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <smlib>

#pragma semicolon 1
#pragma newdecls required


public Plugin myinfo =
{
	name        = "InkMod Server Config",
	author      = "Inks",
	description = "Various server modifications to accomodate InkMod.",
	version     = "0.1.0",
	url         = ""
};


ConVar ink_allow_noclip;
ConVar ink_strip_weapons;
ConVar ink_disable_cleanup;
ConVar ink_tf_alt_use;

Handle SDKCall_FindUseEntity;
DynamicHook DHook_CleanUpMap;
DynamicHook DHook_AcceptInput;

bool ClientInUse[MAXPLAYERS + 1];


/*********************************
          Initialization          
*********************************/

// on plugin load
public void OnPluginStart()
{
	// noclip command
	RegAdminCmd("noclip", Command_Noclip, 0, "Gives you noclip.");
	RegAdminCmd("n_fly", Command_Noclip, 0, "Gives you noclip.");

	ConCommand_RemoveFlags("noclip", FCVAR_CHEAT);
	ConCommand_RemoveFlags("sv_infinite_aux_power", FCVAR_CHEAT);

	// create convars
	ink_allow_noclip	= CreateConVar("ink_allow_noclip",		"0", "Enables/disables noclip for players");
	ink_strip_weapons	= CreateConVar("ink_strip_weapons",		"0", "Enables/disables weapon stripping on player spawn");
	ink_disable_cleanup	= CreateConVar("ink_disable_cleanup",	"0", "Prevents map reset on round start");
	ink_tf_alt_use		= CreateConVar("ink_tf_alt_use",		"1", "Enables use of the MEDIC! voice command to activate +use");

	// hook events
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Pre);
	AddCommandListener(Command_VoiceMenu, "voicemenu");

	GameData gamedata = new GameData("inkmod.games");

	// CBasePlayer::FindUseEntity
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBasePlayer::FindUseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((SDKCall_FindUseEntity = EndPrepSDKCall()) == null) {
		SetFailState("Failed to create SDKCall: CBasePlayer::FindUseEntity");
	}

	// CleanUpMap
	if ((DHook_CleanUpMap = DynamicHook.FromConf(gamedata, "CleanUpMap")) == null) {
		SetFailState("Failed to create DHook: CleanUpMap");
	}

	// CBaseEntity::AcceptInput
	if ((DHook_AcceptInput = DynamicHook.FromConf(gamedata, "CBaseEntity::AcceptInput")) == null) {
		SetFailState("Failed to create DHook: CBaseEntity::AcceptInput");
	}

	delete gamedata;
}

public void OnMapStart()
{
	if (GetEngineVersion() == Engine_TF2) {

		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "info_player_start")) != -1) {
			DispatchKeyValue(ent, "classname", "info_player_teamspawn");
		}

		ent = FindEntityByClassname(-1, "tf_gamerules");
		if (ent != -1) {
			// set m_bAllowStalemateAtTimelimit to true
			SetVariantBool(true);
			AcceptEntityInput(ent, "SetStalemateOnTimelimit");
			// prevent it from being changed again
			DHook_AcceptInput.HookEntity(Hook_Pre, ent, OnGamerulesAcceptInput);
		}
	}

	DHook_CleanUpMap.HookGamerules(Hook_Pre, OnCleanUpMap);
}

public MRESReturn OnGamerulesAcceptInput(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	char inputName[64];
	hParams.GetString(1, inputName, sizeof(inputName));
	if (StrEqual(inputName, "SetStalemateOnTimelimit", false)) {
		hReturn.Value = true;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn OnCleanUpMap()
{
	if (ink_disable_cleanup.BoolValue) {
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public Action Command_Noclip(int client, int args)
{
	if (!ink_allow_noclip.BoolValue && !Client_HasAdminFlags(client, ADMFLAG_ROOT)) {
		return Plugin_Handled;
	}

	if (Entity_GetParent(client) != INVALID_ENT_REFERENCE) {
		return Plugin_Handled;
	}

	if (GetEntityMoveType(client) != MOVETYPE_NOCLIP) {
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
	}
	else {
		SetEntityMoveType(client, MOVETYPE_WALK);
	}

	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	ClientInUse[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (Client_HasAdminFlags(client, ADMFLAG_ROOT)) {
		SendConVarValue(client, FindConVar("sv_cheats"), "1");
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] chatMessage)
{
	if (client == 0) {
		return Plugin_Continue;
	}

	char chatCmdPrefix[2];
	chatCmdPrefix[0] = chatMessage[0];
	if (chatCmdPrefix[0] != '!' && chatCmdPrefix[0] != '/') {
		return Plugin_Continue;
	}

	char chatCmdArg[2][128];
	ExplodeString(chatMessage, " ", chatCmdArg, 2, sizeof(chatCmdArg[]), true);

	String_ToLower(chatCmdArg[0], chatCmdArg[0], sizeof(chatCmdArg[]));
	ReplaceString(chatCmdArg[0], sizeof(chatCmdArg[]), chatCmdPrefix, "n_");

	if (GetCommandFlags(chatCmdArg[0]) == INVALID_FCVAR_FLAGS) {
		return Plugin_Continue;
	}

	FakeClientCommandEx(client, "%s %s", chatCmdArg[0], chatCmdArg[1]);

	if (chatCmdPrefix[0] == '/') {
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}

public Action Command_VoiceMenu(int client, const char[] command, int args)
{
	if (ink_tf_alt_use.BoolValue) {
		char cmdArg[2][2];
		GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
		GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));

		if (cmdArg[0][0] == '0' && cmdArg[1][0] == '0') {
			ClientInUse[client] = true;
			if (SDKCall(SDKCall_FindUseEntity, client) != -1) {
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnClientCommandKeyValues(int client, KeyValues kv)
{
	if (ink_tf_alt_use.BoolValue) {
		char cmd[32];
		kv.GetSectionName(cmd,sizeof(cmd));

		if (StrEqual(cmd, "+use_action_slot_item_server", false)) {
			ClientInUse[client] = true;
			if (SDKCall(SDKCall_FindUseEntity, client) != -1) {
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (ClientInUse[client]) {
		ClientInUse[client] = false;

		buttons |= IN_USE;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	if (ink_strip_weapons.BoolValue) {
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		RequestFrame(RemoveClientWeapons, client);
	}

	return Plugin_Continue;
}

public void RemoveClientWeapons(int client)
{
	Client_ChangeWeapon(client, "weapon_physcannon");
	Client_RemoveAllWeapons(client, "weapon_physcannon", true);
}

public void OnEntityCreated(int ent, const char[] classname)
{
	if (StrEqual(classname, "weapon_physgun")) {
		SetEntProp(ent, Prop_Send, "m_nSkin", 1);
	}
}