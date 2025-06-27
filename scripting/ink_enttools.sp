/*
 *
 *	InkMod Entity Tools
 *	Commands to modify properties on an entity
 *
**/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#pragma semicolon 1
#pragma newdecls required

#include "include/ink_stocks"
#include "include/ink_objects"

#define MAX_EDICTS  2048
#define ZERO_VECTOR view_as<float>({0.0, 0.0, 0.0})


public Plugin myinfo =
{
	name        = "InkMod Entity Tools",
	author      = "Inks",
	description = "Commands to modify properties on an entity.",
	version     = "0.1.0",
	url         = ""
};


/*********************************
          Initialization          
*********************************/

public void OnPluginStart()
{
	RegAdminCmd("n_entindex", Command_EntIndex, ADMFLAG_RCON);
	RegAdminCmd("n_createentity", Command_CreateEntity, ADMFLAG_RCON);
	RegAdminCmd("n_dispatchkeyvalue", Command_DispatchKeyValue, ADMFLAG_RCON);
	RegAdminCmd("n_dispatchspawn", Command_DispatchSpawn, ADMFLAG_RCON);
	RegAdminCmd("n_activateentity", Command_ActivateEntity, ADMFLAG_RCON);
	RegAdminCmd("n_acceptinput", Command_AcceptInput, ADMFLAG_RCON);
	RegAdminCmd("n_getentdata", Command_GetEntData, ADMFLAG_RCON);
	RegAdminCmd("n_setentdata", Command_SetEntData, ADMFLAG_RCON);
	RegAdminCmd("n_getviewmodel", Command_GetViewModel, ADMFLAG_RCON);
	RegAdminCmd("n_setentitymodel", Command_SetEntityModel, ADMFLAG_RCON);
	RegAdminCmd("n_getentpropstring", Command_GetEntPropString, ADMFLAG_RCON);
	RegAdminCmd("n_setentpropstring", Command_SetEntPropString, ADMFLAG_RCON);
	RegAdminCmd("n_getentnetclass", Command_GetEntNetClass, ADMFLAG_RCON);
	RegAdminCmd("n_createfakeclient", Command_CreateFakeClient, ADMFLAG_RCON);

	RegAdminCmd("n_setentityvalue", Command_SetEntityValue, ADMFLAG_RCON);
	RegAdminCmd("n_getentityvalue", Command_GetEntityValue, ADMFLAG_RCON);
	RegAdminCmd("n_setentitystring", Command_SetEntityString, ADMFLAG_RCON);
	RegAdminCmd("n_getentitystring", Command_GetEntityString, ADMFLAG_RCON);

	RegAdminCmd("n_vmftest", Command_VmfTest, ADMFLAG_RCON);
}

public Action Command_VmfTest(int client, int args)
{
	char vmfPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, vmfPath, sizeof(vmfPath), "data/inkmod/test.vmf");
	KeyValues entKv = new KeyValues("vmf");
	entKv.ImportFromFile(vmfPath);
	PrintToChat(client, "Printing test.vmf to console...");
	File vmfFile = OpenFile(vmfPath, "w");
	VmfTestRecursive(client, entKv, vmfFile);
	delete vmfFile;

	return Plugin_Handled;
}

void VmfTestRecursive(int client, KeyValues kv, File vmfFile)
{
	int depth = kv.NodesInStack();

	do
	{
		char buffer[128];
		kv.GetSectionName(buffer, sizeof(buffer));

		if (StrEqual(buffer, "entity", false) || StrEqual(buffer, "world", false)) {
			char kvString[1024];
			kv.ExportToString(kvString, sizeof(kvString));
			WriteFileString(vmfFile, kvString, false);
		}

		char space[64];
		for(int tabs = 0; tabs < depth; tabs++) {
			StrCat(space, sizeof(space), "	");
		}

		if (kv.GotoFirstSubKey(false))
		{
			// Current key is a section. Browse it recursively.
			PrintToConsole(client, "%s\"%s\" {", space, buffer);
			VmfTestRecursive(client, kv, vmfFile);
			PrintToConsole(client, "%s}", space);
			kv.GoBack();
		}
		else
		{
			// Current key is a regular key, or an empty section.
			if (kv.GetDataType(NULL_STRING) != KvData_None)
			{
				char value[128];
				kv.GetString(NULL_STRING, value, sizeof(value), "NOTFOUND");
				PrintToConsole(client, "%s\"%s\" \"%s\"", space, buffer, value);
			}
			else
			{
				PrintToConsole(client, "%s\"%s\" {", space, buffer);
				PrintToConsole(client, "%s}", space);
			}
		}
	} while (kv.GotoNextKey(false));
}

