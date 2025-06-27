/*
 *
 *	InkMod Build
 *	Enables players to spawn and manipulate entities
 *
**/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <dhooks>
#include <multicolors>
#include <loadsoundscript>

#pragma semicolon 1
#pragma newdecls required

#include <ink_stocks>
#include <ink_objects>

#define MAX_EDICTS  2048
#define ZERO_VECTOR view_as<float>({0.0, 0.0, 0.0})


public Plugin myinfo =
{
	name        = "InkMod Build",
	author      = "Inks",
	description = "Enables players to spawn and manipulate entities.",
	version     = "0.9.0",
	url         = ""
};


/*************************
          Globals         
*************************/

int LateLoad;

// convars
ConVar ink_maxplayerents;
ConVar ink_maxplayerlights;
ConVar ink_maxplayervehicles;
ConVar ink_maxlandsize;

// entity data
StringMap Object[MAX_EDICTS + 1] = {null, ...};
int InkDissolver = INVALID_ENT_REFERENCE;

// client data
int ClientId[MAXPLAYERS + 1];
float ClientCmdTime[MAXPLAYERS + 1];

// sprites
int PhysBeam;
int HaloSprite;
int BeamSprite;
int LaserSprite;
int CrystalBeam;


/**********************************
          Ink_Build Files          
**********************************/

// stocks
#include "ink_build/stocks/entity"
#include "ink_build/stocks/client"
#include "ink_build/stocks/effects"

// spawnables
#include "ink_build/spawn/prop.sp"
#include "ink_build/spawn/door.sp"
#include "ink_build/spawn/ladder.sp"
#include "ink_build/spawn/light.sp"
#include "ink_build/spawn/vehicle.sp"
#include "ink_build/spawn/internet.sp"

// entity modify commands
#include "ink_build/modify/color.sp"
#include "ink_build/modify/stack.sp"
#include "ink_build/modify/freeze.sp"
#include "ink_build/modify/grab.sp"
#include "ink_build/modify/move.sp"
#include "ink_build/modify/owner.sp"
#include "ink_build/modify/remove.sp"
#include "ink_build/modify/replace.sp"
#include "ink_build/modify/rotate.sp"
#include "ink_build/modify/scale.sp"
#include "ink_build/modify/skin.sp"
#include "ink_build/modify/weld.sp"
#include "ink_build/modify/lock.sp"

// land
#include "ink_build/land.sp"
#include "ink_build/save.sp"


