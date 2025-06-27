/*
 *
 *	InkMod Entity Data
 *	Manages entity data for InkMod
 *
**/
#include <sourcemod>
#include <ink_objects>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 1048576


public Plugin myinfo =
{
	name = "InkMod Objects",
	author = "Inks",
	description = "Manages entity data for InkMod.",
	version = "1.0.0",
	url = ""
}

GlobalForward ObjectsReady;
GlobalForward ObjectCreated;
GlobalForward ObjectDestroyed;

ObjectMap Objects = null;
int ClientId[MAXPLAYERS + 1];


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("InkMod Objects");
	CreateNative("GetInkObject", Native_GetInkObject);

	return APLRes_Success;
}

public void OnPluginStart()
{
	ObjectsReady = new GlobalForward("OnObjectsReady", ET_Ignore);
	ObjectCreated = new GlobalForward("OnObjectCreated", ET_Ignore, Param_Cell, Param_Cell);
	ObjectDestroyed = new GlobalForward("OnObjectDestroyed", ET_Ignore, Param_Cell);
}

public void OnMapStart()
{
	if (Objects != null) {
		Objects.Close();
	}

	Objects = new ObjectMap();

	Call_StartForward(ObjectsReady);
	Call_Finish();
}

public void OnEntityDestroyed(int ent)
{
	if (Objects != null && ent > MaxClients) {
		Objects.CloseObject(ent);
	}
}

public void OnClientPostAdminCheck(int client)
{
	ClientId[client] = GetSteamAccountID(client);
	Objects.GetObject(client, true);
}

int Native_GetInkObject(Handle plugin, int params)
{
	return view_as<int>(Objects.GetObject(GetNativeCell(1), GetNativeCell(2)));
}

methodmap ObjectMap < IntMap
{
	public ObjectMap()
	{
		return view_as<ObjectMap>(new IntMap());
	}

	public int IndexToKey(int &index)
	{
		if (index <= MaxClients && index > 0) {
			if (IsClientAuthorized(index)) {
				return ClientId[index];
			} else {
				return -1;
			}
		} else if (index > -1) {
			if (IsValidEntity(index)) {
				return EntIndexToEntRef(index);
			} else {
				return -1;
			}
		} else if ((index = EntRefToEntIndex(index)) != -1) {
			return EntIndexToEntRef(index);
		}

		return -1;
	}

	public StringMap GetObject(int index, bool create = false)
	{
		int key = this.IndexToKey(index);
		if (key == -1) {
			return null;
		}

		StringMap obj;
		if (!this.GetValue(key, obj)) {
			if (!create) {
				return null;
			}

			obj = new StringMap();
			if (!this.SetValue(key, obj)) {
				delete obj;
				return null;
			}

			Call_StartForward(ObjectCreated);
			Call_PushCell(index);
			Call_PushCell(obj);
			Call_Finish();
		}

		return obj;
	}

	public void CloseObject(int index)
	{
		int key = this.IndexToKey(index);
		if (key == -1) {
			return;
		}

		StringMap obj;
		if (!this.GetValue(key, obj)) {
			return;
		}

		delete obj;
		this.Remove(key);

		Call_StartForward(ObjectDestroyed);
		Call_PushCell(index);
		Call_Finish();
	}

	public void CloseAllObjects()
	{
		IntMapSnapshot snapshot = this.Snapshot();

		int len = snapshot.Length;
		for (int i = 0; i < len; i++) {
			int key = snapshot.GetKey(i);

			StringMap obj;
			if (this.GetValue(key, obj)) {
				delete obj;
			}
		}

		delete snapshot;
	}

	public void Close()
	{
		this.CloseAllObjects();
		delete this;
	}
}