public Action Command_EntIndex(int client, int args)
{
	int ent = Ink_GetClientAim(client);

	if (ent == INVALID_ENT_REFERENCE) {
		PrintToChat(client, "You're not looking at anything.");
		return Plugin_Handled;
	}

	PrintToChat(client, "Entity index: %i", ent);

	return Plugin_Handled;
}

public Action Command_CreateEntity(int client, int args)
{
	if (args < 1) {
		PrintToChat(client, "Usage: !createentity <classname>");
		return Plugin_Handled;
	}

	char classname[128];
	GetCmdArg(1, classname, sizeof(classname));
	int ent = CreateEntityByName(classname);

	PrintToChat(client, "Created %s with index %i", classname, ent);

	return Plugin_Handled;
}

public Action Command_DispatchSpawn(int client, int args)
{
	if (args < 1) {
		PrintToChat(client, "Usage: !dispatchspawn <ent index>");
		return Plugin_Handled;
	}

	char cmdArg[16];
	GetCmdArg(1, cmdArg, sizeof(cmdArg));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	DispatchSpawn(ent);

	PrintToChat(client, "Spawned entity %i", ent);

	return Plugin_Handled;
}

public Action Command_ActivateEntity(int client, int args)
{
	if (args < 1) {
		PrintToChat(client, "Usage: !activateentity <ent index>");
		return Plugin_Handled;
	}

	char cmdArg[16];
	GetCmdArg(1, cmdArg, sizeof(cmdArg));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	ActivateEntity(ent);

	PrintToChat(client, "Activated entity %i", ent);

	return Plugin_Handled;
}

public Action Command_DispatchKeyValue(int client, int args)
{
	if (args < 3) {
		PrintToChat(client, "Usage: !dispatchkeyvalue <ent index> <key> <value>");
		return Plugin_Handled;
	}

	char cmdArgString[256];
	GetCmdArgString(cmdArgString, sizeof(cmdArgString));
	char cmdArg[3][256];
	ExplodeString(cmdArgString, " ", cmdArg, 3, 256, true);

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	DispatchKeyValue(ent, cmdArg[1], cmdArg[2]);
	PrintToChat(client, "Set key %s to %s on entity %i", cmdArg[1], cmdArg[2], ent);

	return Plugin_Handled;
}

public Action Command_GetEntityValue(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !getentityvalue <ent index> <key>");
		return Plugin_Handled;
	}

	char cmdArg[2][128];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	StringMap entdata = GetInkObject(ent);
	int value;
	if (entdata != null && entdata.GetValue(cmdArg[1], value)) {
		PrintToChat(client, "Key %s on entity %i is %i", cmdArg[1], ent, value);
	}
	else {
		PrintToChat(client, "Failed to get key %s on entity %i", cmdArg[1], ent);
	}

	return Plugin_Handled;
}

public Action Command_SetEntityValue(int client, int args)
{
	if (args < 3) {
		PrintToChat(client, "Usage: !setentityvalue <ent index> <key> <value>");
		return Plugin_Handled;
	}

	char cmdArg[3][128];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));
	GetCmdArg(3, cmdArg[2], sizeof(cmdArg[]));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	StringMap entdata = GetInkObject(ent, true);
	int value = StringToInt(cmdArg[2]);
	if (entdata != null && entdata.SetValue(cmdArg[1], value)) {
		PrintToChat(client, "Set key %s on entity %i to %i", cmdArg[1], ent, value);
	}
	else {
		PrintToChat(client, "Failed to set key %s on entity %i", cmdArg[1], ent);
	}

	return Plugin_Handled;
}

public Action Command_GetEntityString(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !getentitystring <ent index> <key>");
		return Plugin_Handled;
	}

	char cmdArg[2][128];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	StringMap entdata = GetInkObject(ent);
	char value[128];
	if (entdata != null && entdata.GetString(cmdArg[1], value, sizeof(value))) {
		PrintToChat(client, "Key %s on entity %i is %s", cmdArg[1], ent, value);
	}
	else {
		PrintToChat(client, "Key %s on entity %i is %s", cmdArg[1], ent, value);
	}

	return Plugin_Handled;
}

public Action Command_SetEntityString(int client, int args)
{
	if (args < 3) {
		PrintToChat(client, "Usage: !setentitystring <ent index> <key> <value>");
		return Plugin_Handled;
	}

	char cmdArg[3][128];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));
	GetCmdArg(3, cmdArg[2], sizeof(cmdArg[]));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	StringMap entdata = GetInkObject(ent, true);
	if (entdata != null && entdata.SetString(cmdArg[1], cmdArg[2])) {
		PrintToChat(client, "Set key %s on entity %i to %s", cmdArg[1], ent, cmdArg[2]);
	}
	else {
		PrintToChat(client, "Failed to set key %s on entity %i", cmdArg[1], ent);
	}

	return Plugin_Handled;
}