/*********************************
          Initialization          
*********************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	LateLoad = late;
}

public void OnPluginStart()
{
	RegisterCvars();
	RegisterCommands();

	if (LateLoad) {
		for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
			if (IsValidEntity(ent)) {
				Object[ent] = GetInkObject(ent, false);
				SetUpEntityHook(ent);
			}
		}
		for (int client = 1; client <= MaxClients; client++) {
			if (IsClientAuthorized(client)) {
				Object[client] = GetInkObject(client, false);
				InitializeClient(client);
			}
		}
	}
}

public void OnMapStart()
{
	LoadAssets();
	CreateTimer(0.1, DrawLand, INVALID_HANDLE, TIMER_REPEAT);
}

// objects
public void OnObjectCreated(int index, StringMap obj)
{
	Object[index] = obj;
}

public void OnObjectDestroyed(int index)
{
	Object[index] = null;
}

// entities
void SetUpEntityHook(int ent)
{
	char class[32];
	GetEntityClassname(ent, class, sizeof(class));

	if (StrEqual(class, "prop_doll")) {
		SDKHook(ent, SDKHook_OnTakeDamage, OnDollTakeDamage);
	} else if (StrEqual(class, "prop_light")) {
		SDKHook(ent, SDKHook_Use, OnLightUse);
	} else if (StrEqual(class, "prop_internet")) {
		SDKHook(ent, SDKHook_Use, OnInternetUse);
	} else if (StrEqual(class, "prop_vehicle")) {
		HookSingleEntityOutput(ent, "PlayerOn", Vehicle_OnEnter);
		HookSingleEntityOutput(ent, "PlayerOff", Vehicle_OnExit);
	}
}

// clients
public void OnClientPostAdminCheck(int client)
{
	InitializeClient(client);
}

void InitializeClient(int client)
{
	ClientId[client] = GetSteamAccountID(client);
	ClientCmdTime[client] = 0.0;
}

// commands
void RegisterCommands()
{
	// spawnables
	RegAdminCmd("n_prop", Command_SpawnProp, 0, "Spawns a prop with the specified model.");
	RegAdminCmd("n_door", Command_SpawnDoor, 0, "Spawns a usable rotating door.");
	RegAdminCmd("n_ladder", Command_SpawnLadder, 0, "Spawns a usable ladder.");
	RegAdminCmd("n_light", Command_SpawnLight, 0, "Spawns a light.");
	RegAdminCmd("n_vehicle", Command_SpawnVehicle, 0, "Spawns a vehicle.");
	RegAdminCmd("n_internet", Command_SpawnInternet, 0, "Spawns a usable internet portal.");

	// entity modify commands
	RegAdminCmd("n_color", Command_ColorEnt, 0, "Changes the color of an entity.");
	RegAdminCmd("n_alpha", Command_AlphaEnt, 0, "Changes the alpha transparency of an entity.");
	RegAdminCmd("n_amt", Command_AlphaEnt, 0, "Changes the alpha transparency of an entity.");

	RegAdminCmd("n_freeze",   Command_FreezeEnt, 0, "Disables physics on the targeted entity.");
	RegAdminCmd("n_unfreeze", Command_UnfreezeEnt, 0, "Enables physics on the targeted entity.");

	RegAdminCmd("n_move", Command_MoveEnt, 0, "Moves an entity relative to the player's position.");
	RegAdminCmd("+move",  Command_MoveEnt, 0, "Moves an entity relative to the player's position.");
	RegAdminCmd("-move",  Command_MoveEnt, 0, "Moves an entity relative to the player's position.");

	RegAdminCmd("n_copy", Command_CopyEnt, 0, "Copies an entity and moves the copy relative to the player's position.");
	RegAdminCmd("+copy",  Command_CopyEnt, 0, "Copies an entity and moves the copy relative to the player's position.");
	RegAdminCmd("-copy",  Command_CopyEnt, 0, "Copies an entity and moves the copy relative to the player's position.");

	RegAdminCmd("n_lock", Command_LockEnt, 0, "Locks an entity, making it unusable.");
	RegAdminCmd("n_unlock",  Command_UnlockEnt, 0, "Unlocks an entity, making it usable.");

	RegAdminCmd("n_smove",  Command_SmoveEnt, 0, "Moves an entity by the given offset.");
	RegAdminCmd("n_moveto", Command_MoveToEnt, 0, "Moves an entity to another entity.");
	RegAdminCmd("n_drop",   Command_DropEnt, 0, "Drops an entity to ground level.");

	RegAdminCmd("n_owner", Command_GetEntOwner, 0, "Prints the owner of the targeted entity.");
	RegAdminCmd("n_give",  Command_GiveEnt, 0, "Offers the targeted entity to the specified player.");
	RegAdminCmd("n_claim",  Command_ClaimEnt, 0, "Accepts an entity ownership offer.");

	RegAdminCmd("n_remove", Command_RemoveEnt, 0, "Removes the targeted entity.");
	RegAdminCmd("n_del", Command_RemoveEnt, 0, "Removes the targeted entity.");

	RegAdminCmd("n_replace", Command_ReplaceEnt, 0, "Replaces the entity's model with the specified prop.");

	RegAdminCmd("n_rotate", Command_RotateEnt, 0, "Rotates an entity on it's axis, by the specified offset.");
	RegAdminCmd("n_stand",  Command_StandEnt, 0, "Sets an entity to it's default rotation (0 0 0).");

	RegAdminCmd("n_scale", Command_ScaleEnt, 0, "Changes the size of an entity.");

	RegAdminCmd("n_skin", Command_SkinEnt, 0, "Changes the skin of an entity.");

	RegAdminCmd("n_stack", Command_StackEnt, 0, "Makes a copy of an entity and moves it by the given offset");

	RegAdminCmd("n_weld",    Command_ParentEnt, 0, "Parents an entity to another entity.");
	RegAdminCmd("n_release", Command_UnparentEnt, 0, "Releases all entities from a parent.");

	RegAdminCmd("n_seturl", Command_SetURLEnt, 0, "Sets the destination url on an !internet portal");

	// land commands
	RegAdminCmd("n_land",  Command_Land, 0, "Creates a land area.");

	RegAdminCmd("n_save",  Command_Save, 0, "Saves your land-contained entities to the server.");
	RegAdminCmd("n_load",  Command_Load, 0, "Loads a previously saved build from the server.");
}

void RegisterCvars()
{
	// ent limits
	ink_maxplayerents = CreateConVar("ink_maxplayerents", "250", "Limit for number of total entity spawns per player");
	ink_maxplayerlights = CreateConVar("ink_maxplayerlights", "15", "Limit for number of total entity spawns per player");
	ink_maxplayervehicles = CreateConVar("ink_maxplayervehicles", "2",  "Limit for number of vehicle spawns per player");

	// land
	ink_maxlandsize = CreateConVar("ink_maxlandsize", "2048", "Maximum width of the player's land areas.");
}

// assets
void LoadAssets()
{
	// sprites
	PhysBeam    = PrecacheModel("materials/sprites/lgtning.vmt", true);
	HaloSprite  = PrecacheModel("materials/sprites/halo01.vmt", true);
	BeamSprite  = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	LaserSprite = PrecacheModel("materials/sprites/laser.vmt", true);
	CrystalBeam = PrecacheModel("materials/sprites/crystal_beam1.vmt", true);

	// sounds
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);

	PrecacheSound("physics/concrete/concrete_impact_soft1.wav", true);
	PrecacheSound("physics/concrete/concrete_impact_soft2.wav", true);
	PrecacheSound("physics/concrete/concrete_impact_soft3.wav", true);

	PrecacheSound("ambient/levels/citadel/weapon_disintegrate1.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate2.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate3.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate4.wav", true);

	PrecacheSound("buttons/lever7.wav", true);

	PrecacheSound("weapons/physgun_off.wav", true);

	// vehicles
	LoadSoundScript("scripts/game_sounds_vehicles.txt");
}


/***************************
            Loop            
***************************/

public void OnGameFrame()
{
	for (int ent = MaxClients + 1; ent <= MAX_EDICTS; ent++) {
		if (IsValidEntity(ent)) {
			EntOnGameFrame(ent);
		}
	}
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			ClientOnGameFrame(client);
		}
	}
}

void EntOnGameFrame(int ent)
{
	FindCurrentLand(ent);
}

void ClientOnGameFrame(int client)
{
	FindCurrentLand(client);
}


/***************************
          Disposal          
***************************/

public void OnPluginEnd()
{
	// dissolver entity
	if (IsValidEntity(InkDissolver)) {
		AcceptEntityInput(InkDissolver, "dissolve");
		AcceptEntityInput(InkDissolver, "Kill");
	}
}