public Action Command_AcceptInput(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !acceptinput <ent index> <input> <variant>");
		return Plugin_Handled;
	}

	char cmdArg[3][128];
	GetCmdArg(1, cmdArg[0], sizeof(cmdArg[]));
	GetCmdArg(2, cmdArg[1], sizeof(cmdArg[]));
	GetCmdArg(3, cmdArg[2], sizeof(cmdArg[]));

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	SetVariantString(cmdArg[2]);
	AcceptEntityInput(ent, cmdArg[1]);

	PrintToChat(client, "Gave input %s %s on entity %i", cmdArg[1], cmdArg[2], ent);

	return Plugin_Handled;
}

public Action Command_GetEntData(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !getentdata <ent index> <property name> <offset>");
		return Plugin_Handled;
	}

	char cmdArg[3][128];
	for (int x; x < 3; x++) {
		GetCmdArg(x + 1, cmdArg[x], sizeof(cmdArg[]));
	}

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
		return Plugin_Handled;
	}

	PropFieldType type;
	int num_bits;
	int local_offset;
	int offset = StringToInt(cmdArg[2]) + FindDataMapInfo(ent, cmdArg[1], type, num_bits, local_offset);

	if (offset == -1) {
		PrintToChat(client, "no offset found for %s", cmdArg[1]);
		return Plugin_Handled;
	}

	PrintToChat(client, "%s:", cmdArg[1]);
	PrintToChat(client, "offset - %i", offset);
	switch (type) {
		case PropField_Unsupported: {
			PrintToChat(client, "type - PropField_Unsupported");
			int data = GetEntData(ent, offset);
			PrintToChat(client, "value - %i", data);
		}
		case PropField_Integer: {
			PrintToChat(client, "type - PropField_Integer");
			int data = GetEntData(ent, offset);
			PrintToChat(client, "value - %i", data);
		}
		case PropField_Float: {
			PrintToChat(client, "type - PropField_Float");
			float data = GetEntDataFloat(ent, offset);
			PrintToChat(client, "value - %f", data);
		}
		case PropField_Entity: {
			PrintToChat(client, "type - PropField_Entity");
			int data = GetEntDataEnt2(ent, offset);
			PrintToChat(client, "value - %i", data);
		}
		case PropField_Vector: {
			PrintToChat(client, "type - PropField_Vector");
			float data[3];
			GetEntDataVector(ent, offset, data);
			PrintToChat(client, "value - %f %f %f", data[0], data[1], data[2]);
		}
		case PropField_String: {
			PrintToChat(client, "type - PropField_String");
			char data[256];
			GetEntDataString(ent, offset, data, sizeof(data));
			PrintToChat(client, "value - %s", data);
		}
		case PropField_String_T: {
			PrintToChat(client, "type - PropField_String_T");
			char data[256];
			GetEntDataString(ent, offset, data, sizeof(data));
			PrintToChat(client, "value - %s", data);
		}
	}
	PrintToChat(client, "num_bits - %i", num_bits);
	PrintToChat(client, "local_offset - %i", local_offset);

	return Plugin_Handled;
}

public Action Command_SetEntData(int client, int args)
{
	if (args < 3) {
		PrintToChat(client, "Usage: !setentdata <ent index> <property name> <offset> <property value>");
		return Plugin_Handled;
	}

	char cmdArg[6][128];
	for (int x; x < 6; x++) {
		GetCmdArg(x + 1, cmdArg[x], sizeof(cmdArg[]));
	}

	int ent = StringToInt(cmdArg[0]);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
		return Plugin_Handled;
	}

	PropFieldType type;
	int num_bits;
	int local_offset;
	int offset = StringToInt(cmdArg[2]) + FindDataMapInfo(ent, cmdArg[1], type, num_bits, local_offset);

	if (offset == -1) {
		PrintToChat(client, "no offset found for %s", cmdArg[1]);
		return Plugin_Handled;
	}

	switch (type) {
		case PropField_Integer, PropField_Unsupported: {
			int intValue = StringToInt(cmdArg[3]);
			int oldValue = GetEntData(ent, offset);
			SetEntData(ent, offset, intValue);
			ChangeEdictState(ent, offset);
			PrintToChat(client, "set %s (offset %i) to %i (was %i)", cmdArg[1], offset, intValue, oldValue);
		}
		case PropField_Float: {
			float floatValue = StringToFloat(cmdArg[3]);
			float oldValue = GetEntDataFloat(ent, offset);
			SetEntDataFloat(ent, offset, floatValue);
			ChangeEdictState(ent, offset);
			PrintToChat(client, "set %s (offset %i) to %f (was %f)", cmdArg[1], offset, floatValue, oldValue);
		}
		case PropField_Entity: {
			int intValue = StringToInt(cmdArg[3]);
			int oldValue = GetEntDataEnt2(ent, offset);
			SetEntDataEnt2(ent, offset, intValue);
			ChangeEdictState(ent, offset);
			PrintToChat(client, "set %s (offset %i) to %i (was %i)", cmdArg[1], offset, intValue, oldValue);
		}
		case PropField_Vector: {
			float vectorValue[3];
			vectorValue[0] = StringToFloat(cmdArg[3]);
			vectorValue[1] = StringToFloat(cmdArg[4]);
			vectorValue[2] = StringToFloat(cmdArg[5]);
			float oldValue[3];
			GetEntDataVector(ent, offset, oldValue);
			SetEntDataVector(ent, offset, vectorValue);
			ChangeEdictState(ent, offset);
			PrintToChat(client, "set %s (offset %i) to %f %f %f (was %f %f %f)", cmdArg[1], offset, vectorValue[0], vectorValue[1], vectorValue[2], oldValue[0], oldValue[1], oldValue[2]);
		}
		case PropField_String, PropField_String_T: {
			char stringValue[256];
			Format(stringValue, sizeof(stringValue), "%s %s %s", cmdArg[3], cmdArg[4], cmdArg[5]);
			char oldValue[256];
			GetEntDataString(ent, offset, oldValue, sizeof(oldValue));
			SetEntDataString(ent, offset, stringValue, sizeof(stringValue));
			ChangeEdictState(ent, offset);
			PrintToChat(client, "set %s (offset %i) to %s (was %s)", cmdArg[1], offset, stringValue, oldValue);
		}
	}

	return Plugin_Handled;
}

public Action Command_GetViewModel(int client, int args)
{
	int clientViewModel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");
	PrintToChat(client, "viewmodel index is %i %b", clientViewModel, IsClientObserver(client));

	return Plugin_Handled;
}

public Action Command_SetEntityModel(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !setentitymodel <ent index> <modelpath>");
		return Plugin_Handled;
	}

	char entIndex[8];
	char modelPath[128];
	GetCmdArg(1, entIndex, sizeof(entIndex));
	GetCmdArg(2, modelPath, sizeof(modelPath));

	int ent = StringToInt(entIndex);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	PrecacheModel(modelPath, true);
	SetEntityModel(ent, modelPath);

	return Plugin_Handled;
}

public Action Command_GetEntPropString(int client, int args)
{
	if (args < 2) {
		PrintToChat(client, "Usage: !getentpropstring <ent index> <property name>");
		return Plugin_Handled;
	}

	char entIndex[8];
	char propName[128];
	GetCmdArg(1, entIndex, sizeof(entIndex));
	GetCmdArg(2, propName, sizeof(propName));

	int ent = StringToInt(entIndex);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	char propValue[128];
	GetEntPropString(ent, Prop_Data, propName, propValue, sizeof(propValue));
	PrintToChat(client, "Entity %i - %s: %s", ent, propName, propValue);

	return Plugin_Handled;
}

public Action Command_SetEntPropString(int client, int args)
{
	if (args < 3) {
		PrintToChat(client, "Usage: !setentpropstring <ent index> <property name> <value>");
		return Plugin_Handled;
	}

	char entIndex[8];
	char propName[128];
	char propValue[128];
	GetCmdArg(1, entIndex, sizeof(entIndex));
	GetCmdArg(2, propName, sizeof(propName));
	GetCmdArg(3, propValue, sizeof(propValue));

	int ent = StringToInt(entIndex);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	SetEntPropString(ent, Prop_Data, propName, propValue);

	return Plugin_Handled;
}

public Action Command_GetEntNetClass(int client, int args)
{
	if (args < 1) {
		PrintToChat(client, "Usage: !getentnetclass <ent index>");
		return Plugin_Handled;
	}

	int ent = GetCmdArgInt(1);
	if (ent == -1) {
		ent = Ink_GetClientAim(client);
	}
	if (!Entity_IsValid(ent)) {
		PrintToChat(client, "Entity %i does not exist", ent);
	}

	char netClass[64];
	GetEntityNetClass(ent, netClass, sizeof(netClass));
	PrintToChat(client, "NetClass of entity %i is %s", ent, netClass);

	return Plugin_Handled;
}

public Action Command_CreateFakeClient(int client, int args)
{
	if (args < 1) {
		PrintToChat(client, "Usage: !createfakeclient <name>");
		return Plugin_Handled;
	}

	char name[32];
	GetCmdArg(1, name, sizeof(name));

	CreateFakeClient(name);

	return Plugin_Handled;
}