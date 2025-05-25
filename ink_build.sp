#pragma semicolon 1
#pragma dynamic 131072

#include <smlib>
#include <sdkhooks>
#include <sdktools>
#include <ink_base>
#include <ink_build>

#define MAXENTS			2048
#define ZERO_VECTOR		Float:{0.0, 0.0, 0.0}
#define PHYS_WHITE		{255, 255, 255, 200}
#define PHYS_BLUE		{100, 200, 255, 255}
#define PHYS_GREY		{255, 255, 255, 300}


public Plugin:myinfo =
{
	name = "[INK] Build",
	description = "A CelMod-based advanced build mod.",
	author = "Inks",
	version = "1.3.9",
	url = "www.voyagersclan.com"
};


/* todo / idea: Let's do build teams differently:
 *
 * !addteam to invite someone to your team. they have to accept, and have nothing spawned to accept.
 * Your maximum land size will increase (by maybe +(.5*limit) each member). You gain the ability to modify/build with any entities your build team members spawn.
 * Your max prop/ent/etc. limits will increase with each member.
 * You will save your build team member's props.
 * This save will only be spawnable based on how many entities past the limit it contains:	past limit = 2 team members required
 *																							past 2x limit = 3 team members required
 *																							etc.
 * Build teams will be temporary until you disconnect. there will be another solution for accepting !give and allowing players to fly in your land, etc.
 */

// todo: saves -- find more shit to save. like buoyancy.
// todo: set up restricted areas
// todo: put on them entities that go on the entity corners and check em out of the map etc
// todo: fixup for csgo/css (especially csgo, them dynamic shadows)
// todo: create new globals for music/etc. "usetimes", usetime will be entirely for player use hook. another will be used for music length tracking, etc.

// Land:
new g_iLandCreate[MAXPLAYERS + 1];
new g_iLandColor[MAXPLAYERS + 1][4];
new g_eLandCorner[MAXPLAYERS + 1][4];
new g_eLandBeam[MAXPLAYERS + 1][4];
new Float:g_vecLandPoints[MAXPLAYERS + 1][4][3];
new Float:g_fLandCeiling[MAXPLAYERS + 1];

// Save command:
new bool:g_bSaving[MAXPLAYERS + 1];
new String:g_sSaveName[MAXPLAYERS + 1][32];

// Undo command:
new g_iUndoOwner[MAXPLAYERS + 1][256];
new String:g_sUndoQueue[MAXPLAYERS + 1][256][256];

// Grab/copy command:
new g_eGrabEnt[MAXPLAYERS + 1];
new g_eGrabChild[MAXPLAYERS + 1];
new g_eCopyEnt[MAXPLAYERS + 1];
new g_iGrabColor[MAXPLAYERS + 1][4];
new Float:g_vecGrabPos[MAXPLAYERS + 1][3];
new MoveType:g_mGrabMove[MAXPLAYERS + 1];

// Misc command globals:
new g_eMovetoEnt[MAXPLAYERS + 1];
new g_eWeldEnt[MAXPLAYERS + 1];
new g_eTeleEnt[MAXPLAYERS + 1];
new g_eBeamEnt[MAXPLAYERS + 1];
new g_eWireEnt[MAXPLAYERS + 1];
new g_eLightEnt[MAXPLAYERS + 1];
new g_eCustomEnt[MAXPLAYERS + 1];
new String:g_sCopyBuffer[MAXPLAYERS + 1][256];

new g_iCopyColor[MAXPLAYERS + 1][3];
new g_iCopySkin[MAXPLAYERS + 1];

// Land settings:
new g_iPlayerSize[MAXPLAYERS + 1] = {100, ...};
new g_iLandGravity[MAXPLAYERS + 1];
new bool:g_bDeathmatch[MAXPLAYERS + 1];
new bool:g_bStopFly[MAXPLAYERS + 1];
new bool:g_bStopCopy[MAXPLAYERS + 1];

new bool:g_bLandBan[MAXPLAYERS + 1][MAXPLAYERS + 1];

// Misc client globals:
new g_iPrevLand[MAXPLAYERS + 1];
new g_iDeathLand[MAXPLAYERS + 1];
new g_iBanPlayer[MAXPLAYERS + 1];
new g_eCamera[MAXPLAYERS + 1];
new bool:g_bInUse[MAXPLAYERS + 1];
new Float:g_fSpawnTime[MAXPLAYERS + 1];
new Float:g_fCameraTime[MAXPLAYERS + 1];
new Float:g_vecClientPos[MAXPLAYERS + 1][3];
new String:g_sClientAuth[MAXPLAYERS + 1][64];

// Ent globals:
new g_iGiveEnt[MAXENTS + 1];
new Float:g_fUseTime[MAXENTS + 1];
new Handle:g_hUseTimer[MAXENTS + 1] = {INVALID_HANDLE, ...};

// Misc plugin globals:
new InkDissolver;
new bool:LateLoad;
new String:PropPath[PLATFORM_MAX_PATH];
new String:ColorPath[PLATFORM_MAX_PATH];
new String:SoundPath[PLATFORM_MAX_PATH];
new String:MusicPath[PLATFORM_MAX_PATH];
new String:WeaponPath[PLATFORM_MAX_PATH];

// new String:g_sDataString[4000][512];

new g_iUseClient;
new g_iAppID;

new Handle:g_hBuildDB = INVALID_HANDLE;

// Cvars:
new Handle:sv_ink_maxprops;
new Handle:sv_ink_maxcels;
new Handle:sv_ink_maxlights;
new Handle:sv_ink_maxbits;
new Handle:sv_ink_maxlandsize;
new Handle:sv_ink_globalgod;
new Handle:sv_ink_globalfly;

new Handle:sv_gravity;

// Sprite indexes for lands, etc:
new BeamSprite;
new HaloSprite;
new PhysBeam;
new LaserSprite;
new CrystalBeam;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("INK_GetOwner", Native_INK_GetOwner);
	CreateNative("INK_SetOwner", Native_INK_SetOwner);
	
	CreateNative("INK_RemoveEnt", Native_INK_RemoveEnt);
	
	CreateNative("INK_GetPropCount", Native_INK_GetPropCount);
	CreateNative("INK_GetCelCount", Native_INK_GetCelCount);
	CreateNative("INK_GetLightCount", Native_INK_GetLightCount);
	CreateNative("INK_GetBitCount", Native_INK_GetBitCount);
	CreateNative("INK_GetTotalCount", Native_INK_GetTotalCount);
	
	CreateNative("INK_EntToString", Native_INK_EntToString);
	CreateNative("INK_StringToEnt", Native_INK_StringToEnt);
	
	CreateNative("INK_ActivateEnt", Native_INK_ActivateEnt);
	
	LateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	// Game:
	decl String:sGameName[16];
	GetGameFolderName(sGameName, sizeof(sGameName));
	
	if(StrEqual(sGameName, "cstrike"))
		g_iAppID = 240;
	else if(StrEqual(sGameName, "hl2mp"))
		g_iAppID = 320;
	else if(StrEqual(sGameName, "tf"))
		g_iAppID = 440;
	
	// Land commands:
	RegAdminCmd("n_land", Command_SetLand, 0, "Sets up your land build area.");
	
	RegAdminCmd("n_save", Command_SaveBuild, 0, "Saves all entities in your land to a file.");
	RegAdminCmd("n_load", Command_LoadBuild, 0, "Saves all entities in your land to a file.");
	
	RegAdminCmd("n_stopcopy", Command_StopCopy, 0, "Prevents other players from copying your props.");
	
	RegAdminCmd("n_nofly", Command_StopFly, 0, "Prevents other players from flying in your land.");
	
	RegAdminCmd("n_playersize", Command_PlayerSize, 0, "Size of players within your land.");
	RegAdminCmd("n_psize", Command_PlayerSize, 0, "Size of players within your land.");
	
	RegAdminCmd("n_playergravity", Command_PlayerGrav, 0, "Size of players within your land.");
	RegAdminCmd("n_pgravity", Command_PlayerGrav, 0, "Size of players within your land.");
	RegAdminCmd("n_pgrav", Command_PlayerGrav, 0, "Size of players within your land.");
	
	RegAdminCmd("n_deathmatch", Command_Deathmatch, 0, "Enables/disables deathmatch mode in your land.");
	RegAdminCmd("n_dm", Command_Deathmatch, 0, "Enables/disables deathmatch mode in your land.");
	
	RegAdminCmd("n_landban", Command_Landban, 0, "Bans a player from entering your land.");
	
	RegAdminCmd("n_landunban", Command_Landunban, 0, "Unbans a player from your land.");
	RegAdminCmd("n_unlandban", Command_Landunban, 0, "Unbans a player from your land.");
	
	// Entity spawn commands:
	RegAdminCmd("n_spawn", Command_SpawnProp, 0, "Spawns a prop.");
	RegAdminCmd("n_prop", Command_SpawnProp, 0, "Spawns a prop.");
	
	RegAdminCmd("n_light", Command_SpawnLight, 0, "Spawns a light.");
	RegAdminCmd("n_door", Command_SpawnDoor, 0, "Spawns a door.");
	RegAdminCmd("n_ladder", Command_SpawnLadder, 0, "Spawns a ladder.");
	RegAdminCmd("n_internet", Command_SpawnInternet, 0, "Spawns an internet cel.");
	RegAdminCmd("n_sound", Command_SpawnSound, 0, "Spawns a sound cel.");
	RegAdminCmd("n_music", Command_SpawnMusic, 0, "Spawns a music cel.");
	RegAdminCmd("n_fire", Command_SpawnFire, 0, "Spawns a fire cel.");
	RegAdminCmd("n_teleport", Command_SpawnTeleport, 0, "Spawns a teleport cel.");
	RegAdminCmd("n_button", Command_SpawnButton, 0, "Spawns a button cel.");
	RegAdminCmd("n_trigger", Command_SpawnTrigger, 0, "Spawns a trigger cel.");
	RegAdminCmd("n_camera", Command_SpawnCamera, 0, "Spawns a camera cel.");
	RegAdminCmd("n_slider", Command_SpawnSlider, ADMFLAG_ROOT, "Spawns a slider cel. WIP"); // todo: GET THIS SHIT WORKING.
	
	// These are very game-specific, so they're currently only supported on hl2dm:
	if(g_iAppID == 320)
	{
		RegAdminCmd("n_weapon", Command_SpawnWeapon, 0, "Spawns a weapon bit.");
		RegAdminCmd("n_wep", Command_SpawnWeapon, 0, "Spawns a weapon bit.");
		RegAdminCmd("n_ammo", Command_SpawnAmmo, 0, "Spawns an ammo bit.");
		RegAdminCmd("n_ammocrate", Command_SpawnAmmocrate, 0, "Spawns an ammocrate bit.");
		RegAdminCmd("n_charger", Command_SpawnCharger, 0, "Spawns a charger bit.");
	}
	
	RegAdminCmd("n_ent", Command_CustomEnt, ADMFLAG_ROOT, "Create/modify a custom entity. WARNING: Can cause crashes. Experienced users only.");
	RegAdminCmd("n_beament", Command_BeamEnt, ADMFLAG_ROOT, "Beam between two entities.");
	RegAdminCmd("n_flashlight", Command_Flashlight, 0, "Beam between two entities.");
	
	RegAdminCmd("n_testprop", Command_SpawnTestProp, ADMFLAG_ROOT);
	
	RegAdminCmd("+copy", Command_CopymoveEnt, 0, "Copies an entity, and starts moving it.");
	RegAdminCmd("-copy", Command_CopymoveEnt, 0, "Copies an entity, and starts moving it.");
	
	RegAdminCmd("n_copy", Command_CopyEnt, 0, "Copies an entity, for use with !paste");
	RegAdminCmd("n_paste", Command_PasteEnt, 0, "Pastes the copied entity.");
	
	RegAdminCmd("n_undo", Command_UndoRemove, 0, "Undoes the removal of entities.");
	
	// Entity modify commands:
	RegAdminCmd("n_remove", Command_RemoveEnt, 0, "Removes an entity.");
	RegAdminCmd("n_delete", Command_RemoveEnt, 0, "Removes an entity.");
	RegAdminCmd("n_del", Command_RemoveEnt, 0, "Removes an entity.");
	RegAdminCmd("n_delall", Command_RemoveEnt, 0, "Removes an entity.");
	RegAdminCmd("n_removeall", Command_RemoveEnt, 0, "Removes an entity.");
	
	RegAdminCmd("+move", Command_MoveEnt, 0, "Moves an entity.");
	RegAdminCmd("-move", Command_MoveEnt, 0, "Moves an entity.");
	RegAdminCmd("n_move", Command_MoveEnt, 0, "Moves an entity.");
	
	RegAdminCmd("n_stack", Command_StackEnt, 0, "Creates a copy of a prop towards the specified coordinate.");
	
	RegAdminCmd("n_freeze", Command_FreezeEnt, 0, "Freezes an entity.");
	RegAdminCmd("n_unfreeze", Command_UnfreezeEnt, 0, "Freezes an entity.");
	
	RegAdminCmd("n_rotate", Command_RotateEnt, 0, "Rotates an entity. (pitch, yaw, roll)");
	
	RegAdminCmd("n_straight", Command_StandEnt, 0, "Resets an entity's angle.");
	RegAdminCmd("n_stand", Command_StandEnt, 0, "Resets an entity's angle.");
	
	RegAdminCmd("n_skin", Command_SkinEnt, 0, "Changes the skin of an entity.");
	
	RegAdminCmd("n_solid", Command_SolidEnt, 0, "Changes the solidity of an entity.");
	RegAdminCmd("n_nocollide", Command_SolidEnt, 0, "Changes the solidity of an entity.");
	RegAdminCmd("n_collide", Command_SolidEnt, 0, "Changes the solidity of an entity.");
	
	RegAdminCmd("n_god", Command_GodEnt, 0, "Changes the invincibility of an entity.");
	
	RegAdminCmd("n_give", Command_GiveEnt, 0, "Gives an entity to another player.");
	RegAdminCmd("n_accept", Command_AcceptEnt, 0, "Accepts an entity from another player.");
	
	RegAdminCmd("n_color", Command_ColorEnt, 0, "Changes the color of an entity.");
	RegAdminCmd("n_colour", Command_ColorEnt, 0, "Changes the color of an entity.");
	RegAdminCmd("n_paint", Command_ColorEnt, 0, "Changes the color of an entity.");
	
	RegAdminCmd("n_amt", Command_AlphaEnt, 0, "Changes the alpha transparency of an entity.");
	RegAdminCmd("n_alpha", Command_AlphaEnt, 0, "Changes the alpha transparency of an entity.");
	RegAdminCmd("n_transparency", Command_AlphaEnt, 0, "Changes the alpha transparency of an entity.");
	
	RegAdminCmd("n_replace", Command_ModelEnt, 0, "Changes the model of an entity.");
	RegAdminCmd("n_model", Command_ModelEnt, 0, "Changes the model of an entity.");
	RegAdminCmd("n_setmodel", Command_ModelEnt, 0, "Changes the model of an entity.");
	
	RegAdminCmd("n_drop", Command_DropEnt, 0, "Drops the entity to ground level.");
	RegAdminCmd("n_smove", Command_SmoveEnt, 0, "Alters the origin of an entity slightly.");
	RegAdminCmd("n_moveto", Command_MovetoEnt, 0, "Moves an entity directly to another.");
	
	RegAdminCmd("n_weld", Command_WeldEnt, 0, "Parents an entity to another.");
	RegAdminCmd("n_unweld", Command_UnweldEnt, 0, "Releases an entity from it's parent.");
	RegAdminCmd("n_release", Command_UnweldEnt, 0, "Releases an entity from it's parent.");
	
	RegAdminCmd("n_lock", Command_LockEnt, 0, "Disables +use of an entity.");
	RegAdminCmd("n_unlock", Command_UnlockEnt, 0, "Enables +use of an entity.");
	
	RegAdminCmd("n_seturl", Command_SeturlEnt, 0, "Sets the URL of an internet cel.");
	
	RegAdminCmd("n_wire", Command_WireEnt, 0, "Wires two entities together.");
	
	RegAdminCmd("n_skybox", Command_SkyBox, ADMFLAG_ROOT, "Changes the skybox.");
	RegAdminCmd("n_scale", Command_ScaleEnt, ADMFLAG_ROOT, "Resizes a prop.");
	RegAdminCmd("n_activate", Command_ActivateEnt, ADMFLAG_ROOT, "Activates an entity.");
	
	if(g_iAppID == 440)
		RegAdminCmd("n_delobj", Command_DelObjective, ADMFLAG_ROOT, "Removes the objective from TF2 maps.");
	
	// Info commands:
	RegAdminCmd("n_owner", Command_EntOwner, 0, "Retrieves the owner of an entity.");
	RegAdminCmd("n_count", Command_EntCount, 0, "Returns current entity count.");
	RegAdminCmd("n_infostring", Command_EntString, 0, "Returns the string buffer containing an entity's save data.");
	RegAdminCmd("n_axis", Command_DisplayAxis, 0, "Displays the XYZ axis.");
	
	RegAdminCmd("n_maxents", Command_MaxEntities, ADMFLAG_ROOT, "Prints GetMaxEntities().");
	
	RegAdminCmd("n_listentprop", Command_ListEntProp, ADMFLAG_ROOT);
	
	/* RegServerCmd("n_createpropsql", Command_CreatePropSQL);
	RegServerCmd("n_genpropdb", Command_GenPropDB); */
	
	// Other commmands:
	RegAdminCmd("noclip", Command_Noclip, 0, "Gives you noclip.");
	RegAdminCmd("sm_noclip", Command_Noclip, 0, "Gives you noclip.");
	
	if(ConCommand_HasFlags("noclip", FCVAR_CHEAT))
		ConCommand_RemoveFlags("noclip", FCVAR_CHEAT);
	
	LoadTranslations("common.phrases");
	
	// File paths:
	BuildPath(Path_SM, PropPath, sizeof(PropPath), "data/ink_build/props.txt");
	BuildPath(Path_SM, ColorPath, sizeof(ColorPath), "data/ink_build/colors.txt");
	BuildPath(Path_SM, SoundPath, sizeof(SoundPath), "data/ink_build/sounds.txt");
	BuildPath(Path_SM, MusicPath, sizeof(MusicPath), "data/ink_build/music.txt");
	BuildPath(Path_SM, WeaponPath, sizeof(WeaponPath), "data/ink_build/weapons.txt");
	
	// Cvars:
	sv_ink_maxprops = CreateConVar("sv_ink_maxprops", "200", "Per-client prop limit.", FCVAR_PLUGIN|FCVAR_NOTIFY, true);
	sv_ink_maxcels = CreateConVar("sv_ink_maxcels", "25", "Per-client cel limit.", FCVAR_PLUGIN|FCVAR_NOTIFY, true);
	sv_ink_maxlights = CreateConVar("sv_ink_maxlights", "5", "Per-client light limit.", FCVAR_PLUGIN|FCVAR_NOTIFY, true);
	sv_ink_maxbits = CreateConVar("sv_ink_maxbits", "25", "Per-client bit limit.", FCVAR_PLUGIN|FCVAR_NOTIFY, true);
	sv_ink_maxlandsize = CreateConVar("sv_ink_maxlandsize", "1500", "Maximum land size in units.", FCVAR_PLUGIN|FCVAR_NOTIFY, true);
	sv_ink_globalgod = CreateConVar("sv_ink_globalgod", "0", "Enables godmode.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sv_ink_globalfly = CreateConVar("sv_ink_globalfly", "0", "Enables noclip.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	sv_gravity = FindConVar("sv_gravity");
	
	new String:error[512];
	g_hBuildDB = SQL_Connect("voy_hl2_build", true, error, sizeof(error));
	
	if(g_hBuildDB == INVALID_HANDLE)
		LogError(error);
	
	// Tick:
	CreateTimer(0.1, PluginTick, INVALID_HANDLE, TIMER_REPEAT);
	
	HookEvent("player_death", EventDeath);
	HookEventEx("player_spawn", EventSpawn);
}

public OnMapStart()
{
	// Precache sprites:
	BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	HaloSprite = PrecacheModel("materials/sprites/halo01.vmt", true);
	PhysBeam = PrecacheModel("materials/sprites/lgtning.vmt", true);
	LaserSprite = PrecacheModel("materials/sprites/laser.vmt", true);
	CrystalBeam = PrecacheModel("materials/sprites/crystal_beam1.vmt", true);
	
	// Precache sounds:
	
	PrecacheSound("common/wpn_select.wav", true);
	PrecacheSound("common/wpn_denyselect.wav", true);
	// del:
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate1.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate2.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate3.wav", true);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate4.wav", true);
	// modify:
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", true);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", true);
	// weld:
	PrecacheSound("weapons/physgun_off.wav", true);
	// rotate:
	PrecacheSound("buttons/lever7.wav", true);
	// stack:
	PrecacheSound("physics/concrete/concrete_impact_soft1.wav", true);
	PrecacheSound("physics/concrete/concrete_impact_soft2.wav", true);
	PrecacheSound("physics/concrete/concrete_impact_soft3.wav", true);
	// teleport:
	PrecacheSound("npc/roller/code2.wav", true);
	// links / buttons:
	PrecacheSound("buttons/button19.wav", true);
	PrecacheSound("buttons/combine_button1.wav", true);
	
	// Dissolver:
	InkDissolver = CreateEntityByName("env_entity_dissolver");
	
	DispatchKeyValue(InkDissolver, "target", "deleted");
	DispatchKeyValue(InkDissolver, "magnitude", "0");
	DispatchKeyValue(InkDissolver, "dissolvetype", "3");
	
	DispatchSpawn(InkDissolver);
	
	if(LateLoad)
	{
		// Load clients:
		for(new Client = 1; Client <= MaxClients; Client++)
		{
			if(IsClientInGame(Client))
				INK_SetupClient(Client);
		}
		
		// Set up entities:
		new iMaxEnts = GetMaxEntities();
		for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
		{
			if(IsValidEntity(Ent))
			{
				decl String:sEntClass[32];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrEqual(sEntClass, "cel_doll", false))
					SDKHook(Ent, SDKHook_OnTakeDamage, DollTakeDamage);
				
				else if(StrEqual(sEntClass, "cel_sound", false))
					g_fUseTime[Ent] = GetGameTime();
				
				else if(StrEqual(sEntClass, "cel_trigger", false))
					SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
				
				else if(StrEqual(sEntClass, "bit_weapon", false))
					SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
				
				else if(StrEqual(sEntClass, "bit_ammo", false))
					SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
			}
		}
	}
	
	// No OnPlayerUse in TF2! We can get to these another way:
	if(g_iAppID != 440)
	{
		HookEntityOutput("cel_internet", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_sound", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_music", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_teleport", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_button", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_light", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_camera", "OnPlayerUse", HookActivate);
		HookEntityOutput("cel_slider", "OnPlayerUse", HookActivate);
	}
}

/************************************************************************************/
/*									  --  (SQL)  --									*/
/************************************************************************************/


// Land-ban:
public DB_CheckLandban(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(!SQL_GetRowCount(hndl))
		{
			decl String:Query[256];
			Format(Query, sizeof(Query), "INSERT INTO `users_landbans` VALUES ('%s', '%s', '%d')", g_sClientAuth[data], g_sClientAuth[g_iBanPlayer[data]], GetTime());
			
			SQL_TQuery(g_hBuildDB, DB_LandBan, Query, data);
		}
		else if(SQL_FetchRow(hndl))
		{
			INK_Message(data, "This player is already banned from your land.");
			g_iBanPlayer[data] = 0;
		}
	}
	else
	{
		LogError(error);
		g_iBanPlayer[data] = 0;
	}
}
public DB_LandBan(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		INK_Message(data, "Banned {green}%N{default} from your land.", g_iBanPlayer[data]);
		INK_Message(g_iBanPlayer[data], "You have been banned from {green}%N{default}'s land.", data);
		
		g_bLandBan[data][g_iBanPlayer[data]] = true;
	}
	else LogError(error);
	
	g_iBanPlayer[data] = 0;
}

// Land-unban:
public DB_CheckLandunban(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(!SQL_GetRowCount(hndl))
		{
			INK_Message(data, "This player is not banned from your land.");
			g_iBanPlayer[data] = 0;
		}
		else if(SQL_FetchRow(hndl))
		{
			decl String:Query[256];
			Format(Query, sizeof(Query), "DELETE FROM `users_landbans` WHERE `Land` = '%s' AND `Banned` = '%s'", g_sClientAuth[data], g_sClientAuth[g_iBanPlayer[data]]);
			
			SQL_TQuery(g_hBuildDB, DB_LandUnban, Query, data);
		}
	}
	else
	{
		g_iBanPlayer[data] = 0;
		LogError(error);
	}
}
public DB_LandUnban(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		INK_Message(data, "Unbanned {green}%N{default} from your land.", g_iBanPlayer[data]);
		INK_Message(g_iBanPlayer[data], "You have been unbanned from {green}%N{default}'s land.", data);
		
		g_bLandBan[data][g_iBanPlayer[data]] = false;
	}
	else LogError(error);
	
	g_iBanPlayer[data] = 0;
}

// Load land-ban:
public DB_LoadLandban(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(!SQL_GetRowCount(hndl))
			g_bLandBan[data][g_iBanPlayer[data]] = false;
		
		else if(SQL_FetchRow(hndl))
			g_bLandBan[data][g_iBanPlayer[data]] = true;
	}
	else LogError(error);
	
	g_iBanPlayer[data] = 0;
}

// Props DB:
/* public DB_CheckPropData(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_FetchRow(hndl))
		{
			decl String:Query[256];
			
			decl String:sPropBuffer[3][128];
			ExplodeString(g_sDataString[data], "^", sPropBuffer, 3, sizeof(sPropBuffer[]));
			
			Format(Query, sizeof(Query), "UPDATE `props_list` SET `Alias` = '%s', `Access` = '1', `Type` = '%s' WHERE `Path` = '%s'", sPropBuffer[0], sPropBuffer[2], sPropBuffer[1]);
			SQL_TQuery(g_hBuildDB, DB_UpdatePropData, Query, data);
		}
	}
	else LogError(error);
}
public DB_UpdatePropData(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
		PrintToServer("[INK-SQL] ERROR WRITING %s TO DB.", g_sDataString[data]);
		strcopy(g_sDataString[data], sizeof(g_sDataString[]), "");
	}
	else
	{
		PrintToServer("[INK-SQL] WROTE %s TO DB.", g_sDataString[data]);
		strcopy(g_sDataString[data], sizeof(g_sDataString[]), "");
	}
} */

/************************************************************************************/
/*								--  (Base Functions)  --							*/
/************************************************************************************/


public OnGameFrame()
{
	for(new Client = 1; Client <= MaxClients; Client++)
	{
		if(IsClientInGame(Client))
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(Client, vecClientPos);
			
			// If player is +moving an entity:
			if(g_eGrabEnt[Client] != 0)
			{
				if(IsValidEntity(g_eGrabEnt[Client]))
				{
					// Calculate new position:
					decl Float:vecNewPos[3];
					SubtractVectors(vecClientPos, g_vecGrabPos[Client], vecNewPos);
					
					// Update:
					TeleportEntity(g_eGrabEnt[Client], vecNewPos, NULL_VECTOR, NULL_VECTOR);
				}
				else g_eGrabEnt[Client] = 0;
			}
			else if(g_eCopyEnt[Client] != 0)
			{
				if(IsValidEntity(g_eCopyEnt[Client]))
				{
					// Calculate new position:
					decl Float:vecNewPos[3];
					SubtractVectors(vecClientPos, g_vecGrabPos[Client], vecNewPos);
					
					// Update:
					TeleportEntity(g_eCopyEnt[Client], vecNewPos, NULL_VECTOR, NULL_VECTOR);
				}
				else g_eCopyEnt[Client] = 0;
			}
			
			if(g_eLightEnt[Client] != 0)
			{
				if(IsValidEntity(g_eLightEnt[Client]))
				{
					// Calculate new position:
					decl Float:vecEyePos[3], Float:vecEyeAng[3];
					GetClientEyePosition(Client, vecEyePos);
					GetClientEyeAngles(Client, vecEyeAng);
					
					// Update:
					TeleportEntity(g_eLightEnt[Client], vecEyePos, vecEyeAng, NULL_VECTOR);
				}
				else g_eLightEnt[Client] = 0;
			}
			
			if(g_iLandCreate[Client] == 1)
			{
				decl Float:vecAimPos[3];
				INK_AimPosition(Client, vecAimPos);
				
				// Calculate:
				g_vecLandPoints[Client][2][0] = vecAimPos[0];
				g_vecLandPoints[Client][2][1] = vecAimPos[1];
				g_vecLandPoints[Client][2][2] = g_vecLandPoints[Client][0][2];
				
				g_vecLandPoints[Client][1][0] = g_vecLandPoints[Client][2][0];
				g_vecLandPoints[Client][1][1] = g_vecLandPoints[Client][0][1];
				g_vecLandPoints[Client][1][2] = g_vecLandPoints[Client][0][2];
				
				g_vecLandPoints[Client][3][0] = g_vecLandPoints[Client][0][0];
				g_vecLandPoints[Client][3][1] = g_vecLandPoints[Client][2][1];
				g_vecLandPoints[Client][3][2] = g_vecLandPoints[Client][0][2];
				
				// Clamp:
				new iMaxLand = GetConVarInt(sv_ink_maxlandsize);
				
				for(new x; x < 2; x++)
				{
					if(g_vecLandPoints[Client][1][x] > g_vecLandPoints[Client][0][x] + iMaxLand)
						g_vecLandPoints[Client][1][x] = g_vecLandPoints[Client][0][x] + iMaxLand;
					if(g_vecLandPoints[Client][3][x] > g_vecLandPoints[Client][0][x] + iMaxLand)
						g_vecLandPoints[Client][3][x] = g_vecLandPoints[Client][0][x] + iMaxLand;
					
					if(g_vecLandPoints[Client][1][x] < g_vecLandPoints[Client][0][x] - iMaxLand)
						g_vecLandPoints[Client][1][x] = g_vecLandPoints[Client][0][x] - iMaxLand;
					if(g_vecLandPoints[Client][3][x] < g_vecLandPoints[Client][0][x] - iMaxLand)
						g_vecLandPoints[Client][3][x] = g_vecLandPoints[Client][0][x] - iMaxLand;
				}
				
				g_vecLandPoints[Client][2][0] = g_vecLandPoints[Client][1][0];
				g_vecLandPoints[Client][2][1] = g_vecLandPoints[Client][3][1];
				
				// Beams:
				for(new x; x < 4; x++)
					TeleportEntity(g_eLandCorner[Client][x], g_vecLandPoints[Client][x], NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public OnPluginEnd()
{
	// It's easier to remove this than to find it again on reload:
	if(IsValidEntity(InkDissolver))
	{
		AcceptEntityInput(InkDissolver, "dissolve");
		AcceptEntityInput(InkDissolver, "Kill");
	}
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			decl String:sEntClass[32];
			GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
			
			// Stop sound/music:
			if(StrEqual(sEntClass, "cel_music", false) || StrEqual(sEntClass, "cel_sound", false))
			{
				decl String:sTarget[192];
				GetEntPropString(Ent, Prop_Data, "m_target", sTarget, sizeof(sTarget));
				
				decl String:sMusicArray[2][128];
				ExplodeString(sTarget, "^", sMusicArray, 2, sizeof(sMusicArray[]));
				
				StopSound(Ent, SNDCHAN_AUTO, sMusicArray[0]);
			}
			else if(StrContains(sEntClass, "ink_land", false) != -1)
				AcceptEntityInput(Ent, "Kill");
		}
	}
}

public OnClientPutInServer(Client)
{
	INK_SetupClient(Client);
}

public OnClientDisconnect(Client)
{
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
				INK_RemoveEnt(Ent, false);
		}
	}
	
	INK_SetupClient(Client, true);
}

public Action:PluginTick(Handle:Timer, any:Data)
{
	for(new Client = 1; Client <= MaxClients; Client++)
	{
		if(IsClientInGame(Client))
		{
			decl Float:vecAimPos[3];
			INK_AimPosition(Client, vecAimPos);
			
			new eTarget = INK_AimTarget(Client);
			
			new Owner;
			if(eTarget > MaxClients)
				Owner = INK_GetOwner(eTarget);
				
			// Target HUD:
			if(Owner > 0)
			{
				SetHudTextParamsEx(3.050, -0.110, 0.4, g_iLandColor[Owner]);
				
				decl String:sEntClass[128];
				GetEntityClassname(eTarget, sEntClass, sizeof(sEntClass));
				
				if(StrEqual(sEntClass, "prop_physics", false))
				{
					decl String:sEntTarget[128];
					GetEntPropString(eTarget, Prop_Data, "m_target", sEntTarget, sizeof(sEntTarget));
					
					new buttons = GetClientButtons(Client);
					if(buttons & IN_SCORE)
					{
						new iSkin = GetEntProp(eTarget, Prop_Send, "m_nSkin", 1);
						ShowHudText(Client, 6, "Owner: %N   \nProp: %s   \nSkin: %d   ", Owner, sEntTarget, iSkin);
					}
					else ShowHudText(Client, 6, "Owner: %N   \nProp: %s   ", Owner, sEntTarget);
				}
				else ShowHudText(Client, 6, "Owner: %N   ", Owner);
			}
			else
			{
				new iAimLand = INK_GetLand(vecAimPos);
				if(iAimLand > 0)
				{
					SetHudTextParamsEx(3.050, -0.110, 0.4, g_iLandColor[iAimLand]);
					ShowHudText(Client, 6, "Land: %N   ", iAimLand);
				}
				else ShowHudText(Client, 6, " ");
			}
			
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(Client, vecClientPos);
			
			// Lands:
			new iLand = INK_GetLand(vecClientPos);
			
			// This block executes when a client exits/enters a land area:
			if(iLand != g_iPrevLand[Client])
			{
				if(g_bLandBan[iLand][Client])
				{
					INK_Message(Client, "You have been banned from this land.");
					TeleportEntity(Client, g_vecClientPos[Client], NULL_VECTOR, ZERO_VECTOR);
					
					g_iPrevLand[Client] = INK_GetLand(vecClientPos);
				}
				else
				{
					// Noclip:
					if(g_bStopFly[iLand] && Client != iLand)
					{
						if(GetEntPropEnt(Client, Prop_Send, "m_hGroundEntity") != 0)
						{
							if(vecClientPos[2] > g_vecLandPoints[iLand][0][2] + 100 || GetEntityMoveType(Client) != MOVETYPE_WALK)
							{
								INK_Message(Client, "You are not allowed to fly inside this land.");
								TeleportEntity(Client, g_vecClientPos[Client], NULL_VECTOR, ZERO_VECTOR);
							}
							
							SetEntityMoveType(Client, MOVETYPE_WALK);
						}
					}
					
					// Deathmatch:
					if(g_bDeathmatch[iLand])
					{
						SetEntityRenderColor(Client, 255, 0, 0, 255);
						INK_Message(Client, "WARNING: This land has deathmatch enabled.");
					}
					else SetEntityRenderColor(Client, 255, 255, 255, 255);
					
					// Player size:
					if(g_iAppID == 440)
						SetEntPropFloat(Client, Prop_Send, "m_flModelScale", 0.9*(float(g_iPlayerSize[iLand])/100.0));
					else
						SetEntPropFloat(Client, Prop_Send, "m_flModelScale", float(g_iPlayerSize[iLand])/100.0);
					
					// Player gravity:
					if(g_iLandGravity[iLand] != 0)
						SetEntityGravity(Client, float(g_iLandGravity[iLand])/GetConVarInt(sv_gravity));
					else if(iLand != 0)
						SetEntityGravity(Client, 0.000001);
					else SetEntityGravity(Client, 1.0);
					
					g_iPrevLand[Client] = iLand;
				}
			}
			
			// Copy the clients position while out of land so we can easily teleport them out if needed:
			if(iLand == 0)
			{
				g_vecClientPos[Client][0] = vecClientPos[0];
				g_vecClientPos[Client][1] = vecClientPos[1];
				g_vecClientPos[Client][2] = vecClientPos[2];
			}
		}
	}
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			new Owner = INK_GetOwner(Ent);
			if(Owner > 0)
			{
				decl Float:vecEntPos[3];
				INK_GetEntPos(Ent, vecEntPos);
				
				new iLand = INK_GetLand(vecEntPos);
				
				if(g_bLandBan[iLand][Owner])
				{
					INK_RemoveEnt(Ent, false);
					INK_Message(Owner, "Your entity has been removed for entering a banned land.");
				}
			}
		}
	}
}

public OnEntityCreated(Ent, const String:classname[])
{
	if(-1 < Ent < MAXENTS+1)
		g_iGiveEnt[Ent] = 0;
}

/************************************************************************************/
/*								--  (Player Commands)  --							*/
/************************************************************************************/


// LAND COMMANDS:

public Action:Command_SetLand(Client, Args)
{
	decl String:Arg1[16];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	
	if(StrEqual(Arg1, "#clear", false))
	{
		INK_Message(Client, "Cleared land.");
		
		INK_CreateLandEnts(Client, false);
		
		g_iLandCreate[Client] = 0;
		return Plugin_Handled;
	}
	
	if(g_iLandCreate[Client] == 0)
	{
		INK_AimPosition(Client, g_vecLandPoints[Client][0]);
		g_vecLandPoints[Client][0][2]++;
		
		if(INK_GetLand(g_vecLandPoints[Client][0]) != 0)
		{
			INK_Message(Client, "Land intercepting another player's land area.");
			INK_Message(Client, "Do {green}!land #clear{default} to cancel land creation.");
			return Plugin_Handled;
		}
		
		INK_Message(Client, "Set initial start of land.");
		INK_Message(Client, "Now do {green}!land{default} again to end land.");
		
		INK_CreateLandEnts(Client);
		
		g_iLandCreate[Client] = 1;
	}
	else if(g_iLandCreate[Client] == 1)
	{
		// Get ceiling:
		decl Float:vecCeiling[4][3];
		for(new x; x < 4; x++)
			INK_TraceUpward(g_vecLandPoints[Client][x], vecCeiling[x]);
		
		g_fLandCeiling[Client] = -999999.0;
		for(new x; x < 4; x++)
		{
			if(g_fLandCeiling[Client] < vecCeiling[x][2])
				g_fLandCeiling[Client] = vecCeiling[x][2];
		}
		
		new Float:fLowX = 999999.0, Float:fHighX = -999999.0, Float:fLowY = 999999.0, Float:fHighY = -999999.0;
		
		// Grab highs/lows:
		for(new Check; Check < 4; Check++)
		{
			if(fLowX > g_vecLandPoints[Client][Check][0])
				fLowX = g_vecLandPoints[Client][Check][0];
			
			if(fHighX < g_vecLandPoints[Client][Check][0])
				fHighX = g_vecLandPoints[Client][Check][0];
			
			if(fLowY > g_vecLandPoints[Client][Check][1])
				fLowY = g_vecLandPoints[Client][Check][1];
			
			if(fHighY < g_vecLandPoints[Client][Check][1])
				fHighY = g_vecLandPoints[Client][Check][1];
		}
		
		// Check for other intercepting lands & players:
		for(new C = 1; C <= MaxClients; C++)
		{
			if(IsClientInGame(C))
			{
				if(g_iLandCreate[C] > 1)
				{
					new Float:fTargetLowX = 999999.0, Float:fTargetHighX = -999999.0, Float:fTargetLowY = 999999.0, Float:fTargetHighY = -999999.0;
					
					for(new Check; Check < 4; Check++)
					{
						if(fTargetLowX > g_vecLandPoints[C][Check][0])
							fTargetLowX = g_vecLandPoints[C][Check][0];
						
						if(fTargetHighX < g_vecLandPoints[C][Check][0])
							fTargetHighX = g_vecLandPoints[C][Check][0];
						
						if(fTargetLowY > g_vecLandPoints[C][Check][1])
							fTargetLowY = g_vecLandPoints[C][Check][1];
						
						if(fTargetHighY < g_vecLandPoints[C][Check][1])
							fTargetHighY = g_vecLandPoints[C][Check][1];
					}
					
					if(fHighX > fTargetLowX && fLowX < fTargetHighX && fHighY > fTargetLowY && fLowY < fTargetHighY)
					{
						if(g_fLandCeiling[Client] + 8 > g_vecLandPoints[C][0][2] - 8 || g_vecLandPoints[Client][0][2] - 8 < g_fLandCeiling[C] + 8)
						{
							INK_Message(Client, "Land intercepting another player's land area.");
							INK_Message(Client, "Do {green}!land #clear{default} to cancel land creation.");
							return Plugin_Handled;
						}
					}
				}
				
				if(C != Client)
				{
					decl Float:vecTargetPos[3];
					GetClientAbsOrigin(C, vecTargetPos);
					
					if(INK_GetLand(vecTargetPos, true) == Client)
					{
						INK_Message(Client, "Land intercepting another player.");
						INK_Message(Client, "Do {green}!land #clear{default} to cancel land creation.");
						return Plugin_Handled;
					}
				}
			}
		}
		
		// Check for intercepting entities:
		new iMaxEnts = GetMaxEntities();
		for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
		{
			if(IsValidEntity(Ent))
			{
				new Owner = INK_GetOwner(Ent);
				if(Owner != Client && Owner > 0)
				{
					decl Float:vecEntPos[3];
					INK_GetEntPos(Ent, vecEntPos);
					
					if(INK_GetLand(vecEntPos, true) == Client)
					{
						INK_EntMessage(Client, "Land intercepting another player's", Ent);
						INK_Message(Client, "Do {green}!land #clear{default} to cancel land creation.");
						return Plugin_Handled;
					}
				}
			}
		}
		
		g_iLandCreate[Client] = 2;
		INK_Message(Client, "Set up land area.");
		
		for(new x; x < 4; x++)
			TeleportEntity(g_eLandCorner[Client][x], g_vecLandPoints[Client][x], NULL_VECTOR, NULL_VECTOR);
	}
	else if(g_iLandCreate[Client] == 2)
	{
		INK_Message(Client, "Already set up land area.");
		INK_Message(Client, "To clear it: Do {green}!land{default} again.");
		
		g_iLandCreate[Client] = 3;
	}
	else if(g_iLandCreate[Client] == 3)
	{
		INK_Message(Client, "Cleared land.");
		
		INK_CreateLandEnts(Client, false);
		
		g_iLandCreate[Client] = 0;
	}
	
	return Plugin_Handled;
}

public Action:Command_SaveBuild(Client, Args)
{
	// Make sure the client has set up their land:
	if(g_iLandCreate[Client] < 2)
	{
		INK_Message(Client, "You must set up your {green}!land{default} area first.");
		return Plugin_Handled;
	}
	
	// These are used multiple times, so I just put 'em here:
	new iMaxEnts = GetMaxEntities();
	new String:sEntName[90], String:sNameArray[2][32], Ent;
	new iEntOut, iEntIn;
	
	// Grab the save name:
	if(!g_bSaving[Client])
	{
		GetCmdArg(1, g_sSaveName[Client], sizeof(g_sSaveName[]));
		
		String_ToLower(g_sSaveName[Client], g_sSaveName[Client], sizeof(g_sSaveName[]));
		StripQuotes(g_sSaveName[Client]);
		TrimString(g_sSaveName[Client]);
		
		if(!INK_ValidString(g_sSaveName[Client]))
		{
			INK_Message(Client, "Build name can only contain letters and numbers.");
			
			strcopy(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
			return Plugin_Handled;
		}
		
		if(StrContains(g_sSaveName[Client], "steam", false) != -1)
		{
			INK_Message(Client, "Build name can not contain the word \"steam\"");
			
			strcopy(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
			return Plugin_Handled;
		}
		
		new bool:bCustomName;
		
		if(!StrEqual(g_sSaveName[Client], ""))
			bCustomName = true;
		
		// Loop through ents to grab save name, etc.
		for(Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
		{
			if(IsValidEntity(Ent))
			{
				if(INK_GetOwner(Ent) == Client)
				{
					decl Float:vecEntPos[3];
					INK_GetEntPos(Ent, vecEntPos);
					if(INK_GetLand(vecEntPos) == Client)
					{
						iEntIn++;
						
						GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
						ExplodeString(sEntName, "^", sNameArray, 2, sizeof(sNameArray[]));
						
						if(!StrEqual(sNameArray[1], ""))
						{
							if(StrEqual(g_sSaveName[Client], ""))
								Format(g_sSaveName[Client], sizeof(g_sSaveName[]), sNameArray[1]);
							
							else if(!StrEqual(sNameArray[1], g_sSaveName[Client], false) && !bCustomName)
							{
								INK_Message(Client, "Multiple builds found within land area.");
								INK_Message(Client, "Specify a build name to save.");
								return Plugin_Handled;
							}
						}
					}
					else iEntOut++;
				}
			}
		}
		
		if(iEntIn < 1)
		{
			INK_Message(Client, "No entities found within land.");
			return Plugin_Handled;
		}
		
		if(StrEqual(g_sSaveName[Client], ""))
		{
			INK_Message(Client, "Specify a build name to save.");
			return Plugin_Handled;
		}
	}
	
	if(Args > 0)
	{
		GetCmdArg(1, g_sSaveName[Client], sizeof(g_sSaveName[]));
		
		String_ToLower(g_sSaveName[Client], g_sSaveName[Client], sizeof(g_sSaveName[]));
		StripQuotes(g_sSaveName[Client]);
		TrimString(g_sSaveName[Client]);
		
		if(!INK_ValidString(g_sSaveName[Client]))
		{
			INK_Message(Client, "Build name can only contain letters and numbers.");
			
			strcopy(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
			return Plugin_Handled;
		}
		
		if(StrContains(g_sSaveName[Client], "steam", false) != -1)
		{
			INK_Message(Client, "Build name can not contain the word \"steam\"");
			
			strcopy(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
			return Plugin_Handled;
		}
	}
	
	// Set up file path:
	decl String:sSavePath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sSavePath, sizeof(sSavePath), "data/ink_build/saves");
	if(!DirExists(sSavePath))
		CreateDirectory(sSavePath, 511);
	
	BuildPath(Path_SM, sSavePath, sizeof(sSavePath), "data/ink_build/saves/%s", g_sClientAuth[Client]);
	if(!DirExists(sSavePath))
		CreateDirectory(sSavePath, 511);
	
	BuildPath(Path_SM, sSavePath, sizeof(sSavePath), "data/ink_build/saves/%s/%s.txt", g_sClientAuth[Client], g_sSaveName[Client]);
	
	// Saving switch:
	if(!g_bSaving[Client])
	{
		if(iEntOut < 1)
			INK_Message(Client, "Saving {green}%d{default} entities to build {green}%s{default}. (All entities are inside land)", iEntIn, g_sSaveName[Client]);
		else if(iEntOut == 1)
			INK_Message(Client, "Saving {green}%d{default} entities to build {green}%s{default}. ({green}1{default} entity is outside land)", iEntIn, g_sSaveName[Client]);
		else INK_Message(Client, "Saving {green}%d{default} entities to build {green}%s{default}. ({green}%d{default} entities are outside land)", iEntIn, g_sSaveName[Client], iEntOut);
		
		INK_Message(Client, "Do {green}!save{default} again to save your build.", g_sSaveName[Client]);
		
		g_bSaving[Client] = true;
		return Plugin_Handled;
	}
	
	// Get land center origin:
	new Float:fLowX = 999999.0, Float:fHighX = -999999.0, Float:fLowY = 999999.0, Float:fHighY = -999999.0;
	
	for(new Check; Check < 4; Check++)
	{
		if(fLowX > g_vecLandPoints[Client][Check][0])
			fLowX = g_vecLandPoints[Client][Check][0];
		
		if(fHighX < g_vecLandPoints[Client][Check][0])
			fHighX = g_vecLandPoints[Client][Check][0];
		
		if(fLowY > g_vecLandPoints[Client][Check][1])
			fLowY = g_vecLandPoints[Client][Check][1];
		
		if(fHighY < g_vecLandPoints[Client][Check][1])
			fHighY = g_vecLandPoints[Client][Check][1];
	}
	
	decl Float:vecLandOrigin[3];
	
	vecLandOrigin[0] = (fLowX + fHighX)/2;
	vecLandOrigin[1] = (fLowY + fHighY)/2;
	vecLandOrigin[2] = g_vecLandPoints[Client][0][2];
	
	// Create file:	
	OpenFile(sSavePath, "w+");
	new Handle:hSaveKv = CreateKeyValues("Build");
	
	for(Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				decl Float:vecEntPos[3];
				INK_GetEntPos(Ent, vecEntPos);
				
				if(INK_GetLand(vecEntPos) == Client)
				{
					decl String:sEntClass[32];
					GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
					
					if(StrContains(sEntClass, "prop_physics", false) == 0
					|| StrContains(sEntClass, "cel_", false) == 0
					|| StrContains(sEntClass, "bit_", false) == 0)
					{
						GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
						ExplodeString(sEntName, "^", sNameArray, 2, sizeof(sNameArray[]));
						
						// Clear entity from existing save:
						if(!StrEqual(sNameArray[1], ""))
						{
							new Handle:hClearKv = CreateKeyValues("Build");
							
							decl String:sClearPath[PLATFORM_MAX_PATH];
							BuildPath(Path_SM, sClearPath, sizeof(sClearPath), "data/ink_build/saves/%s/%s.txt", g_sClientAuth[Client], sNameArray[1]);
							
							FileToKeyValues(hClearKv, sClearPath);
							
							if(KvJumpToKey(hClearKv, sNameArray[0]))
								KvDeleteThis(hClearKv);
							
							KvRewind(hClearKv);
							KeyValuesToFile(hClearKv, sClearPath);
							
							if(!KvGotoFirstSubKey(hClearKv, false))
								DeleteFile(sClearPath);
							
							CloseHandle(hClearKv);
						}
						
						// Store new save info:
						Format(sEntName, sizeof(sEntName), "%d^%s^%s", Ent, g_sSaveName[Client], g_sClientAuth[Client]);
						DispatchKeyValue(Ent, "targetname", sEntName);
						
						// Get ent string and store to keyvalue:
						decl String:sEntString[256];
						INK_EntToString(Ent, sEntString, sizeof(sEntString), vecLandOrigin);
						
						decl String:sKeyName[8];
						IntToString(Ent, sKeyName, sizeof(sKeyName));
						
						KvSetString(hSaveKv, sKeyName, sEntString);
						KvRewind(hSaveKv);
					}
				}
			}
		}
	}
	
	// Save file:
	KeyValuesToFile(hSaveKv, sSavePath);
	CloseHandle(hSaveKv);
	
	INK_Message(Client, "Saved build under name {green}%s{default}.", g_sSaveName[Client]);
	
	Format(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
	g_bSaving[Client] = false;
	
	return Plugin_Handled;
}

public Action:Command_LoadBuild(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!load{default} <save name>");
		return Plugin_Handled;
	}
	
	decl String:sSaveName[32];
	GetCmdArg(1, sSaveName, sizeof(sSaveName));
	String_ToLower(sSaveName, sSaveName, sizeof(sSaveName));
	
	new String:sEntName[90], Ent;
	
	// Check if build has already been loaded:
	new iMaxEnts = GetMaxEntities();
	for(Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
				
				decl String:sNameArray[2][32];
				ExplodeString(sEntName, "^", sNameArray, 2, sizeof(sNameArray[]));
				
				if(StrEqual(sNameArray[1], sSaveName, false))
				{
					INK_Message(Client, "You've already loaded this build.");
					INK_Message(Client, "Do {green}!del %s{default} to remove.", sSaveName);
					
					return Plugin_Handled;
				}
			}
		}
	}
	
	decl String:sSavePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sSavePath, sizeof(sSavePath), "data/ink_build/saves/%s/%s.txt", g_sClientAuth[Client], sSaveName);
	
	if(!FileExists(sSavePath) || !INK_ValidString(sSaveName))
	{
		INK_Message(Client, "Could not find build {green}%s{default}.", sSaveName);
		return Plugin_Handled;
	}
	
	if(!INK_TooFast(Client))
	{
		decl Float:vecAimPos[3];
		INK_AimPosition(Client, vecAimPos);
		vecAimPos[2]++;
		
		new Handle:hLoadKv = CreateKeyValues("Build");
		FileToKeyValues(hLoadKv, sSavePath);
		
		if(!KvGotoFirstSubKey(hLoadKv, false))
		{
			INK_Message(Client, "ERRORORRR1!!!!1!1evlen1");
			CloseHandle(hLoadKv);
			return Plugin_Handled;
		}
		
		do
		{	decl String:sKeyName[8];
			KvGetSectionName(hLoadKv, sKeyName, sizeof(sKeyName));
			
			decl String:sEntString[256];
			KvGetString(hLoadKv, NULL_STRING, sEntString, sizeof(sEntString));
			
			Ent = INK_StringToEnt(sEntString, vecAimPos, true);
			
			if(IsValidEntity(Ent))
			{
				Format(sEntName, sizeof(sEntName), "%s^%s^%s", sKeyName, sSaveName, g_sClientAuth[Client]);
				DispatchKeyValue(Ent, "targetname", sEntName);
				
				if(StrContains(sEntString, "cel_door", false) == -1)
				{
					SetEntityMoveType(Ent, MOVETYPE_NONE);
					AcceptEntityInput(Ent, "disablemotion");
				}
				
				SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
				
				INK_SetOwner(Ent, Client);
			}
		}
		while(KvGotoNextKey(hLoadKv, false));
		
		CloseHandle(hLoadKv);
		
		INK_Message(Client, "Loaded build {green}%s{default}.", sSaveName);
	}
	
	return Plugin_Handled;
}

public Action:Command_StopCopy(Client, Args)
{
	g_bStopCopy[Client] = !g_bStopCopy[Client];
	
	if(g_bStopCopy[Client])
		INK_Message(Client, "Players can no longer copy your entities.");
	else INK_Message(Client, "Players can now copy your entities.");
	
	return Plugin_Handled;
}

public Action:Command_StopFly(Client, Args)
{
	g_bStopFly[Client] = !g_bStopFly[Client];
	
	if(g_bStopFly[Client])
		INK_Message(Client, "Players can no longer fly in your land.");
	else INK_Message(Client, "Players can now fly in your land.");
	
	for(new C = 1; C <= MaxClients; C++)
	{
		if(IsClientInGame(C))
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(C, vecClientPos);
			
			if(INK_GetLand(vecClientPos) == Client)
			{
				if(g_bStopFly[Client] && C != Client)
				{
					if(GetEntityMoveType(C) != MOVETYPE_WALK)
					{
						INK_Message(C, "You are not allowed to fly inside this land.");
						TeleportEntity(C, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
					}
					
					SetEntityMoveType(C, MOVETYPE_WALK);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_PlayerSize(Client, Args)
{
	decl String:Arg1[8];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	
	new iScale = StringToInt(Arg1);
	
	if(iScale < 25) iScale = 25;
	else if(iScale > 200) iScale = 200;
	
	g_iPlayerSize[Client] = iScale;
	
	for(new C = 1; C <= MaxClients; C++)
	{
		if(IsClientInGame(C))
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(C, vecClientPos);
			
			if(INK_GetLand(vecClientPos) == Client)
			{
				if(g_iAppID == 440)
					SetEntPropFloat(C, Prop_Send, "m_flModelScale", 0.9*(float(g_iPlayerSize[Client])/100.0));
				else
					SetEntPropFloat(C, Prop_Send, "m_flModelScale", float(g_iPlayerSize[Client])/100.0);
			}
		}
	}
	
	return Plugin_Handled;
}


public Action:Command_PlayerGrav(Client, Args)
{
	decl String:Arg1[8];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	
	new iGrav = StringToInt(Arg1);
	
	g_iLandGravity[Client] = iGrav;
	
	for(new C = 1; C <= MaxClients; C++)
	{
		if(IsClientInGame(C))
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(C, vecClientPos);
			
			if(INK_GetLand(vecClientPos) == Client)
			{
				if(g_iLandGravity[Client] != 0)
					SetEntityGravity(C, float(g_iLandGravity[Client])/GetConVarInt(sv_gravity));
				else if(Client != 0)
					SetEntityGravity(C, 0.000001);
				else SetEntityGravity(C, 1.0);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_Deathmatch(Client, Args)
{
	g_bDeathmatch[Client] = !g_bDeathmatch[Client];
	
	if(g_bDeathmatch[Client])
		INK_Message(Client, "Enabled deathmatch in your land.");
	else
		INK_Message(Client, "Disabled deathmatch in your land.");
	
	for(new C = 1; C <= MaxClients; C++)
	{
		if(IsClientInGame(C))
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin(C, vecClientPos);
			
			if(INK_GetLand(vecClientPos) == Client)
			{
				if(g_bDeathmatch[Client])
				{
					SetEntityRenderColor(C, 255, 0, 0, 255);
					INK_Message(C, "WARNING: This land has deathmatch enabled.");
				}
				else SetEntityRenderColor(C, 255, 255, 255, 255);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_Landban(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!landban{default} <player>");
		return Plugin_Handled;
	}
	
	decl String:sNewOwner[MAX_NAME_LENGTH];
	GetCmdArg(1, sNewOwner, sizeof(sNewOwner));
	
	new Target = FindTarget(Client, sNewOwner, false, false);
	
	if(Target > 0 && Target != Client)
	{
		g_iBanPlayer[Client] = Target;
		
		decl String:Query[256];
		Format(Query, sizeof(Query), "SELECT * FROM `users_landbans` WHERE `Land` = '%s' AND `Banned` = '%s' LIMIT 0,1", g_sClientAuth[Client], g_sClientAuth[Target]);
		SQL_TQuery(g_hBuildDB, DB_CheckLandban, Query, Client);
	}
	else INK_Message(Client, "Player not found.");
	
	return Plugin_Handled;
}

public Action:Command_Landunban(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!landunban{default} <player>");
		return Plugin_Handled;
	}
	
	decl String:sNewOwner[MAX_NAME_LENGTH];
	GetCmdArg(1, sNewOwner, sizeof(sNewOwner));
	
	new Target = FindTarget(Client, sNewOwner, false, false);
	
	if(Target > 0 && Target != Client)
	{
		g_iBanPlayer[Client] = Target;
		
		decl String:Query[256];
		Format(Query, sizeof(Query), "SELECT * FROM `users_landbans` WHERE `Land` = '%s' AND `Banned` = '%s' LIMIT 0,1", g_sClientAuth[Client], g_sClientAuth[Target]);
		SQL_TQuery(g_hBuildDB, DB_CheckLandunban, Query, Client);
	}
	else INK_Message(Client, "Player not found.");
	
	return Plugin_Handled;
}

// ENT SPAWN COMMANDS:

public Action:Command_SpawnProp(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!spawn{default} <prop alias>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "prop_physics_overide"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[128];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl String:sPropString[128];
		
		// Attempt to match a model to the given prop alias:
		new Handle:hPropHandle = CreateKeyValues("Props");
		FileToKeyValues(hPropHandle, PropPath);
		KvGetString(hPropHandle, Arg1, sPropString, sizeof(sPropString), "Null");
		
		// If no model was found:
		if(StrContains(sPropString, "Null", false) != -1)
		{
			// Attempt to correct:
			if(StrContains(Arg1, "1", false) != -1)
				ReplaceString(Arg1, sizeof(Arg1), "1", "");
			
			else
				Format(Arg1, sizeof(Arg1), "%s1", Arg1);
			
			KvGetString(hPropHandle, Arg1, sPropString, sizeof(sPropString), "Null");
			
			// If no model was found, cancel:
			if(StrContains(sPropString, "Null", false) != -1)
			{
				INK_Message(Client, "Prop not found.", Arg1);
				
				CloseHandle(hPropHandle);
				return Plugin_Handled;
			}
		}
		
		CloseHandle(hPropHandle);
		
		decl String:sPropBuffer[3][128];
		ExplodeString(sPropString, "^", sPropBuffer, 3, sizeof(sPropBuffer[]));
		
		// Found a model, but discontinued (not spawnable by regular players):
		if(StringToInt(sPropBuffer[2]) == 1)
		{
			INK_Message(Client, "This prop has been discontinued.", Arg1);
			return Plugin_Handled;
		}
		
		decl Ent;
		
		if(StringToInt(sPropBuffer[1]) == 1)
			Ent = CreateEntityByName("cycler");
		else Ent = CreateEntityByName("prop_physics_override");
		
		// Precache and apply model to prop:
		PrecacheModel(sPropBuffer[0]);
		DispatchKeyValue(Ent, "model", sPropBuffer[0]);
		
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		
		// Calculate spawn origin:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		if(StringToInt(sPropBuffer[1]) == 1)
			vecSpawnOrigin[2] = vecClientOrigin[2];
		else vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport entity to calculated position:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		if(!DispatchSpawn(Ent))
		{
			// There was an error, notify player and cancel spawn:
			INK_Message(Client, "Error spawning prop.");
			AcceptEntityInput(Ent, "Kill");
			return Plugin_Handled;
		}
		// If doll, hook damage:
		if(StringToInt(sPropBuffer[1]) == 1)
		{
			DispatchKeyValue(Ent, "classname", "cel_doll");
			
			SDKHook(Ent, SDKHook_OnTakeDamage, DollTakeDamage);
			Entity_AddSpawnFlags(Ent, 256);
		} 
		// If prop, freeze and god:
		else
		{
			SetEntityMoveType(Ent, MOVETYPE_NONE);
			AcceptEntityInput(Ent, "disablemotion");
			
			SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
			
			if(StringToInt(sPropBuffer[1]) == 2)
				DispatchKeyValue(Ent, "solid", "4");
		}
		
		ActivateEntity(Ent);
		
		// Set up ownership and target:
		DispatchKeyValue(Ent, "target", Arg1);
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_CopymoveEnt(Client, Args)
{
	if(g_eGrabEnt[Client] != 0)
	{
		INK_Message(Client, "You're already moving something.");
		return Plugin_Handled;
	}
	
	if(g_eCopyEnt[Client] == 0)
	{
		decl String:sCmdName[8];
		GetCmdArg(0, sCmdName, sizeof(sCmdName));
		
		if(StrEqual(sCmdName, "-copy", false))
			return Plugin_Handled;
		
		new Ent = INK_AimTarget(Client);
		
		if(Ent == -1)
		{
			INK_NoTarget(Client);
			return Plugin_Handled;
		}
		
		new Owner = INK_GetOwner(Ent);
		if(Owner != Client && g_bStopCopy[Owner])
		{
			INK_Message(Client, "The owner of this entity has disable copying.");
			return Plugin_Handled;
		}
		
		if(!INK_TooFast(Client))
		{
			decl String:sEntClass[32];
			GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
			
			if(StrContains(sEntClass, "prop_physics", false) == 0
			||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_teleport", false)
			&& !StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false) && !StrEqual(sEntClass, "cel_link", false))
			||(StrContains(sEntClass, "bit_", false) == 0))
			{
				// Origin relative to client:
				decl Float:vecClientPos[3], Float:vecEntPos[3];
				GetClientAbsOrigin(Client, vecClientPos);
				INK_GetEntPos(Ent, vecEntPos);
				
				SubtractVectors(vecClientPos, vecEntPos, g_vecGrabPos[Client]);
				
				// Color:
				new iColorOffset = GetEntSendPropOffs(Ent, "m_clrRender");
				g_iGrabColor[Client][0] = GetEntData(Ent, iColorOffset, 1);
				g_iGrabColor[Client][1] = GetEntData(Ent, iColorOffset + 1, 1);
				g_iGrabColor[Client][2] = GetEntData(Ent, iColorOffset + 2, 1);
				g_iGrabColor[Client][3] = GetEntData(Ent, iColorOffset + 3, 1);
				
				// Make Copy:
				decl String:sEntString[256];
				INK_EntToString(Ent, sEntString, sizeof(sEntString));
				
				if(INK_CheckLimit(Client, sEntString))
					return Plugin_Handled;
				
				new EntCopy = INK_StringToEnt(sEntString);
				
				if(StrContains(sEntString, "cel_door", false) == -1)
				{
					SetEntityMoveType(EntCopy, MOVETYPE_NONE);
					AcceptEntityInput(EntCopy, "disablemotion");
				}
				
				SetEntProp(EntCopy, Prop_Data, "m_takedamage", 0, 1);
				
				// Give ownership to client:
				INK_SetOwner(EntCopy, Client);
				
				// Set up grab:
				SetEntProp(EntCopy, Prop_Send, "m_nRenderMode", 1, 1);
				SetEntityRenderColor(EntCopy, 0, 0, 255, 192);
				
				g_eCopyEnt[Client] = EntCopy;
				
				// Spawn effect:
				INK_SpawnEffect(EntCopy);
			}
			else INK_Message(Client, "You cannot copy this entity.");
		}
	}
	else
	{
		if(IsValidEntity(g_eCopyEnt[Client]))
		{
			SetEntityRenderColor(g_eCopyEnt[Client], g_iGrabColor[Client][0], g_iGrabColor[Client][1], g_iGrabColor[Client][2], g_iGrabColor[Client][3]);
			
			TeleportEntity(g_eCopyEnt[Client], NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
		}
		
		g_eCopyEnt[Client] = 0;
	}
	
	return Plugin_Handled;
}

public Action:Command_CopyEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	new Owner = INK_GetOwner(Ent);
	if(Owner != Client && g_bStopCopy[Owner])
	{
		INK_Message(Client, "The owner of this entity has disable copying.");
		return Plugin_Handled;
	}
	
	decl String:sEntClass[32];
	GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
	
	if(StrContains(sEntClass, "prop_physics", false) == 0
	||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_teleport", false)
	&& !StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false) && !StrEqual(sEntClass, "cel_link", false))
	||(StrContains(sEntClass, "bit_", false) == 0))
	{
		INK_EntToString(Ent, g_sCopyBuffer[Client], sizeof(g_sCopyBuffer[]));
		INK_EntMessage(Client, "Set", Ent, "to copy queue. Now do {green}!paste{default} to make a copy");
	}
	else INK_Message(Client, "You cannot copy this entity.");
	
	return Plugin_Handled;
}

public Action:Command_PasteEnt(Client, Args)
{
	if(StrEqual(g_sCopyBuffer[Client], ""))
	{
		INK_Message(Client, "No entity found in copy queue.");
		return Plugin_Handled;
	}
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Check entity limits:
		if(INK_CheckLimit(Client, g_sCopyBuffer[Client]))
			return Plugin_Handled;
		
		new Ent = INK_StringToEnt(g_sCopyBuffer[Client]);
		
		if(StrContains(g_sCopyBuffer[Client], "cel_door", false) == -1)
		{
			SetEntityMoveType(Ent, MOVETYPE_NONE);
			AcceptEntityInput(Ent, "disablemotion");
		}
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		decl Float:vecAimPos[3];
		INK_AimPosition(Client, vecAimPos);
		TeleportEntity(Ent, vecAimPos, NULL_VECTOR, NULL_VECTOR);
		
		INK_SetOwner(Ent, Client);
		INK_ChangeBeam(Client);
		
		INK_EntMessage(Client, "Pasted", Ent) ;
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_UndoRemove(Client, Args)
{
	if(!INK_TooFast(Client))
	{
		for(new i = 255; i >= 0; i--)
		{
			if(!StrEqual(g_sUndoQueue[Client][i], ""))
			{
				// Check entity limits:
				if(INK_CheckLimit(Client, g_sUndoQueue[Client][i]))
					return Plugin_Handled;
				
				// Copy:
				new Ent = INK_StringToEnt(g_sUndoQueue[Client][i]);
				
				if(StrContains(g_sUndoQueue[Client][i], "cel_door", false) == -1)
				{
					SetEntityMoveType(Ent, MOVETYPE_NONE);
					AcceptEntityInput(Ent, "disablemotion");
				}
				
				SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
				
				// Detect error, set owner:
				if(IsValidEntity(Ent))
				{
					INK_SetOwner(Ent, g_iUndoOwner[Client][i]);
					INK_EntMessage(Client, "Restored", Ent);
				}
				else INK_Message(Client, "Too late -- It's gone!");
				
				// Clear:
				strcopy(g_sUndoQueue[Client][i], sizeof(g_sUndoQueue[][]), "");
				g_iUndoOwner[Client][i] = 0;
				
				// Spawn effect:
				INK_SpawnEffect(Ent);
				
				return Plugin_Handled;
			}
		}
		
		INK_Message(Client, "Nothing in undo queue.");
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnLight(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_light"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/roller_spikes.mdl");
		DispatchKeyValue(Ent, "model", "models/roller_spikes.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "rendermode", "1");
		DispatchKeyValue(Ent, "renderamt", "64");
		DispatchSpawn(Ent);
		
		// Spawn light:
		new EntLight = CreateEntityByName("light_dynamic");
		
		DispatchKeyValue(EntLight, "inner_cone", "300");
		DispatchKeyValue(EntLight, "cone", "500");
		DispatchKeyValue(EntLight, "spotlight_radius", "500");
		DispatchKeyValue(EntLight, "brightness", "0.5");
		
		if(Args > 0)
		{
			decl String:Arg1[8];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			
			// Distance:
			if(StringToInt(Arg1) > 1000)
				DispatchKeyValue(EntLight, "distance", "1000");
			else DispatchKeyValue(EntLight, "distance", Arg1);
			
			decl String:Arg2[4];
			GetCmdArg(2, Arg2, sizeof(Arg2));
			
			// Style:
			DispatchKeyValue(EntLight, "style", Arg2);
		}
		else DispatchKeyValue(EntLight, "distance", "500");
		
		DispatchSpawn(EntLight);
		DispatchKeyValue(Ent, "classname", "cel_light");
		
		AcceptEntityInput(Ent, "disableshadow");
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport & weld:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		Entity_SetParent(EntLight, Ent);
		TeleportEntity(EntLight, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);
		
		// Freeze:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnDoor(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_door"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:sSkin[4];
		GetCmdArg(1, sSkin, sizeof(sSkin));
		
		decl String:sHardware[4];
		GetCmdArg(2, sHardware, sizeof(sSkin));
		
		new Ent = CreateEntityByName("prop_door_rotating");
		
		PrecacheModel("models/props_c17/door01_left.mdl");
		DispatchKeyValue(Ent, "model", "models/props_c17/door01_left.mdl");
		
		// Misc properties:
		DispatchKeyValue(Ent, "spawnflags", "8192");
		DispatchKeyValue(Ent, "distance", "90");
		DispatchKeyValue(Ent, "speed", "100");
		DispatchKeyValue(Ent, "dmg", "20");
		DispatchKeyValue(Ent, "opendir", "0");
		
		DispatchKeyValue(Ent, "returndelay", "-1");
		DispatchKeyValue(Ent, "forceclosed", "1");
		DispatchKeyValue(Ent, "OnFullyOpen", "!caller,close,,3,-1");
		
		// Skin:
		DispatchKeyValue(Ent, "skin", sSkin);
		
		// Hardware:
		if(StringToInt(sHardware) == 1)
			DispatchKeyValue(Ent, "hardware", "2");
		else DispatchKeyValue(Ent, "hardware", "1");
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 54;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Set up door angles:
		decl String:sAngles[16];
		Format(sAngles, sizeof(sAngles), "%f %f %f", vecSpawnAng[0], vecSpawnAng[1], vecSpawnAng[2]); 
		
		// Teleport:
		DispatchKeyValue(Ent, "angles", sAngles);
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		// Spawn:
		DispatchSpawn(Ent);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		DispatchKeyValue(Ent, "classname", "cel_door");
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnLadder(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_ladder"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		// Model:
		decl String:sType[4];
		GetCmdArg(1, sType, sizeof(sType));
		
		if(StrEqual(sType, "2", false))
		{
			PrecacheModel("models/props_c17/metalladder002.mdl");
			DispatchKeyValue(Ent, "model", "models/props_c17/metalladder002.mdl");
		}
		else 
		{
			PrecacheModel("models/props_c17/metalladder001.mdl");
			DispatchKeyValue(Ent, "model", "models/props_c17/metalladder001.mdl");
		}
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchSpawn(Ent);
		
		// Spawn ladder:
		new EntLadder = CreateEntityByName("func_useableladder");
		
		DispatchKeyValue(EntLadder, "point0", "30 0 0");
		DispatchKeyValue(EntLadder, "point1", "30 0 128");
		DispatchKeyValue(EntLadder, "StartDisabled", "0");
		
		DispatchSpawn(EntLadder);
		DispatchKeyValue(Ent, "classname", "cel_ladder");
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2];
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport & weld:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		Entity_SetParent(EntLadder, Ent);
		TeleportEntity(EntLadder, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);
		
		// Freeze:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnInternet(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_internet"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_lab/monitor02.mdl");
		DispatchKeyValue(Ent, "model", "models/props_lab/monitor02.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "classname", "cel_internet");
		
		DispatchSpawn(Ent);
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnSound(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!sound{default} <sound name>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "cel_sound"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl String:sSoundString[128];
		
		// Attempt to match a sound to the given alias:
		new Handle:hSoundKv = CreateKeyValues("Sounds");
		FileToKeyValues(hSoundKv, SoundPath);
		KvGetString(hSoundKv, Arg1, sSoundString, sizeof(sSoundString), "Null");
		
		// If no sound was found:
		if(StrContains(sSoundString, "Null", false) != -1)
		{
			// Attempt to correct:
			if(StrContains(Arg1, "1", false) != -1)
			{
				ReplaceString(Arg1, sizeof(Arg1), "1", "");
				KvGetString(hSoundKv, Arg1, sSoundString, sizeof(sSoundString), "Null");
				
				// If no sound was found, cancel:
				if(StrContains(sSoundString, "Null", false) != -1)
				{
					INK_Message(Client, "Sound not found.");
					
					CloseHandle(hSoundKv);
					return Plugin_Handled;
				}
			}
			else
			{
				Format(Arg1, sizeof(Arg1), "%s1", Arg1);
				KvGetString(hSoundKv, Arg1, sSoundString, sizeof(sSoundString), "Null");
				
				// If no sound was found, cancel:
				if(StrContains(sSoundString, "Null", false) != -1)
				{
					INK_Message(Client, "Sound not found.");
					
					CloseHandle(hSoundKv);
					return Plugin_Handled;
				}
			}
		}
		CloseHandle(hSoundKv);
		
		// Sound speed:
		decl String:Arg2[8];
		GetCmdArg(2, Arg2, sizeof(Arg2));
		new iSpeed = StringToInt(Arg2);
		
		if(iSpeed == 0) iSpeed = 100;
		else if(iSpeed < 10) iSpeed = 10;
		else if(iSpeed > 255) iSpeed = 255;
		
		Format(sSoundString, sizeof(sSoundString), "%s^%d", sSoundString, iSpeed);
		
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_junk/popcan01a.mdl");
		DispatchKeyValue(Ent, "model", "models/props_junk/popcan01a.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "skin", "1");
		DispatchKeyValue(Ent, "rendercolor", "255 200 0");
		DispatchKeyValue(Ent, "classname", "cel_sound");
		
		DispatchSpawn(Ent);
		
		// Set up sound:
		DispatchKeyValue(Ent, "target", sSoundString);
		g_fUseTime[Ent] = GetGameTime();
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnMusic(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!music{default} <song name>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "cel_music"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl String:sMusicString[192];
		
		// Attempt to match a sound to the given alias:
		new Handle:hMusicKv = CreateKeyValues("Music");
		FileToKeyValues(hMusicKv, MusicPath);
		KvGetString(hMusicKv, Arg1, sMusicString, sizeof(sMusicString), "Null");
		
		// If no sound was found:
		if(StrContains(sMusicString, "Null", false) != -1)
		{
			// Attempt to correct:
			if(StrContains(Arg1, "1", false) != -1)
			{
				ReplaceString(Arg1, sizeof(Arg1), "1", "");
				KvGetString(hMusicKv, Arg1, sMusicString, sizeof(sMusicString), "Null");
				
				// If no sound was found, cancel:
				if(StrContains(sMusicString, "Null", false) != -1)
				{
					INK_Message(Client, "Sound not found.");
					
					CloseHandle(hMusicKv);
					return Plugin_Handled;
				}
			}
			else
			{
				Format(Arg1, sizeof(Arg1), "%s1", Arg1);
				KvGetString(hMusicKv, Arg1, sMusicString, sizeof(sMusicString), "Null");
				
				// If no sound was found, cancel:
				if(StrContains(sMusicString, "Null", false) != -1)
				{
					INK_Message(Client, "Sound not found.");
					
					CloseHandle(hMusicKv);
					return Plugin_Handled;
				}
			}
		}
		CloseHandle(hMusicKv);
		
		// Music volume:
		decl String:Arg2[8];
		GetCmdArg(2, Arg2, sizeof(Arg2));
		new iVolume = StringToInt(Arg2);
		
		if(iVolume == 0) iVolume = 100;
		else if(iVolume < 40) iVolume = 40;
		else if(iVolume > 100) iVolume = 100;
		
		new Float:fVolume = float(iVolume)/100;
		
		// Loop:
		decl String:Arg3[8];
		GetCmdArg(3, Arg3, sizeof(Arg3));
		new iLoop = StringToInt(Arg3);
		
		if(iLoop < 0) iLoop = 0;
		if(iLoop > 1) iLoop = 1;
		
		// Music speed:
		decl String:Arg4[8];
		GetCmdArg(4, Arg4, sizeof(Arg4));
		new iSpeed = StringToInt(Arg4);
		
		if(iSpeed == 0) iSpeed = 100;
		else if(iSpeed < 10) iSpeed = 10;
		else if(iSpeed > 255) iSpeed = 255;
		
		// Music length:
		decl String:sMusicBreak[2][128], String:sSeconds[2][8];
		
		ExplodeString(sMusicString, "|", sMusicBreak, 2, sizeof(sMusicBreak[]));
		ExplodeString(sMusicBreak[1], ":", sSeconds, 2, sizeof(sSeconds[]));
		
		new iSeconds = StringToInt(sSeconds[0]) * 60;
		iSeconds = StringToInt(sSeconds[1]) + iSeconds;
		
		iSeconds = RoundFloat(iSeconds/(float(iSpeed)/100));
		
		// Combine:
		Format(sMusicString, sizeof(sMusicString), "%s^%d^%f^%d^%d", sMusicBreak[0], iSeconds, fVolume, iLoop, iSpeed);
		
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_lab/citizenradio.mdl");
		DispatchKeyValue(Ent, "model", "models/props_lab/citizenradio.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "skin", "1");
		DispatchKeyValue(Ent, "rendercolor", "128 255 0");
		DispatchKeyValue(Ent, "classname", "cel_music");
		
		DispatchSpawn(Ent);
		
		// Set up music:
		DispatchKeyValue(Ent, "target", sMusicString);
		g_fUseTime[Ent] = 0.0;
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnFire(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_fire"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_junk/wood_crate001a.mdl");
		DispatchKeyValue(Ent, "model", "models/props_junk/wood_crate001a.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchKeyValue(Ent, "rendermode", "1");
		DispatchKeyValue(Ent, "renderamt", "0");
		DispatchKeyValue(Ent, "classname", "cel_fire");
		
		DispatchSpawn(Ent);
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Ignite:
		new EntIgnite = CreateEntityByName("env_entity_igniter");
		DispatchKeyValue(EntIgnite, "target", "ignited");
		DispatchSpawn(EntIgnite);
		
		DispatchKeyValue(Ent, "targetname", "ignited");
		DispatchKeyValue(EntIgnite, "lifetime", "100000");
		AcceptEntityInput(EntIgnite, "ignite");
		
		DispatchKeyValue(Ent, "targetname", "");
		AcceptEntityInput(EntIgnite, "Kill");
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnTeleport(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_teleport"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_lab/teleplatform.mdl");
		DispatchKeyValue(Ent, "model", "models/props_lab/teleplatform.mdl");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "classname", "cel_teleport");
		
		DispatchSpawn(Ent);
		
		g_fUseTime[Ent] = 0.0;
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		vecEyeAng[0] = 0.0;
		vecEyeAng[2] = 0.0;
		
		// Teleport:
		vecClientOrigin[2] += 6;
		TeleportEntity(Ent, vecClientOrigin, vecEyeAng, ZERO_VECTOR);
		
		vecClientOrigin[2] += 16;
		TeleportEntity(Client, vecClientOrigin, NULL_VECTOR, NULL_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		if(!IsValidEntity(g_eTeleEnt[Client]) || g_eTeleEnt[Client] == 0)
		{
			INK_Message(Client, "Created teleport cel.");
			g_eTeleEnt[Client] = Ent;
		}
		else
		{
			INK_Message(Client, "Created destination teleport.");
			
			decl String:sStartTarget[8], String:sDestTarget[8];
			IntToString(Ent, sStartTarget, sizeof(sStartTarget));
			IntToString(g_eTeleEnt[Client], sDestTarget, sizeof(sDestTarget));
			
			DispatchKeyValue(g_eTeleEnt[Client], "target", sStartTarget);
			DispatchKeyValue(Ent, "target", sDestTarget);
			
			g_eTeleEnt[Client] = 0;
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnButton(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_button"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_combine/combinebutton.mdl");
		DispatchKeyValue(Ent, "model", "models/props_combine/combinebutton.mdl");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "classname", "cel_button");
		DispatchKeyValue(Ent, "target", "0^0^0^0^0^0");
		
		DispatchSpawn(Ent);
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnTrigger(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_trigger"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_pipes/pipe02_connector01.mdl");
		DispatchKeyValue(Ent, "model", "models/props_pipes/pipe02_connector01.mdl");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "classname", "cel_trigger");
		DispatchKeyValue(Ent, "target", "0^0^0^0^0^0");
		
		DispatchSpawn(Ent);
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2];
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		vecSpawnAng[0] = -90.0;
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		// Trigger:
		SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
	}
	
	return Plugin_Handled;
}

public Action:Command_SkyBox(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!skybox{default} <option>");
		return Plugin_Handled;
	}
	
	new Ent = Entity_FindByName("Sky_Sphere", "prop_dynamic");
	
	if(Ent == -1)
	{
		INK_Message(Client, "This map doesn't support a dynamic skybox.");
		return Plugin_Handled;
	}
	
	decl String:Arg1[16];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	
	if(StrEqual(Arg1, "skin", false))
	{
		decl String:sSkin[8];
		GetCmdArg(2, sSkin, sizeof(sSkin));
		
		SetEntProp(Ent, Prop_Send, "m_nSkin", StringToInt(sSkin));
	}
	else if(StrEqual(Arg1, "color", false))
	{
		decl String:sRed[8], String:sGreen[8], String:sBlue[8], String:sAlpha[8];
		GetCmdArg(2, sRed, sizeof(sRed));
		GetCmdArg(3, sGreen, sizeof(sGreen));
		GetCmdArg(4, sBlue, sizeof(sBlue));
		GetCmdArg(5, sAlpha, sizeof(sAlpha));
		
		SetEntityRenderColor(Ent, StringToInt(sRed), StringToInt(sGreen), StringToInt(sBlue), StringToInt(sAlpha));
	}
	else if(StrEqual(Arg1, "render", false))
	{
		decl String:sRender[8];
		GetCmdArg(2, sRender, sizeof(sRender));
		
		SetEntityRenderFx(Ent, RenderFx:StringToInt(sRender));
	}
	
	return Plugin_Handled;
}

public Action:Command_ScaleEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[64];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) != -1)
		{
			decl String:Arg1[16];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			
			new Float:fScale = StringToFloat(Arg1);
			SetEntPropFloat(Ent, Prop_Data, "m_flModelScale", fScale);
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_ActivateEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	INK_ActivateEnt(Client, Ent);
	
	return Plugin_Handled;
}

public Action:Command_DelObjective(Client, args)
{
	new Ent = FindEntityByClassname(-1, "team_control_point_master");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
		{
			DispatchKeyValue(Ent, "caplayout", "");
			INK_RemoveEnt(Ent, false);
		}
		
		Ent = FindEntityByClassname(Ent, "team_control_point_master");
	}
	
	Ent = FindEntityByClassname(-1, "team_control_point_round");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
			INK_RemoveEnt(Ent, false);
		
		Ent = FindEntityByClassname(Ent, "team_control_point_round");
	}
	
	Ent = FindEntityByClassname(-1, "team_control_point");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
			INK_RemoveEnt(Ent, false);
		
		Ent = FindEntityByClassname(Ent, "team_control_point");
	}
	
	Ent = FindEntityByClassname(-1, "trigger_capture_area");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
			INK_RemoveEnt(Ent, false);
		
		Ent = FindEntityByClassname(Ent, "trigger_capture_area");
	}
	
	Ent = FindEntityByClassname(-1, "prop_dynamic");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
		{
			decl String:sEntModel[128];
			GetEntPropString(Ent, Prop_Data, "m_ModelName", sEntModel, sizeof(sEntModel));
			
			if(StrEqual(sEntModel, "models/props_gameplay/cap_point_base.mdl", false))
				INK_RemoveEnt(Ent, false);
		}
		
		Ent = FindEntityByClassname(Ent, "prop_dynamic");
	}
	
	Ent = FindEntityByClassname(-1, "tf_gamerules");
	while(Ent != -1)
	{
		if(IsValidEntity(Ent))
			INK_RemoveEnt(Ent, false);
		
		Ent = FindEntityByClassname(Ent, "tf_gamerules");
	}
}

public Action:Command_SpawnCamera(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_camera"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/tools/camera/camera.mdl");
		DispatchKeyValue(Ent, "model", "models/tools/camera/camera.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		
		DispatchKeyValue(Ent, "classname", "cel_camera");
		DispatchSpawn(Ent);
		
		// Spawn view controller:
		new EntView = CreateEntityByName("point_viewcontrol");
		DispatchKeyValue(EntView, "spawnflags", "64");
		DispatchSpawn(EntView);
		
		DispatchKeyValue(Ent, "solid", "4");
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport & weld:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		Entity_SetParent(EntView, Ent);
		TeleportEntity(EntView, Float:{2.5, 0.0, 0.0}, ZERO_VECTOR, ZERO_VECTOR);
		
		// Freeze:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnWeapon(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!wep{default} <weapon name>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "bit_weapon"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl String:sWeaponString[128];
		
		new Handle:hWeaponsKv = CreateKeyValues("Weapons");
		FileToKeyValues(hWeaponsKv, WeaponPath);
		KvGetString(hWeaponsKv, Arg1, sWeaponString, sizeof(sWeaponString), "Null");
		CloseHandle(hWeaponsKv);
		
		if(StrContains(sWeaponString, "Null", false) != -1)
		{
			INK_Message(Client, "Weapon not found.");
			return Plugin_Handled;
		}
		
		new Ent = CreateEntityByName("prop_physics_override");
		
		decl String:sWepArray[2][64];
		ExplodeString(sWeaponString, "^", sWepArray, 2, sizeof(sWepArray[]));
		
		// Precache and apply model to prop:
		PrecacheModel(sWepArray[1]);
		DispatchKeyValue(Ent, "model", sWepArray[1]);
		
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "classname", "bit_weapon");
		
		DispatchKeyValue(Ent, "target", sWepArray[0]);
		
		// Calculate spawn origin:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport entity to calculated position:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		DispatchSpawn(Ent);
		
		SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Set up ownership and target:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		INK_Message(Client, "Created {green}%s{default} weapon spawner.", Arg1);
		INK_Message(Client, "To enable, you must {green}!unlock{default} it.");
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnAmmo(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!ammo{default} <weapon name>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "bit_ammo"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl String:sWeaponString[128];
		
		new Handle:hWeaponsKv = CreateKeyValues("Weapons");
		FileToKeyValues(hWeaponsKv, WeaponPath);
		KvGetString(hWeaponsKv, Arg1, sWeaponString, sizeof(sWeaponString), "Null");
		CloseHandle(hWeaponsKv);
		
		if(StrContains(sWeaponString, "Null", false) != -1)
		{
			INK_Message(Client, "Weapon not found.");
			return Plugin_Handled;
		}
		
		new Ent = CreateEntityByName("prop_physics_override");
		
		decl String:sWepArray[3][64];
		ExplodeString(sWeaponString, "^", sWepArray, 3, sizeof(sWepArray[]));
		
		if(StrContains(sWepArray[2], "models", false) == -1)
		{
			INK_Message(Client, "No ammo available for this weapon.");
			return Plugin_Handled;
		}
		
		// Precache and apply model to prop:
		PrecacheModel(sWepArray[2]);
		DispatchKeyValue(Ent, "model", sWepArray[2]);
		
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "classname", "bit_ammo");
		
		DispatchKeyValue(Ent, "target", sWepArray[0]);
		
		// Calculate spawn origin:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport entity to calculated position:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		DispatchSpawn(Ent);
		
		SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Set up ownership and target:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		INK_Message(Client, "Created {green}%s{default} ammo spawner.", Arg1);
		INK_Message(Client, "To enable, you must {green}!unlock{default} it.");
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnAmmocrate(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!ammocrate{default} <smg | ar2 | rpg | grenade | cball>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "bit_ammocrate"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		new Ent = CreateEntityByName("item_ammo_crate");
		
		// Precache and apply model to prop:
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "classname", "bit_ammocrate");
		
		if(StrEqual(Arg1, "smg", false))
		{
			DispatchKeyValue(Ent, "AmmoType", "1");
			DispatchKeyValue(Ent, "target", "1");
		}
		else if(StrEqual(Arg1, "ar2", false))
		{
			DispatchKeyValue(Ent, "AmmoType", "2");
			DispatchKeyValue(Ent, "target", "2");
		}
		else if(StrEqual(Arg1, "rpg", false))
		{
			DispatchKeyValue(Ent, "AmmoType", "3");
			DispatchKeyValue(Ent, "target", "3");
		}
		else if(StrEqual(Arg1, "grenade", false))
		{
			DispatchKeyValue(Ent, "AmmoType", "5");
			DispatchKeyValue(Ent, "target", "5");
		}
		else if(StrEqual(Arg1, "cball", false))
		{
			DispatchKeyValue(Ent, "AmmoType", "8");
			DispatchKeyValue(Ent, "target", "8");
		}
		
		// Calculate spawn origin:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 16;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport entity to calculated position:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		DispatchSpawn(Ent);
		
		SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Set up ownership and target:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		INK_Message(Client, "Created {green}%s{default} ammocrate.", Arg1);
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnCharger(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!charger{default} <health | suit>");
		return Plugin_Handled;
	}
	
	if(INK_CheckLimit(Client, "bit_charger"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		decl String:Arg1[32];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		String_ToLower(Arg1, Arg1, sizeof(Arg1));
		
		decl Ent;
		
		if(StrEqual(Arg1, "health", false))
			Ent = CreateEntityByName("item_healthcharger");
		else if(StrEqual(Arg1, "suit", false))
			Ent = CreateEntityByName("item_suitcharger");
		
		else
		{
			INK_Message(Client, "Usage: {green}!charger{default} <health | suit>");
			return Plugin_Handled;
		}
		
		// Precache and apply model to prop:
		DispatchKeyValue(Ent, "physdamagescale", "1.0");
		DispatchKeyValue(Ent, "classname", "bit_charger");
		DispatchKeyValue(Ent, "target", Arg1);
		
		// Calculate spawn origin:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 48;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1] + 180;
		
		// Teleport entity to calculated position:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, NULL_VECTOR);
		
		DispatchSpawn(Ent);
		
		SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Set up ownership and target:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
		
		INK_Message(Client, "Created {green}%s{default} charger.", Arg1);
	}
	
	return Plugin_Handled;
}

public Action:Command_CustomEnt(Client, Args)
{
	decl String:Arg1[32], String:Arg2[128], String:Arg3[128], String:Arg4[128], String:Arg5[128], String:Arg6[128];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	
	if(StrEqual(Arg1, "create", false))
	{
		if(Args < 2)
		{
			INK_Message(Client, "Usage: {green}!ent create{default} <classname>");
			return Plugin_Handled;
		}
		
		GetCmdArg(2, Arg2, sizeof(Arg2));
		new Ent = CreateEntityByName(Arg2);
		
		if(Ent < 0)
		{
			INK_Message(Client, "Error: \"{green}%s{default}\" returned invalid classname. No entity has been created.", Arg2);
			return Plugin_Handled;
		}
		
		g_eCustomEnt[Client] = Ent;
		
		INK_Message(Client, "Created and selected entity {green}%d{default} with classname \"%s\".", g_eCustomEnt[Client], Arg2);
		return Plugin_Handled;
	}
	
	if(StrEqual(Arg1, "select", false))
	{
		if(Args < 2)
		{
			INK_Message(Client, "Usage: {green}!ent select{default} <entity index OR !picker>");
			return Plugin_Handled;
		}
		
		decl Ent;
		
		GetCmdArg(2, Arg2, sizeof(Arg2));
		if(StrEqual(Arg2, "!picker", false))
		{
			Ent = INK_AimTarget(Client);
		}
		else if(StrContains(Arg2, "0", false) != 0)
		{
			Ent = FindEntityByClassname(-1, Arg2);
		}
		else Ent = StringToInt(Arg2);
		
		if(!IsValidEntity(Ent))
		{
			INK_Message(Client, "Error: {green}%d{default} returned invalid entity. No entity has been selected.", Ent);
			return Plugin_Handled;
		}
		
		g_eCustomEnt[Client] = Ent;
		
		decl String:sEntClass[64];
		GetEntityClassname(g_eCustomEnt[Client], sEntClass, sizeof(sEntClass));
		
		INK_Message(Client, "Selected existing entity {green}%d{default} with classname \"%s\".", g_eCustomEnt[Client], sEntClass);
		return Plugin_Handled;
	}
	
	if(!IsValidEntity(g_eCustomEnt[Client]) || g_eCustomEnt[Client] == 0)
	{
		INK_Message(Client, "Error: No entity is currently selected.");
		return Plugin_Handled;
	}
	else
	{
		decl String:sEntClass[64];
		GetEntityClassname(g_eCustomEnt[Client], sEntClass, sizeof(sEntClass));
		
		if(StrEqual(Arg1, "spawn", false))
		{
			DispatchSpawn(g_eCustomEnt[Client]);
			INK_Message(Client, "Dispatched spawn on entity {green}%d{default} (%s).", g_eCustomEnt[Client], sEntClass);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "input", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			
			AcceptEntityInput(g_eCustomEnt[Client], Arg2);
			INK_Message(Client, "Input \"%s\" on entity {green}%d{default} (%s).", Arg2, g_eCustomEnt[Client], sEntClass);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "keyvalue", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			
			DispatchKeyValue(g_eCustomEnt[Client], Arg2, Arg3);
			INK_Message(Client, "Dispatched key-value \"%s\" \"%s\" on entity {green}%d{default} (%s).", Arg2, Arg3, g_eCustomEnt[Client], sEntClass);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "setprop", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			GetCmdArg(5, Arg5, sizeof(Arg5));
			GetCmdArg(6, Arg6, sizeof(Arg6));
			
			new iSize = StringToInt(Arg5);
			if(iSize == 0) iSize = 4;
			
			if(StrEqual(Arg2, "send", false))
			{
				SetEntProp(g_eCustomEnt[Client], Prop_Send, Arg3, StringToInt(Arg4), iSize, StringToInt(Arg6));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				SetEntProp(g_eCustomEnt[Client], Prop_Data, Arg3, StringToInt(Arg4), iSize, StringToInt(Arg6));
			}
			
			INK_Message(Client, "Set \"%s\" on entity {green}%d{default} (%s) to %d.", Arg3, g_eCustomEnt[Client], sEntClass, StringToInt(Arg4));
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "setpropfloat", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			GetCmdArg(5, Arg5, sizeof(Arg5));
			
			if(StrEqual(Arg2, "send", false))
			{
				SetEntPropFloat(g_eCustomEnt[Client], Prop_Send, Arg3, StringToFloat(Arg4), StringToInt(Arg5));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				SetEntPropFloat(g_eCustomEnt[Client], Prop_Data, Arg3, StringToFloat(Arg4), StringToInt(Arg5));
			}
			
			INK_Message(Client, "Set \"%s\" on entity {green}%d{default} (%s) to %f.", Arg3, g_eCustomEnt[Client], sEntClass, StringToFloat(Arg4));
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "setpropstring", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			
			if(StrEqual(Arg2, "send", false))
			{
				SetEntPropString(g_eCustomEnt[Client], Prop_Send, Arg3, Arg4);
			}
			else if(StrEqual(Arg2, "data", false))
			{
				SetEntPropString(g_eCustomEnt[Client], Prop_Data, Arg3, Arg4);
			}
			
			INK_Message(Client, "Set \"%s\" on entity {green}%d{default} (%s) to %s.", Arg3, g_eCustomEnt[Client], sEntClass, Arg4);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "setpropvector", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			GetCmdArg(5, Arg5, sizeof(Arg5));
			
			decl String:sVector[3][16];
			ExplodeString(Arg4, " ", sVector, 3, sizeof(sVector[]));
			
			decl Float:Vector[3];
			for(new x; x < 3; x++)
				Vector[x] = StringToFloat(sVector[x]);
			
			if(StrEqual(Arg2, "send", false))
			{
				SetEntPropVector(g_eCustomEnt[Client], Prop_Send, Arg3, Vector, StringToInt(Arg5));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				SetEntPropVector(g_eCustomEnt[Client], Prop_Data, Arg3, Vector, StringToInt(Arg5));
			}
			
			INK_Message(Client, "Set \"%s\" on entity {green}%d{default} (%s) to %s.", Arg3, g_eCustomEnt[Client], sEntClass, Arg4);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "getprop", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			GetCmdArg(5, Arg5, sizeof(Arg5));
			
			new iSize = StringToInt(Arg4);
			if(iSize == 0) iSize = 4;
			
			new result;
			
			if(StrEqual(Arg2, "send", false))
			{
				result = GetEntProp(g_eCustomEnt[Client], Prop_Send, Arg3, iSize, StringToInt(Arg5));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				result = GetEntProp(g_eCustomEnt[Client], Prop_Data, Arg3, iSize, StringToInt(Arg5));
			}
			
			INK_Message(Client, "Property \"%s\" on entity {green}%d{default} (%s) is %d.", Arg3, g_eCustomEnt[Client], sEntClass, result);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "getpropfloat", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			
			new Float:result;
			
			if(StrEqual(Arg2, "send", false))
			{
				result = GetEntPropFloat(g_eCustomEnt[Client], Prop_Send, Arg3, StringToInt(Arg4));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				result = GetEntPropFloat(g_eCustomEnt[Client], Prop_Data, Arg3, StringToInt(Arg4));
			}
			
			INK_Message(Client, "Property \"%s\" on entity {green}%d{default} (%s) is %f.", Arg3, g_eCustomEnt[Client], sEntClass, result);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "getpropstring", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			
			new String:result[256];
			
			if(StrEqual(Arg2, "send", false))
			{
				GetEntPropString(g_eCustomEnt[Client], Prop_Send, Arg3, result, sizeof(result), StringToInt(Arg4));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				GetEntPropString(g_eCustomEnt[Client], Prop_Data, Arg3, result, sizeof(result), StringToInt(Arg4));
			}
			
			INK_Message(Client, "Property \"%s\" on entity {green}%d{default} (%s) is %s.", Arg3, g_eCustomEnt[Client], sEntClass, result);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "getpropvector", false))
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			GetCmdArg(4, Arg4, sizeof(Arg4));
			
			new Float:result[3];
			
			if(StrEqual(Arg2, "send", false))
			{
				GetEntPropVector(g_eCustomEnt[Client], Prop_Send, Arg3, result, StringToInt(Arg4));
			}
			else if(StrEqual(Arg2, "data", false))
			{
				GetEntPropVector(g_eCustomEnt[Client], Prop_Data, Arg3, result, StringToInt(Arg4));
			}
			
			INK_Message(Client, "Property \"%s\" on entity {green}%d{default} (%s) is %f %f %f.", Arg3, g_eCustomEnt[Client], sEntClass, result[0], result[1], result[2]);
			
			return Plugin_Handled;
		}
		
		if(StrEqual(Arg1, "getclass", false))
		{
			decl String:sNetClass[64];
			GetEntityNetClass(g_eCustomEnt[Client], sNetClass, sizeof(sNetClass));
			
			INK_Message(Client, "Netclass of entity {green}%d{default} (%s) is \"%s\".", g_eCustomEnt[Client], sEntClass, sNetClass);
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_BeamEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		g_eBeamEnt[Client] = 0;
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		if(g_eBeamEnt[Client] == 0)
			g_eBeamEnt[Client] = Ent;
		
		else
		{
			INK_BeamEnt(g_eBeamEnt[Client], Ent, "materials/sprites/laserbeam.vmt", 3.0, 3.0, g_iLandColor[Client]);
			
			g_eBeamEnt[Client] = 0;
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_Flashlight(Client, Args)
{
	new Ent = CreateEntityByName("env_projectedtexture");
	
	decl String:sColor[20];
	Format(sColor, sizeof(sColor), "%d %d %d 255", g_iLandColor[Client][0], g_iLandColor[Client][1], g_iLandColor[Client][2]);
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "farz", "1024.0");
	DispatchKeyValue(Ent, "shadowquality", "1");
	DispatchKeyValue(Ent, "lightcolor", sColor);
	DispatchKeyValue(Ent, "nearz", "16.0");
	DispatchKeyValue(Ent, "lightfov", "50.0");
	DispatchKeyValue(Ent, "lightworld", "1");
	DispatchKeyValue(Ent, "enableshadows", "1");
	
	DispatchSpawn(Ent);
	ActivateEntity(Ent);
	AcceptEntityInput(Ent, "TurnOn");
	
	g_eLightEnt[Client] = Ent;
	
	return Plugin_Handled;
}

public Action:Command_SpawnTestProp(Client, Args)
{
	// Spawn prop:
	new Ent = CreateEntityByName("prop_physics_override");
	
	PrecacheModel("models/props_junk/popcan01a.mdl");
	
	DispatchKeyValue(Ent, "damagetoenablemotion", "0");
	DispatchKeyValue(Ent, "Damagetype", "0");
	DispatchKeyValue(Ent, "disableshadows", "0");
	DispatchKeyValue(Ent, "ExplodeDamage", "0");
	DispatchKeyValue(Ent, "ExplodeRadius", "0");
	DispatchKeyValue(Ent, "spawnflags", "256");
	DispatchKeyValue(Ent, "fademaxdist", "0");
	DispatchKeyValue(Ent, "skin", "0");
	DispatchKeyValue(Ent, "fademindist", "-1");
	DispatchKeyValue(Ent, "shadowcastdist", "0");
	DispatchKeyValue(Ent, "fadescale", "1");
	DispatchKeyValue(Ent, "pressuredelay", "0");
	DispatchKeyValue(Ent, "forcetoenablemotion", "0");
	DispatchKeyValue(Ent, "physdamagescale", "0.1");
	DispatchKeyValue(Ent, "health", "0");
	DispatchKeyValue(Ent, "PerformanceMode", "0");
	DispatchKeyValue(Ent, "inertiaScale", "1.0");
	DispatchKeyValue(Ent, "nodamageforces", "0");
	DispatchKeyValue(Ent, "massScale", "0");
	DispatchKeyValue(Ent, "modelscale", "5");
	DispatchKeyValue(Ent, "maxdxlevel", "0");
	DispatchKeyValue(Ent, "model", "models/props_junk/popcan01a.mdl");
	DispatchKeyValue(Ent, "mindxlevel", "0");
	DispatchKeyValue(Ent, "minhealthdmg", "0");
	
	DispatchSpawn(Ent);
	
	// Calculate spawn position:
	decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
	GetClientEyeAngles(Client, vecEyeAng);
	GetClientAbsOrigin(Client, vecClientOrigin);
	
	decl Float:vecSpawnOrigin[3];
	vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
	vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
	
	vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
	
	new Float:vecSpawnAng[3];
	vecSpawnAng[1] = vecEyeAng[1];
	
	// Teleport & weld:
	TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
	
	// Freeze:
	SetEntityMoveType(Ent, MOVETYPE_NONE);
	AcceptEntityInput(Ent, "disablemotion");
	
	SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
	
	// Give ownership:
	INK_SetOwner(Ent, Client);
	
	// Spawn effect:
	INK_SpawnEffect(Ent);
	
	return Plugin_Handled;
}

public Action:Command_SpawnSlider(Client, Args)
{
	if(INK_CheckLimit(Client, "cel_slider"))
		return Plugin_Handled;
	
	// Make sure the client isn't sending commands too rapidly:
	if(!INK_TooFast(Client))
	{
		// Spawn prop:
		new Ent = CreateEntityByName("prop_physics_override");
		
		PrecacheModel("models/props_junk/trashdumpster02b.mdl");
		DispatchKeyValue(Ent, "model", "models/props_junk/trashdumpster02b.mdl");
		
		DispatchKeyValue(Ent, "physdamagescale", "0.0");
		DispatchKeyValue(Ent, "spawnflags", "256");
		DispatchKeyValue(Ent, "classname", "cel_slider");
		
		DispatchSpawn(Ent);
		
		// Calculate spawn position:
		decl Float:vecClientOrigin[3], Float:vecEyeAng[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientAbsOrigin(Client, vecClientOrigin);
		
		decl Float:vecSpawnOrigin[3];
		vecSpawnOrigin[0] = vecClientOrigin[0]+(Cosine(DegToRad(vecEyeAng[1])) * 50);
		vecSpawnOrigin[1] = vecClientOrigin[1]+(Sine(DegToRad(vecEyeAng[1])) * 50);
		
		vecSpawnOrigin[2] = vecClientOrigin[2] + 40;
		
		new Float:vecSpawnAng[3];
		vecSpawnAng[1] = vecEyeAng[1];
		
		// Teleport:
		TeleportEntity(Ent, vecSpawnOrigin, vecSpawnAng, ZERO_VECTOR);
		
		// Freeze & god:
		SetEntityMoveType(Ent, MOVETYPE_NONE);
		AcceptEntityInput(Ent, "disablemotion");
		
		SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
		
		// Give ownership:
		INK_SetOwner(Ent, Client);
		
		// Spawn effect:
		INK_SpawnEffect(Ent);
	}
	
	return Plugin_Handled;
}


// ENT MODIFY COMMANDS:

public Action:Command_RemoveEnt(Client, Args)
{
	decl String:Arg0[16];
	GetCmdArg(0, Arg0, sizeof(Arg0));
	
	if(Args < 1 && !StrEqual(Arg0, "n_delall", false) && !StrEqual(Arg0, "n_removeall", false))
	{
		// Point and click removal:
		new Ent = INK_AimTarget(Client);
	
		if(Ent == -1)
		{
			INK_NoTarget(Client);
			return Plugin_Handled;
		}
		
		decl Float:vecAimPos[3];
		INK_AimPosition(Client, vecAimPos);
		
		if(INK_GetOwner(Ent) == Client || INK_GetLand(vecAimPos) == Client)
		{
			decl String:sEntName[16];
			Entity_GetName(Ent, sEntName, sizeof(sEntName));
			
			if(!StrEqual(sEntName, "deleted", false))
			{
				decl String:sEntClass[32];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrContains(sEntClass, "prop_physics", false) == 0
				||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_teleport", false)
				&& !StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false) && !StrEqual(sEntClass, "cel_link", false))
				||(StrContains(sEntClass, "bit_", false) == 0))
					INK_WriteUndoQueue(Client, Ent);
				
				INK_EntMessage(Client, "Removed", Ent);
				INK_DeleteBeam(Client, vecAimPos);
			}
			
			INK_RemoveEnt(Ent);
		}
		else INK_NotYours(Client);
	}
	else
	{
		// Remove entire specified groups:
		decl String:Arg1[16];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		
		new iMaxEnts = GetMaxEntities();
		
		if(StrEqual(Arg1, "all", false) || StrEqual(Arg0, "n_delall", false) || StrEqual(Arg0, "n_removeall", false))
		{
			for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
			{
				if(IsValidEntity(Ent))
				{
					if(INK_GetOwner(Ent) == Client)
						INK_RemoveEnt(Ent, false);
				}
			}
		}
		else
		{
			for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
			{
				if(IsValidEntity(Ent))
				{
					if(INK_GetOwner(Ent) == Client)
					{
						decl String:sEntName[90], String:sNameArray[2][32];
						GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
						ExplodeString(sEntName, "^", sNameArray, 2, sizeof(sNameArray[]));
						
						if(StrEqual(sNameArray[1], Arg1))
							INK_RemoveEnt(Ent, false);
					}
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_MoveEnt(Client, Args)
{
	if(g_eCopyEnt[Client] != 0)
	{
		INK_Message(Client, "You're already moving something.");
		return Plugin_Handled;
	}
	
	if(g_eGrabEnt[Client] == 0)
	{
		decl String:sCmdName[8];
		GetCmdArg(0, sCmdName, sizeof(sCmdName));
		
		if(StrEqual(sCmdName, "-move", false))
			return Plugin_Handled;
		
		new Ent = INK_AimTarget(Client);
		
		if(Ent == -1)
		{
			INK_NoTarget(Client);
			return Plugin_Handled;
		}
		
		// If entity is parented, target parent instead:
		new EntChild = Ent;
		Ent = INK_TopParent(Ent);
		
		if(INK_GetOwner(Ent) == Client)
		{
			// Origin relative to client:
			decl Float:vecClientPos[3], Float:vecEntPos[3];
			GetClientAbsOrigin(Client, vecClientPos);
			INK_GetEntPos(Ent, vecEntPos);
			
			SubtractVectors(vecClientPos, vecEntPos, g_vecGrabPos[Client]);
			
			// Color:
			new iColorOffset = GetEntSendPropOffs(EntChild, "m_clrRender");
			g_iGrabColor[Client][0] = GetEntData(EntChild, iColorOffset, 1);
			g_iGrabColor[Client][1] = GetEntData(EntChild, iColorOffset + 1, 1);
			g_iGrabColor[Client][2] = GetEntData(EntChild, iColorOffset + 2, 1);
			g_iGrabColor[Client][3] = GetEntData(EntChild, iColorOffset + 3, 1);
			
			// Movetype:
			g_mGrabMove[Client] = GetEntityMoveType(Ent);
			
			// Prepare grab:
			SetEntProp(EntChild, Prop_Send, "m_nRenderMode", 1, 1);
			SetEntityRenderColor(EntChild, 0, 255, 0, 192);
			
			AcceptEntityInput(g_eGrabEnt[Client], "EnableMotion");
			SetEntityMoveType(Ent, MOVETYPE_NONE);
			
			g_eGrabEnt[Client] = Ent;
			g_eGrabChild[Client] = EntChild;
		}
		else INK_NotYours(Client);
	}
	else
	{
		if(IsValidEntity(g_eGrabEnt[Client]))
		{
			if(IsValidEntity(g_eGrabChild[Client]))
				SetEntityRenderColor(g_eGrabChild[Client], g_iGrabColor[Client][0], g_iGrabColor[Client][1], g_iGrabColor[Client][2], g_iGrabColor[Client][3]);
			
			SetEntityMoveType(g_eGrabEnt[Client], g_mGrabMove[Client]);
			if(g_mGrabMove[Client] == MOVETYPE_NONE) AcceptEntityInput(g_eGrabEnt[Client], "DisableMotion");
			
			TeleportEntity(g_eGrabEnt[Client], NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
		}
		
		g_eGrabEnt[Client] = 0;
		g_eGrabChild[Client] = 0;
	}
	
	return Plugin_Handled;
}

public Action:Command_StackEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!stack{default} <x> <y> <z>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(!INK_TooFast(Client))
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0 || StrContains(sEntClass, "cel_", false) == 0)
		{
			decl String:sEntString[256];
			
			// Copy:
			INK_EntToString(Ent, sEntString, sizeof(sEntString));
			
			if(INK_CheckLimit(Client, sEntString))
				return Plugin_Handled;
			
			new EntCopy = INK_StringToEnt(sEntString);
			
			if(StrContains(sEntString, "cel_door", false) == -1)
			{
				SetEntityMoveType(EntCopy, MOVETYPE_NONE);
				AcceptEntityInput(EntCopy, "disablemotion");
			}
			
			SetEntProp(EntCopy, Prop_Data, "m_takedamage", 0, 1);
			
			// Get new position:
			decl String:Arg1[16], String:Arg2[16], String:Arg3[16];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			
			decl Float:vecFinalPos[3];
			vecFinalPos[0] = StringToFloat(Arg1);
			vecFinalPos[1] = StringToFloat(Arg2);
			vecFinalPos[2] = StringToFloat(Arg3);
			
			// Calculate:
			Entity_SetParent(EntCopy, Ent);
			TeleportEntity(EntCopy, vecFinalPos, ZERO_VECTOR, ZERO_VECTOR);
			Entity_RemoveParent(EntCopy);
			
			// Set ownership:
			INK_SetOwner(EntCopy, Client);
			
			// Sound effect:
			switch(GetRandomInt(0, 2))
			{
				case 0: EmitSoundToAll("physics/concrete/concrete_impact_soft1.wav", EntCopy);
				case 1: EmitSoundToAll("physics/concrete/concrete_impact_soft2.wav", EntCopy);
				case 2: EmitSoundToAll("physics/concrete/concrete_impact_soft3.wav", EntCopy);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_FreezeEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	new EntChild = Ent;
	Ent = INK_TopParent(Ent);
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0
		||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_door", false) && !StrEqual(sEntClass, "cel_camera", false))
		||(StrContains(sEntClass, "bit_", false) == 0 && !StrEqual(sEntClass, "bit_ammocrate", false) && !StrEqual(sEntClass, "bit_charger", false)))
		{
			SetEntityMoveType(Ent, MOVETYPE_NONE);
			AcceptEntityInput(Ent, "disablemotion");
			
			INK_ChangeBeam(Client);
			INK_EntMessage(Client, "Disabled motion on", EntChild);
		}
		else INK_Message(Client, "You cannot freeze this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_UnfreezeEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	new EntChild = Ent;
	Ent = INK_TopParent(Ent);
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0
		||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_door", false) && !StrEqual(sEntClass, "cel_camera", false))
		||(StrContains(sEntClass, "bit_", false) == 0 && !StrEqual(sEntClass, "bit_ammocrate", false) && !StrEqual(sEntClass, "bit_charger", false)))
		{
			SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);
			AcceptEntityInput(Ent, "enablemotion");
			
			INK_ChangeBeam(Client);
			INK_EntMessage(Client, "Enabled motion on", EntChild);
		}
		else INK_Message(Client, "You cannot unfreeze this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_RotateEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!rotate{default} <x> <y> <z>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sPitch[16], String:sYaw[16], String:sRoll[16], String:sAngSet[4];
		
		GetCmdArg(1, sPitch, sizeof(sPitch));
		GetCmdArg(2, sYaw, sizeof(sYaw));
		GetCmdArg(3, sRoll, sizeof(sRoll));
		GetCmdArg(4, sAngSet, sizeof(sAngSet));
		
		decl Float:vecFinalAng[3];
		
		if(StrEqual(sAngSet, "set", false))
		{
			vecFinalAng[0] = StringToFloat(sPitch);
			vecFinalAng[1] = StringToFloat(sYaw);
			vecFinalAng[2] = StringToFloat(sRoll);
		}
		else
		{
			decl Float:vecEntAng[3];
			INK_GetEntAng(Ent, vecEntAng);
			vecFinalAng[0] = vecEntAng[0] + StringToFloat(sPitch);
			vecFinalAng[1] = vecEntAng[1] + StringToFloat(sYaw);
			vecFinalAng[2] = vecEntAng[2] + StringToFloat(sRoll);
		}
		
		TeleportEntity(Ent, NULL_VECTOR, vecFinalAng, NULL_VECTOR);
		EmitSoundToAll("buttons/lever7.wav", Ent);
		
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrEqual(sEntClass, "cel_door", false))
		{
			decl String:sEntString[256];
			INK_EntToString(Ent, sEntString, sizeof(sEntString));
			
			INK_RemoveEnt(Ent, false, 0.0);
			Ent = INK_StringToEnt(sEntString);
			INK_SetOwner(Ent, Client);
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_StandEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		TeleportEntity(Ent, NULL_VECTOR, ZERO_VECTOR, NULL_VECTOR);
		
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrEqual(sEntClass, "cel_door", false))
		{
			decl String:sEntString[256];
			INK_EntToString(Ent, sEntString, sizeof(sEntString));
			
			INK_RemoveEnt(Ent, false, 0.0);
			Ent = INK_StringToEnt(sEntString);
			INK_SetOwner(Ent, Client);
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_SkinEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!skin{default} <skin number> OR <next / prev>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0
		|| StrContains(sEntClass, "cel_", false) == 0
		|| StrContains(sEntClass, "bit_", false) == 0)
		{
			decl String:sSkin[8];
			GetCmdArg(1, sSkin, sizeof(sSkin));
			
			decl iSkin;
			
			if(StrEqual(sSkin, "next", false))
				iSkin = GetEntProp(Ent, Prop_Send, "m_nSkin", 1) + 1;
			
			else if(StrEqual(sSkin, "prev", false))
				iSkin = GetEntProp(Ent, Prop_Send, "m_nSkin", 1) - 1;
			
			else if(StrEqual(sSkin, "copy", false))
			{
				g_iCopySkin[Client] = GetEntProp(Ent, Prop_Send, "m_nSkin", 1);
				
				INK_Message(Client, "Copied skin {green}%d{default}.", g_iCopySkin[Client]);
				return Plugin_Handled;
			}
			else if(StrEqual(sSkin, "paste", false))
			{
				iSkin = g_iCopySkin[Client];
				
				INK_EntMessage(Client, "Pasted skin onto", Ent);
			}
			else iSkin = StringToInt(sSkin);
			
			SetEntProp(Ent, Prop_Send, "m_nSkin", iSkin);
			
			INK_ChangeBeam(Client);
		}
		else INK_Message(Client, "You cannot change the skin on this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_SolidEnt(Client, Args)
{
	decl String:CmdName[16];
	GetCmdArg(0, CmdName, sizeof(CmdName));
	
	if(Args < 1 && !StrEqual(CmdName, "n_nocollide", false) && !StrEqual(CmdName, "n_collide", false))
	{
		INK_Message(Client, "Usage: {green}!solid{default} <on / off>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0
		||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_camera", false))
		|| StrContains(sEntClass, "bit_", false) == 0)
		{
			decl String:Arg1[8];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			
			if(StrEqual(Arg1, "on", false) || StrEqual(CmdName, "n_collide", false))
			{
				DispatchKeyValue(Ent, "solid", "6");
				
				INK_ChangeBeam(Client);
				INK_EntMessage(Client, "Turned solidity on", Ent);
			}
			else if(StrEqual(Arg1, "off", false) || StrEqual(CmdName, "n_nocollide", false))
			{
				DispatchKeyValue(Ent, "solid", "4");
				
				INK_ChangeBeam(Client);
				INK_EntMessage(Client, "Turned solidity off", Ent);
			}
			else INK_Message(Client, "Usage: {green}!rotate{default} <skin number> OR <next / prev>");
		}
		else INK_Message(Client, "You cannot change the solidity on this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_GodEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!god{default} <on / off>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0)
		{
			decl String:Arg1[8];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			
			if(StrEqual(Arg1, "on", false))
			{
				DispatchKeyValue(Ent, "classname", "prop_physics_override");
				SetEntProp(Ent, Prop_Data, "m_takedamage", 0, 1);
				
				INK_ChangeBeam(Client);
				INK_EntMessage(Client, "Turned invincibility on", Ent);
			}
			else if(StrEqual(Arg1, "off", false))
			{
				DispatchKeyValue(Ent, "classname", "prop_physics_breakable");
				SetEntProp(Ent, Prop_Data, "m_takedamage", 2, 1);
				
				INK_ChangeBeam(Client);
				INK_EntMessage(Client, "Turned invincibility off", Ent);
			}
			else INK_Message(Client, "Usage: {green}!god{default} <on / off>");
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_GiveEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!give{default} <player name>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sNewOwner[MAX_NAME_LENGTH];
		GetCmdArg(1, sNewOwner, sizeof(sNewOwner));
		
		new Target = FindTarget(Client, sNewOwner, false, false);
		
		if(Target != -1 && Target != Client)
		{
			g_iGiveEnt[Ent] = Target;
			
			INK_EntMessage(Client, "Offering", Ent, "to {green}%N{default}.", Target);
			INK_Message(Target, "{green}%N{default} has offered an entity to you. Do {green}!accept{default} on it to claim!", Client);
		}
		else INK_Message(Client, "Player not found.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_AcceptEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(g_iGiveEnt[Ent] == Client || Client_HasAdminFlags(Client, ADMFLAG_ROOT))
	{
		new Owner = INK_GetOwner(Ent);
		
		if(Owner > 0)
		{
			if(g_iGiveEnt[Ent] == Client)
				INK_EntMessage(Owner, "Gave", Ent, "to {green}%N", Client);
			
			INK_EntMessage(Client, "Accepted", Ent, "from {green}%N", Owner);
		}
		else
		{
			INK_EntMessage(Client, "Accepted", Ent, "from the map.", Owner);
		}
		
		INK_SetOwner(Ent, Client);
	}
	else INK_Message(Client, "This entity is not offered to you.");
	
	return Plugin_Handled;
}

public Action:Command_ColorEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!color{default} <color name> OR <red> <green> <blue>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:Arg1[16], String:Arg2[4], String:Arg3[4];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		
		new Red, Green, Blue;
		
		if(StrEqual(Arg1, "copy", false))
		{
			new clrOff = GetEntSendPropOffs(Ent, "m_clrRender");
			
			g_iCopyColor[Client][0] = GetEntData(Ent, clrOff, 1);
			g_iCopyColor[Client][1] = GetEntData(Ent, clrOff + 1, 1);
			g_iCopyColor[Client][2] = GetEntData(Ent, clrOff + 2, 1);
			
			INK_Message(Client, "Copied color {green}%d %d %d{default}.", g_iCopyColor[Client][0], g_iCopyColor[Client][1], g_iCopyColor[Client][2]);
			
			return Plugin_Handled;
		}
		else if(StrEqual(Arg1, "paste", false))
		{
			Red = g_iCopyColor[Client][0];
			Green = g_iCopyColor[Client][1];
			Blue = g_iCopyColor[Client][2];
			
			INK_EntMessage(Client, "Pasted color onto", Ent);
		}
		else if(StringToInt(Arg1) == 0 && StrContains(Arg1, "0") != 0)
		{
			decl String:sColorString[16];
			
			// Attempt to match a color to the given alias:
			new Handle:hColorKv = CreateKeyValues("Colors");
			FileToKeyValues(hColorKv, ColorPath);
			KvGetString(hColorKv, Arg1, sColorString, sizeof(sColorString), "Null");
			
			CloseHandle(hColorKv);
			
			// If no color was found:
			if(StrEqual(sColorString, "Null"))
			{
				INK_Message(Client, "Color not found.");
				return Plugin_Handled;
			}
			
			decl String:sColors[3][8];
			ExplodeString(sColorString, " ", sColors, 3, sizeof(sColors[]));
			
			Red = StringToInt(sColors[0]);
			Green = StringToInt(sColors[1]);
			Blue = StringToInt(sColors[2]);
		}
		else
		{
			GetCmdArg(2, Arg2, sizeof(Arg2));
			GetCmdArg(3, Arg3, sizeof(Arg3));
			
			Red = StringToInt(Arg1);
			Green = StringToInt(Arg2);
			Blue = StringToInt(Arg3);
		}
		
		new Alpha = GetEntSendPropOffs(Ent, "m_clrRender");
		Alpha = GetEntData(Ent, Alpha + 3, 1);
		
		if(Red > 255) Red = 255;
		if(Green > 255) Green = 255;
		if(Blue > 255) Blue = 255;
		
		if(g_eGrabChild[Client] == Ent || g_eCopyEnt[Client] == Ent)
		{
			g_iGrabColor[Client][0] = Red;
			g_iGrabColor[Client][1] = Green;
			g_iGrabColor[Client][2] = Blue;
		}
		else SetEntityRenderColor(Ent, Red, Green, Blue, Alpha);
		
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		// Color light:
		if(StrEqual(sEntClass, "cel_light", false))
		{
			new EntLight = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
			SetEntityRenderColor(EntLight, Red, Green, Blue, 255);
		}
		
		INK_ChangeBeam(Client);
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_AlphaEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!amt{default} <50-255>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:Arg1[16];
		GetCmdArg(1, Arg1, sizeof(Arg1));
		
		new Red, Green, Blue = GetEntSendPropOffs(Ent, "m_clrRender");
		Red = GetEntData(Ent, Blue, 1);
		Green = GetEntData(Ent, Blue + 1, 1);
		Blue = GetEntData(Ent, Blue + 2, 1);
		
		new Alpha = StringToInt(Arg1);
		if(Alpha > 255) Alpha = 255;
		if(Alpha < 50) Alpha = 50;
		
		if(g_eGrabChild[Client] == Ent || g_eCopyEnt[Client] == Ent)
			g_iGrabColor[Client][3] = Alpha;
		
		else
		{
			SetEntProp(Ent, Prop_Send, "m_nRenderMode", 1, 1);
			SetEntityRenderColor(Ent, Red, Green, Blue, Alpha);
		}
		
		INK_ChangeBeam(Client);
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_ModelEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!replace{default} <prop name>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrContains(sEntClass, "prop_physics", false) == 0
		||(StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_fire", false)))
		{
			decl String:Arg1[128];
			GetCmdArg(1, Arg1, sizeof(Arg1));
			String_ToLower(Arg1, Arg1, sizeof(Arg1));
			
			decl String:sPropString[128];
			
			// Attempt to match a model to the given prop alias:
			new Handle:hPropHandle = CreateKeyValues("Props");
			FileToKeyValues(hPropHandle, PropPath);
			KvGetString(hPropHandle, Arg1, sPropString, sizeof(sPropString), "Null");
			
			// If no model was found:
			if(StrContains(sPropString, "Null", false) != -1)
			{
				// Attempt to correct:
				if(StrContains(Arg1, "1", false) != -1)
					ReplaceString(Arg1, sizeof(Arg1), "1", "");
				
				else
					Format(Arg1, sizeof(Arg1), "%s1", Arg1);
				
				KvGetString(hPropHandle, Arg1, sPropString, sizeof(sPropString), "Null");
				
				// If no model was found, cancel:
				if(StrContains(sPropString, "Null", false) != -1)
				{
					INK_Message(Client, "Prop not found.", Arg1);
					
					CloseHandle(hPropHandle);
					return Plugin_Handled;
				}
			}
			
			CloseHandle(hPropHandle);
			
			decl String:sPropBuffer[3][128];
			ExplodeString(sPropString, "^", sPropBuffer, 3, sizeof(sPropBuffer[]));
			
			// Found a model, but discontinued (not spawnable by regular players):
			if(StringToInt(sPropBuffer[2]) == 1)
			{
				INK_Message(Client, "This prop has been discontinued.", Arg1);
				return Plugin_Handled;
			}
			
			INK_ChangeBeam(Client);
			
			PrecacheModel(sPropBuffer[0]);
			SetEntityModel(Ent, sPropBuffer[0]);
			DispatchKeyValue(Ent, "target", Arg1);
			
			// Spawn effect:
			INK_SpawnEffect(Ent);
		}
		else INK_Message(Client, "You cannot replace the model of this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_DropEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		new EntParent = Entity_GetParent(Ent);
		if(IsValidEntity(EntParent))
			Entity_RemoveParent(Ent);
		
		decl Float:vecEntPos[3], Float:vecGround[3];
		INK_GetEntPos(Ent, vecEntPos);
		
		new Handle:hTraceRay = TR_TraceRayFilterEx(vecEntPos, Float:{90.0,0.0,0.0}, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterPlayer, Ent);
		if(TR_DidHit(hTraceRay))
		{
			decl Float:vecMins[3];
			GetEntPropVector(Ent, Prop_Send, "m_vecMins", vecMins);
			
			TR_GetEndPosition(vecGround, hTraceRay);
			vecEntPos[2] = vecGround[2] - float(RoundFloat(vecMins[2]));
			TeleportEntity(Ent, vecEntPos, NULL_VECTOR, NULL_VECTOR);
		}
		CloseHandle(hTraceRay);
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_SmoveEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!smove{default} <x> <y> <z>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sXOffset[16], String:sYOffset[16], String:sZOffset[16];
		GetCmdArg(1, sXOffset, 16);
		GetCmdArg(2, sYOffset, 16);
		GetCmdArg(3, sZOffset, 16);
		
		decl Float:vecOffset[3];
		vecOffset[0] = StringToFloat(sXOffset);
		vecOffset[1] = StringToFloat(sYOffset);
		vecOffset[2] = StringToFloat(sZOffset);
		
		// We're moving relative to the original position, so we can safely grab the raw origin:
		decl Float:vecEntPos[3];
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", vecEntPos);
		
		AddVectors(vecEntPos, vecOffset, vecEntPos);
		TeleportEntity(Ent, vecEntPos, NULL_VECTOR, NULL_VECTOR);
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_MovetoEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		g_eMovetoEnt[Client] = 0;
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		if(g_eMovetoEnt[Client] == 0)
		{
			g_eMovetoEnt[Client] = Ent;
			INK_Message(Client, "Now do {green}!moveto{default} on target entity to move.");
		}
		else
		{
			decl Float:vecEntPos[3];
			INK_GetEntPos(Ent, vecEntPos);
			
			TeleportEntity(g_eMovetoEnt[Client], vecEntPos, NULL_VECTOR, ZERO_VECTOR);
			g_eMovetoEnt[Client] = 0;
			
			INK_EntMessage(Client, "Moved", Ent, "to target");
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_WeldEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		g_eWeldEnt[Client] = 0;
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		if(g_eWeldEnt[Client] == 0)
		{
			g_eWeldEnt[Client] = Ent;
			INK_Message(Client, "Now do {green}!weld{default} on target entity to weld.");
		}
		else
		{
			decl String:sEntClass[32];
			GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
			
			if(StrContains(sEntClass, "prop_physics", false) == 0 || StrEqual(sEntClass, "cel_door", false))
			{
				// Entity_SetParent(g_eWeldEnt[Client], Ent);
				INK_WeldBeam(Ent, g_eWeldEnt[Client]);
				
				INK_EntMessage(Client, "Welded", g_eWeldEnt[Client], "to target");
				g_eWeldEnt[Client] = 0;
			}
			else
			{
				INK_Message(Client, "You cannot weld to this entity.");
				g_eWeldEnt[Client] = 0;
			}
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_UnweldEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		new bool:bIsWelded;
		
		new eChild = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
		if(StrContains(sEntClass, "prop_physics", false) == 0)
		{
			while(IsValidEntity(eChild))
			{
				Entity_RemoveParent(eChild);
				eChild = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
				
				bIsWelded = true;
			}
		}
		
		if(bIsWelded) INK_EntMessage(Client, "Released all welds on", Ent);
		else INK_EntMessage(Client, "This entity is not welded.", Ent);
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_LockEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[64];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrEqual(sEntClass, "cel_door", false))
		{
			AcceptEntityInput(Ent, "Lock");
			
			INK_EntMessage(Client, "Locked", Ent);
			INK_ChangeBeam(Client);
		}
		else if((StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_camera", false) && !StrEqual(sEntClass, "cel_ladder", false) && !StrEqual(sEntClass, "cel_fire", false))
		||(StrContains(sEntClass, "bit_", false) == 0 && !StrEqual(sEntClass, "bit_ammocrate", false) && !StrEqual(sEntClass, "bit_charger", false)))
		{
			if(Entity_HasSpawnFlags(Ent, 256))
				Entity_RemoveSpawnFlags(Ent, 256);
			
			INK_EntMessage(Client, "Locked", Ent);
			INK_ChangeBeam(Client);
		}
		else INK_Message(Client, "You cannot lock this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_UnlockEnt(Client, args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[64];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrEqual(sEntClass, "cel_door", false))
		{
			AcceptEntityInput(Ent, "Unlock");
			
			INK_EntMessage(Client, "Unlocked", Ent);
			INK_ChangeBeam(Client);
		}
		else if((StrContains(sEntClass, "cel_", false) == 0 && !StrEqual(sEntClass, "cel_camera", false) && !StrEqual(sEntClass, "cel_ladder", false) && !StrEqual(sEntClass, "cel_fire", false))
		||(StrContains(sEntClass, "bit_", false) == 0 && !StrEqual(sEntClass, "bit_ammocrate", false) && !StrEqual(sEntClass, "bit_charger", false)))
		{
			if(!Entity_HasSpawnFlags(Ent, 256))
				Entity_AddSpawnFlags(Ent, 256);
			
			INK_EntMessage(Client, "Unlocked", Ent);
			INK_ChangeBeam(Client);
		}
		else INK_Message(Client, "You cannot unlock this entity.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_SeturlEnt(Client, Args)
{
	if(Args < 1)
	{
		INK_Message(Client, "Usage: {green}!seturl{default} <web url>");
		return Plugin_Handled;
	}
	
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[64];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(StrEqual(sEntClass, "cel_internet", false))
		{
			decl String:Arg[256];
			GetCmdArgString(Arg, sizeof(Arg));
			
			if(StrEqual(Arg, ""))
			{
				DispatchKeyValue(Ent, "target", "");
				
				INK_ChangeBeam(Client);
				INK_EntMessage(Client, "Cleared URL on", Ent);
				
				return Plugin_Handled;
			}
			
			if(StrContains(Arg, "://", false) == -1)
				Format(Arg, sizeof(Arg), "http://%s", Arg);
			
			DispatchKeyValue(Ent, "target", Arg);
			
			INK_ChangeBeam(Client);
			INK_EntMessage(Client, "Applied URL to", Ent);
		}
		else INK_Message(Client, "This command can only be used on internet cels.");
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
}

public Action:Command_WireEnt(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		g_eWireEnt[Client] = 0;
		return Plugin_Handled;
	}
	
	if(INK_GetOwner(Ent) == Client)
	{
		decl String:sEntClass[32];
		GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
		
		if(g_eWireEnt[Client] == 0 || !IsValidEntity(g_eWireEnt[Client]))
		{
			// Check 1st entity for invalid wire:
			if((StrContains(sEntClass, "cel_", false) != 0
			&& !StrEqual(sEntClass, "cel_ladder", false) && !StrEqual(sEntClass, "cel_fire", false)
			&& !StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false)))
			{
				INK_EntMessage(Client, "Entity", Ent, "cannot be wired");
				
				g_eWireEnt[Client] = 0;
				return Plugin_Handled;
			}
			
			g_eWireEnt[Client] = Ent;
			INK_Message(Client, "Now do {green}!wire{default} on target entity to wire.");
		}
		else
		{
			decl String:sWireEntClass[32];
			GetEntityClassname(g_eWireEnt[Client], sWireEntClass, sizeof(sWireEntClass));
			
			// Check 2nd entity for invalid wire:
			if((StrContains(sEntClass, "cel_", false) != 0
			&& !StrEqual(sEntClass, "cel_ladder", false) && !StrEqual(sEntClass, "cel_fire", false)
			&& !StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false)))
			{
				INK_EntMessage(Client, "Entity", Ent, "cannot be wired");
				
				g_eWireEnt[Client] = 0;
				return Plugin_Handled;
			}
			
			// Check for a controller entity:
			if(!StrEqual(sEntClass, "cel_button", false) && !StrEqual(sEntClass, "cel_trigger", false)
			&& !StrEqual(sWireEntClass, "cel_button", false) && !StrEqual(sWireEntClass, "cel_trigger", false))
			{
				INK_Message(Client, "Selected entities cannot be wired together.");
				
				g_eWireEnt[Client] = 0;
				return Plugin_Handled;
			}
			
			// Unable to wire a controller to a controller:
			if((StrEqual(sEntClass, "cel_button", false) || StrEqual(sEntClass, "cel_trigger", false))
			&& (StrEqual(sWireEntClass, "cel_button", false) || StrEqual(sWireEntClass, "cel_trigger", false)))
			{
				INK_Message(Client, "Selected entities cannot be wired together.");
				
				g_eWireEnt[Client] = 0;
				return Plugin_Handled;
			}
			
			new Controller;
			new Target;
			
			// Find controller entity:
			if(StrEqual(sWireEntClass, "cel_button", false) || StrEqual(sWireEntClass, "cel_trigger", false))
			{
				Controller = g_eWireEnt[Client];
				Target = Ent;
			}
			else if(StrEqual(sEntClass, "cel_button", false) || StrEqual(sEntClass, "cel_trigger", false))
			{
				Controller = Ent;
				Target = g_eWireEnt[Client];
			}
			
			decl String:sEntTarget[32];
			GetEntPropString(Controller, Prop_Data, "m_target", sEntTarget, sizeof(sEntTarget));
			
			if(StrContains(sEntTarget, "0") == -1)
			{
				INK_Message(Client, "Controller entity has reached maximum connections (6).");
				
				g_eWireEnt[Client] = 0;
				return Plugin_Handled;
			}
			
			new String:sTargetIndex[8];
			IntToString(Target, sTargetIndex, sizeof(sTargetIndex));
			
			// Register target onto controller entity:
			ReplaceStringEx(sEntTarget, sizeof(sEntTarget), "0", sTargetIndex);
			DispatchKeyValue(Controller, "target", sEntTarget);
			
			INK_Message(Client, "Created wire connection.");
			
			TE_SetupBeamEnts(Target, Controller, CrystalBeam, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, PHYS_WHITE, 10);
			TE_SendToAll(0.0);
			
			EmitSoundToAll("buttons/button19.wav", Controller);
			
			g_eWireEnt[Client] = 0;
		}
	}
	else INK_NotYours(Client);
	
	return Plugin_Handled;
	
	// links:
	/* if(StrContains(sEntTarget, "use", false) == 0)
	{
		if(StrContains(sEntClass, "cel_", false) != 0 || StrEqual(sEntClass, "cel_ladder", false) || StrEqual(sEntClass, "cel_fire", false) || StrEqual(sEntClass, "cel_button", false) || StrEqual(sEntClass, "cel_trigger", false))
		{
			INK_EntMessage(Client, "This link type can't be hooked to", Ent);
			
			INK_RemoveEnt(g_eLinkEnt[Client], false);
			g_eLinkEnt[Client] = 0;
			return Plugin_Handled;
		}
	}
	else if(StrContains(sEntTarget, "lock", false) == 0)
	{
		if(StrContains(sEntClass, "cel_", false) != 0 || StrEqual(sEntClass, "cel_ladder", false) || StrEqual(sEntClass, "cel_fire", false))
		{
			INK_EntMessage(Client, "This link type can't be hooked to", Ent);
			
			INK_RemoveEnt(g_eLinkEnt[Client], false);
			g_eLinkEnt[Client] = 0;
			return Plugin_Handled;
		}
	}
	else if(StrContains(sEntTarget, "solid", false) == 0)
	{
		if(StrContains(sEntClass, "prop_physics", false) == -1)
		{
			INK_EntMessage(Client, "This link type can't be hooked to", Ent);
			
			INK_RemoveEnt(g_eLinkEnt[Client], false);
			g_eLinkEnt[Client] = 0;
			return Plugin_Handled;
		}
	} */
}


// ENT INFO COMMANDS:

public Action:Command_EntCount(Client, Args)
{
	INK_Message(Client, "Props: %d/%d", INK_GetPropCount(Client), GetConVarInt(sv_ink_maxprops));
	INK_Message(Client, "Cels: %d/%d", INK_GetCelCount(Client), GetConVarInt(sv_ink_maxcels));
	INK_Message(Client, "Lights: %d/%d", INK_GetLightCount(Client), GetConVarInt(sv_ink_maxlights));
	INK_Message(Client, "Bits: %d/%d", INK_GetBitCount(Client), GetConVarInt(sv_ink_maxbits));
	INK_Message(Client, "Total: %d", INK_GetTotalCount(Client));
	return Plugin_Handled;
}

public Action:Command_EntOwner(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	for(new C = 1; C <= MaxClients; C++)
	{
		if(INK_GetOwner(Ent) == C)
		{
			INK_Message(Client, "Entity is owned by {green}%N{default}.", C);
			return Plugin_Handled;
		}
	}
	
	INK_Message(Client, "This entity is not owned by anyone.");
	return Plugin_Handled;
}

public Action:Command_EntString(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	decl String:sEntString[256];
	INK_EntToString(Ent, sEntString, sizeof(sEntString));
	
	INK_Message(Client, "// classname|model|flags|renderfx|scale|solidity|takedamage|movetype|skin|color|parenting|position|angle|data");
	INK_Message(Client, "Entity Index: %d", Ent);
	INK_Message(Client, sEntString);
	
	return Plugin_Handled;
}

public Action:Command_DisplayAxis(Client, Args)
{
	decl Float:vecClientPos[3];
	GetClientAbsOrigin(Client, vecClientPos);
	vecClientPos[2] += 40;
	
	decl Float:vecXPos[3];
	AddVectors(vecClientPos, ZERO_VECTOR, vecXPos);
	vecXPos[0] += 50;
	
	decl Float:vecYPos[3];
	AddVectors(vecClientPos, ZERO_VECTOR, vecYPos);
	vecYPos[1] += 50;
	
	decl Float:vecZPos[3];
	AddVectors(vecClientPos, ZERO_VECTOR, vecZPos);
	vecZPos[2] += 50;
	
	TE_SetupBeamPoints(vecClientPos, vecXPos, BeamSprite, HaloSprite, 0, 15, 25.0, 3.0, 3.0, 1, 0.0, {255, 25, 0, 200}, 3);
	TE_SendToClient(Client, 0.0);
	
	TE_SetupBeamPoints(vecClientPos, vecYPos, BeamSprite, HaloSprite, 0, 15, 25.0, 3.0, 3.0, 1, 0.0, {50, 255, 0, 200}, 3);
	TE_SendToClient(Client, 0.0);
	
	TE_SetupBeamPoints(vecClientPos, vecZPos, BeamSprite, HaloSprite, 0, 15, 25.0, 3.0, 3.0, 1, 0.0, {0, 50, 255, 200}, 3);
	TE_SendToClient(Client, 0.0);
	
	INK_Message(Client, "Created axis marker. (red X, green Y, blue Z)");
	return Plugin_Handled;
}

public Action:Command_MaxEntities(Client, Args)
{
	INK_Message(Client, "GetMaxEntities() == %d", GetMaxEntities());
}

public Action:Command_ListEntProp(Client, Args)
{
	new Ent = INK_AimTarget(Client);
	
	if(Ent == -1)
	{
		INK_NoTarget(Client);
		return Plugin_Handled;
	}
	
	// UUURRRRGGGGGGGGGGGGGGGGGGGGGGGHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHJKKLK;KJHJHL;
	
	new m_flAnimTime = GetEntProp(Ent, Prop_Send, "m_flAnimTime");
	INK_Message(Client, "m_flAnimTime %d", m_flAnimTime);
	
	new m_flSimulationTime = GetEntProp(Ent, Prop_Send, "m_flSimulationTime");
	INK_Message(Client, "m_flSimulationTime %d", m_flSimulationTime);
	
	new Float:m_vecOrigin[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", m_vecOrigin);
	INK_Message(Client, "m_vecOrigin %f %f %f", m_vecOrigin[0], m_vecOrigin[1], m_vecOrigin[2]);
	
	new m_ubInterpolationFrame = GetEntProp(Ent, Prop_Send, "m_ubInterpolationFrame");
	INK_Message(Client, "m_ubInterpolationFrame %d", m_ubInterpolationFrame);
	
	new m_nModelIndex = GetEntProp(Ent, Prop_Send, "m_nModelIndex");
	INK_Message(Client, "m_nModelIndex %d", m_nModelIndex);
	
	new Float:m_vecMinsPreScaled[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecMinsPreScaled", m_vecMinsPreScaled);
	INK_Message(Client, "m_vecMinsPreScaled %f %f %f", m_vecMinsPreScaled[0], m_vecMinsPreScaled[1], m_vecMinsPreScaled[2]);
	
	new Float:m_vecMaxsPreScaled[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecMaxsPreScaled", m_vecMaxsPreScaled);
	INK_Message(Client, "m_vecMaxsPreScaled %f %f %f", m_vecMaxsPreScaled[0], m_vecMaxsPreScaled[1], m_vecMaxsPreScaled[2]);
	
	new Float:m_vecMins[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecMins", m_vecMins);
	INK_Message(Client, "m_vecMins %f %f %f", m_vecMins[0], m_vecMins[1], m_vecMins[2]);
	
	new Float:m_vecMaxs[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecMaxs", m_vecMaxs);
	INK_Message(Client, "m_vecMaxs %f %f %f", m_vecMaxs[0], m_vecMaxs[1], m_vecMaxs[2]);
	
	new m_nSolidType = GetEntProp(Ent, Prop_Send, "m_nSolidType");
	INK_Message(Client, "m_nSolidType %d", m_nSolidType);
	
	new m_usSolidFlags = GetEntProp(Ent, Prop_Send, "m_usSolidFlags");
	INK_Message(Client, "m_usSolidFlags %d", m_usSolidFlags);
	
	new m_nSurroundType = GetEntProp(Ent, Prop_Send, "m_nSurroundType");
	INK_Message(Client, "m_nSurroundType %d", m_nSurroundType);
	
	new m_triggerBloat = GetEntProp(Ent, Prop_Send, "m_triggerBloat");
	INK_Message(Client, "m_triggerBloat %d", m_triggerBloat);
	
	new Float:m_vecSpecifiedSurroundingMinsPreScaled[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecSpecifiedSurroundingMinsPreScaled", m_vecSpecifiedSurroundingMinsPreScaled);
	INK_Message(Client, "m_vecSpecifiedSurroundingMinsPreScaled %f %f %f", m_vecSpecifiedSurroundingMinsPreScaled[0], m_vecSpecifiedSurroundingMinsPreScaled[1], m_vecSpecifiedSurroundingMinsPreScaled[2]);
	
	new Float:m_vecSpecifiedSurroundingMaxsPreScaled[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecSpecifiedSurroundingMaxsPreScaled", m_vecSpecifiedSurroundingMaxsPreScaled);
	INK_Message(Client, "m_vecSpecifiedSurroundingMaxsPreScaled %f %f %f", m_vecSpecifiedSurroundingMaxsPreScaled[0], m_vecSpecifiedSurroundingMaxsPreScaled[1], m_vecSpecifiedSurroundingMaxsPreScaled[2]);
	
	new Float:m_vecSpecifiedSurroundingMins[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecSpecifiedSurroundingMins", m_vecSpecifiedSurroundingMins);
	INK_Message(Client, "m_vecSpecifiedSurroundingMins %f %f %f", m_vecSpecifiedSurroundingMins[0], m_vecSpecifiedSurroundingMins[1], m_vecSpecifiedSurroundingMins[2]);
	
	new Float:m_vecSpecifiedSurroundingMaxs[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecSpecifiedSurroundingMaxs", m_vecSpecifiedSurroundingMaxs);
	INK_Message(Client, "m_vecSpecifiedSurroundingMaxs %f %f %f", m_vecSpecifiedSurroundingMaxs[0], m_vecSpecifiedSurroundingMaxs[1], m_vecSpecifiedSurroundingMaxs[2]);
	
	new m_nRenderFX = GetEntProp(Ent, Prop_Send, "m_nRenderFX");
	INK_Message(Client, "m_nRenderFX %d", m_nRenderFX);
	
	new m_nRenderMode = GetEntProp(Ent, Prop_Send, "m_nRenderMode");
	INK_Message(Client, "m_nRenderMode %d", m_nRenderMode);
	
	new m_fEffects = GetEntProp(Ent, Prop_Send, "m_fEffects");
	INK_Message(Client, "m_fEffects %d", m_fEffects);
	
	new m_clrRender = GetEntProp(Ent, Prop_Send, "m_clrRender");
	INK_Message(Client, "m_clrRender %d", m_clrRender);
	
	new m_iTeamNum = GetEntProp(Ent, Prop_Send, "m_iTeamNum");
	INK_Message(Client, "m_iTeamNum %d", m_iTeamNum);
	
	new m_CollisionGroup = GetEntProp(Ent, Prop_Send, "m_CollisionGroup");
	INK_Message(Client, "m_CollisionGroup %d", m_CollisionGroup);
	
	new Float:m_flElasticity = GetEntPropFloat(Ent, Prop_Send, "m_flElasticity");
	INK_Message(Client, "m_flElasticity %f", m_flElasticity);
	
	new Float:m_flShadowCastDistance = GetEntPropFloat(Ent, Prop_Send, "m_flShadowCastDistance");
	INK_Message(Client, "m_flShadowCastDistance %f", m_flShadowCastDistance);
	
	new m_hOwnerEntity = GetEntProp(Ent, Prop_Send, "m_hOwnerEntity");
	INK_Message(Client, "m_hOwnerEntity %d", m_hOwnerEntity);
	
	new m_hEffectEntity = GetEntProp(Ent, Prop_Send, "m_hEffectEntity");
	INK_Message(Client, "m_hEffectEntity %d", m_hEffectEntity);
	
	new moveparent = GetEntProp(Ent, Prop_Send, "moveparent");
	INK_Message(Client, "moveparent %d", moveparent);
	
	new m_iParentAttachment = GetEntProp(Ent, Prop_Send, "m_iParentAttachment");
	INK_Message(Client, "m_iParentAttachment %d", m_iParentAttachment);
	
	new movetype = GetEntProp(Ent, Prop_Send, "movetype");
	INK_Message(Client, "movetype %d", movetype);
	
	new movecollide = GetEntProp(Ent, Prop_Send, "movecollide");
	INK_Message(Client, "movecollide %d", movecollide);
	
	new Float:m_angRotation[3];
	GetEntPropVector(Ent, Prop_Send, "m_angRotation", m_angRotation);
	INK_Message(Client, "m_angRotation %f %f %f", m_angRotation[0], m_angRotation[1], m_angRotation[2]);
	
	new m_iTextureFrameIndex = GetEntProp(Ent, Prop_Send, "m_iTextureFrameIndex");
	INK_Message(Client, "m_iTextureFrameIndex %d", m_iTextureFrameIndex);
	
	new m_PredictableID = GetEntProp(Ent, Prop_Send, "m_PredictableID");
	INK_Message(Client, "m_PredictableID %d", m_PredictableID);
	
	new m_bIsPlayerSimulated = GetEntProp(Ent, Prop_Send, "m_bIsPlayerSimulated");
	INK_Message(Client, "m_bIsPlayerSimulated %d", m_bIsPlayerSimulated);
	
	new m_bSimulatedEveryTick = GetEntProp(Ent, Prop_Send, "m_bSimulatedEveryTick");
	INK_Message(Client, "m_bSimulatedEveryTick %d", m_bSimulatedEveryTick);
	
	new m_bAnimatedEveryTick = GetEntProp(Ent, Prop_Send, "m_bAnimatedEveryTick");
	INK_Message(Client, "m_bAnimatedEveryTick %d", m_bAnimatedEveryTick);
	
	new m_bAlternateSorting = GetEntProp(Ent, Prop_Send, "m_bAlternateSorting");
	INK_Message(Client, "m_bAlternateSorting %d", m_bAlternateSorting);
	
	new m_nForceBone = GetEntProp(Ent, Prop_Send, "m_nForceBone");
	INK_Message(Client, "m_nForceBone %d", m_nForceBone);
	
	new Float:m_vecForce[3];
	GetEntPropVector(Ent, Prop_Send, "m_vecForce", m_vecForce);
	INK_Message(Client, "m_vecForce %f %f %f", m_vecForce[0], m_vecForce[1], m_vecForce[2]);
	
	new m_nSkin = GetEntProp(Ent, Prop_Send, "m_nSkin");
	INK_Message(Client, "m_nSkin %d", m_nSkin);
	
	new m_nBody = GetEntProp(Ent, Prop_Send, "m_nBody");
	INK_Message(Client, "m_nBody %d", m_nBody);
	
	new m_nHitboxSet = GetEntProp(Ent, Prop_Send, "m_nHitboxSet");
	INK_Message(Client, "m_nHitboxSet %d", m_nHitboxSet);
	
	new Float:m_flModelScale = GetEntPropFloat(Ent, Prop_Send, "m_flModelScale");
	INK_Message(Client, "m_flModelScale %f", m_flModelScale);
	
	new m_nSequence = GetEntProp(Ent, Prop_Send, "m_nSequence");
	INK_Message(Client, "m_nSequence %d", m_nSequence);
	
	new Float:m_flPlaybackRate = GetEntPropFloat(Ent, Prop_Send, "m_flPlaybackRate");
	INK_Message(Client, "m_flPlaybackRate %f", m_flPlaybackRate);
	
	new m_bClientSideAnimation = GetEntProp(Ent, Prop_Send, "m_bClientSideAnimation");
	INK_Message(Client, "m_bClientSideAnimation %d", m_bClientSideAnimation);
	
	new m_bClientSideFrameReset = GetEntProp(Ent, Prop_Send, "m_bClientSideFrameReset");
	INK_Message(Client, "m_bClientSideFrameReset %d", m_bClientSideFrameReset);
	
	new m_nNewSequenceParity = GetEntProp(Ent, Prop_Send, "m_nNewSequenceParity");
	INK_Message(Client, "m_nNewSequenceParity %d", m_nNewSequenceParity);
	
	new m_nResetEventsParity = GetEntProp(Ent, Prop_Send, "m_nResetEventsParity");
	INK_Message(Client, "m_nResetEventsParity %d", m_nResetEventsParity);
	
	new m_nMuzzleFlashParity = GetEntProp(Ent, Prop_Send, "m_nMuzzleFlashParity");
	INK_Message(Client, "m_nMuzzleFlashParity %d", m_nMuzzleFlashParity);
	
	new m_hLightingOrigin = GetEntProp(Ent, Prop_Send, "m_hLightingOrigin");
	INK_Message(Client, "m_hLightingOrigin %d", m_hLightingOrigin);
	
	new m_hLightingOriginRelative = GetEntProp(Ent, Prop_Send, "m_hLightingOriginRelative");
	INK_Message(Client, "m_hLightingOriginRelative %d", m_hLightingOriginRelative);
	
	new Float:m_flCycle = GetEntPropFloat(Ent, Prop_Send, "m_flCycle");
	INK_Message(Client, "m_flCycle %f", m_flCycle);
	
	new Float:m_fadeMinDist = GetEntPropFloat(Ent, Prop_Send, "m_fadeMinDist");
	INK_Message(Client, "m_fadeMinDist %f", m_fadeMinDist);
	
	new Float:m_fadeMaxDist = GetEntPropFloat(Ent, Prop_Send, "m_fadeMaxDist");
	INK_Message(Client, "m_fadeMaxDist %f", m_fadeMaxDist);
	
	new Float:m_flFadeScale = GetEntPropFloat(Ent, Prop_Send, "m_flFadeScale");
	INK_Message(Client, "m_flFadeScale %f", m_flFadeScale);
	
	
	
	return Plugin_Handled;
}

/* public Action:Command_CreatePropSQL(Args)
{
	if(FileExists(PropPath))
	{
		new Handle:hPropKv = CreateKeyValues("House");
		FileToKeyValues(hPropKv, PropPath);
		INK_CreatePropSQL(hPropKv);
		CloseHandle(hPropKv);
	}
}

stock INK_CreatePropSQL(Handle:kv)
{
	do
	{
		if(KvGotoFirstSubKey(kv, false))
		{
			INK_CreatePropSQL(kv);
			KvGoBack(kv);
		}
		else if(KvGetDataType(kv, NULL_STRING) != KvData_None)
		{
			decl String:sPropName[128];
			KvGetSectionName(kv, sPropName, sizeof(sPropName));
			
			decl String:sPropString[128];
			KvGetString(kv, NULL_STRING, sPropString, sizeof(sPropString));
			
			decl String:sPropBuffer[2][128];
			ExplodeString(sPropString, "^", sPropBuffer, 2, sizeof(sPropBuffer[]));
			
			Format(sPropString, sizeof(sPropString), "%s^%s", sPropName, sPropString);
			
			new data = Array_FindString(g_sDataString, sizeof(g_sDataString), "");
			strcopy(g_sDataString[data], sizeof(g_sDataString[]), sPropString);
			
			decl String:Query[256];
			Format(Query, sizeof(Query), "SELECT * FROM `props_list` WHERE `Path` = '%s' LIMIT 0,1", sPropBuffer[0]);
			SQL_TQuery(g_hBuildDB, DB_CheckPropData, Query, data);
		}
	}
	while(KvGotoNextKey(kv, false));
} */

/* public Action:Command_GenPropDB(Args)
{
	new String:Arg1[256];
	GetCmdArg(1, Arg1, sizeof(Arg1));
	INK_SearchForMDL("models", Arg1);
	
	PrintToServer("[INK-SQL] FINISHED GENERATING PROP DB.");
	
	return Plugin_Handled;
}

stock INK_SearchForMDL(const String:Directory[], const String:Start[])
{
	decl String:FileName[128], String:Path[512];
	new Handle:Dir = OpenDirectory(Directory), FileType:Type;
	while(ReadDirEntry(Dir, FileName, sizeof(FileName), Type))
	{
		if(StrEqual(FileName, "", false) || StrEqual(FileName, ".", false) || StrEqual(FileName, "..",false))
			continue;
		
		if(Type == FileType_File)
		{
			if(StrContains(FileName, ".mdl", false) != -1)
			{
				if(StrContains(FileName, Start, false) != -1 || StrEqual(Start, ""))
				{
					g_bStartPropData = true;
					
					if(!StrEqual(Start, ""))
						continue;
				}
				
				if(!g_bStartPropData)
					continue;
				
				Format(Path, sizeof(Path), "%s/%s", Directory, FileName);
				
				decl String:Query[512];
				Format(Query, sizeof(Query), "SELECT * FROM `props_list` WHERE `Path` = '%s' LIMIT 0,1", Path);
				
				new data = Array_FindString(g_sDataString, sizeof(g_sDataString), "");
				if(data != -1)
				{
					strcopy(g_sDataString[data], sizeof(g_sDataString[]), Path);
					SQL_TQuery(g_hBuildDB, DB_CheckPropData, Query, data);
				}
			}
		}
		else
		{
			Format(FileName, sizeof(FileName), "%s/%s", Directory, FileName);
			
			if(DirExists(FileName))
				INK_SearchForMDL(FileName, Start);
		}
	}
	
	return;
} */

public Action:Command_Noclip(Client, Args)
{
	decl Float:vecClientPos[3];
	GetClientAbsOrigin(Client, vecClientPos);
	
	new iLand = INK_GetLand(vecClientPos);
	
	if(iLand > 0 && iLand != Client && g_bStopFly[iLand])
	{
		SetEntityMoveType(Client, MOVETYPE_WALK);
		INK_Message(Client, "You are not allowed to fly inside this land.");
		
		return Plugin_Handled;
	}
	
	new MoveType:mType = GetEntityMoveType(Client);
	
	if(mType != MOVETYPE_NOCLIP && GetConVarBool(sv_ink_globalfly))
		SetEntityMoveType(Client, MOVETYPE_NOCLIP);
	else SetEntityMoveType(Client, MOVETYPE_WALK);
	
	return Plugin_Handled;
}

/************************************************************************************/
/*									  --  (Hooks)  --								*/
/************************************************************************************/


public Action:DollTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(INK_GetOwner(victim) != attacker)
		return Plugin_Handled;
	
	if(!Entity_HasSpawnFlags(victim, 256))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:ClientTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	new iVictimLand;
	if(victim >= 1 && victim <= MaxClients)
	{
		decl Float:vecVictimPos[3];
		GetClientAbsOrigin(victim, vecVictimPos);
		
		iVictimLand = INK_GetLand(vecVictimPos);
	}
	
	new iAttackerLand;
	if(attacker >= 1 && attacker <= MaxClients)
	{
		decl Float:vecAttackerPos[3];
		GetClientAbsOrigin(attacker, vecAttackerPos);
		
		iAttackerLand = INK_GetLand(vecAttackerPos);
	}
	
	new bool:bGlobalGod = GetConVarBool(sv_ink_globalgod);
		
	if(damage < 0)
		return Plugin_Continue;
	
	if(iVictimLand != iAttackerLand && (attacker >= 1 || attacker <= MaxClients))
		return Plugin_Handled;
	
	else if((!g_bDeathmatch[iVictimLand] && iVictimLand > 0) || (bGlobalGod && iVictimLand == 0))
	{
		if(victim == attacker)
		{
			SetEntProp(victim, Prop_Data, "m_takedamage", 1, 1);
			return Plugin_Continue;
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:ClientTakeDamagePost(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{
	if(GetEntProp(victim, Prop_Data, "m_takedamage", 1) == 1)
		SetEntProp(victim, Prop_Data, "m_takedamage", 2, 1);
}

public OnEntTouch(Ent, Client)
{
	if(0 < Client <= MaxClients)
	{
		if(IsClientInGame(Client))
		{
			if(!IsValidEntity(Ent))
				return;
			
			if(!Entity_HasSpawnFlags(Ent, 256))
				return;
			
			INK_ActivateEnt(Client, Ent);
		}
	}
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(buttons & IN_USE)
	{
		g_iUseClient = Client;
		
		// if game is TF2:
		if(g_iAppID == 440)
		{
			if(!g_bInUse[Client])
			{
				g_bInUse[Client] = true;
				
				new Ent = INK_AimTarget(Client);
				if(Ent != -1)
				{
					new bool:bLocked = !Entity_HasSpawnFlags(Ent, 256);
					if(bLocked)
					{
						decl String:sEntClass[32];
						GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
						
						if(StrEqual(sEntClass, "cel_door", false))
							bLocked = (GetEntProp(Ent, Prop_Data, "m_bLocked") == 1);
					}
					
					if(!bLocked)
					{
						decl Float:vecAimPos[3];
						INK_AimPosition(Client, vecAimPos);
						
						decl Float:vecClientPos[3];
						GetClientEyePosition(Client, vecClientPos);
						
						if(GetVectorDistance(vecClientPos, vecAimPos) <= 100)
						{
							INK_ActivateEnt(Client, Ent);
							EmitSoundToClient(Client, "common/wpn_select.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO);
						}
					}
					else EmitSoundToClient(Client, "common/wpn_denyselect.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO);
				}
				else EmitSoundToClient(Client, "common/wpn_denyselect.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO);
			}
		}
		
		if(g_eCamera[Client] != 0)
		{
			if(IsValidEntity(g_eCamera[Client]))
			{
				if(g_fCameraTime[Client] <= GetGameTime() - 0.4)
				{
					decl String:sClientTarget[16];
					Format(sClientTarget, sizeof(sClientTarget), "client_%d", Client);
					
					DispatchKeyValue(Client, "targetname", sClientTarget); 
					
					SetVariantString(sClientTarget); 
					AcceptEntityInput(g_eCamera[Client], "Disable", Client, g_eCamera[Client]);
					
					g_eCamera[Client] = 0;
					g_fCameraTime[Client] = GetGameTime();
				}
			}
			else g_eCamera[Client] = 0;
		}
	}
	else g_bInUse[Client] = false;
}

public HookActivate(String:output[], caller, activator, Float:delay)
{
	if(g_fUseTime[activator] < GetGameTime() - 0.5)
	{
		g_fUseTime[activator] = GetGameTime();
		
		new Client = g_iUseClient;
		g_iUseClient = 0;
		
		INK_ActivateEnt(Client, activator);
	}
}

public Action:EventDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl Float:vecClientPos[3];
	GetClientAbsOrigin(Client, vecClientPos);
	g_iDeathLand[Client] = INK_GetLand(vecClientPos);
	
	if(g_eCamera[Client] != 0)
	{
		if(IsValidEntity(g_eCamera[Client]))
		{
			decl String:sClientTarget[16];
			Format(sClientTarget, sizeof(sClientTarget), "client_%d", Client);
			
			DispatchKeyValue(Client, "targetname", sClientTarget); 
			
			SetVariantString(sClientTarget); 
			AcceptEntityInput(g_eCamera[Client], "Disable", Client, g_eCamera[Client]);
			
			g_eCamera[Client] = 0;
			g_fCameraTime[Client] = GetGameTime();
		}
		else g_eCamera[Client] = 0;
	}
}

public Action:EventSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsPlayerAlive(Client))
	{
		// If game == TF2
		if(g_iAppID == 440)
		{
			SetEntPropFloat(Client, Prop_Send, "m_flModelScale", 0.9);
		}
	}
}


/************************************************************************************/
/*								  --  (Misc Timers)  --								*/
/************************************************************************************/


public Action:DelayDissolve(Handle:timer, any:data)
{
	if(IsValidEntity(InkDissolver))
	{
		decl String:sEntClass[32];
		GetEntityClassname(InkDissolver, sEntClass, sizeof(sEntClass));
		
		if(!StrEqual(sEntClass, "env_entity_dissolver", false))
		{
			InkDissolver = CreateEntityByName("env_entity_dissolver");
			
			DispatchKeyValue(InkDissolver, "target", "deleted");
			DispatchKeyValue(InkDissolver, "magnitude", "0");
			DispatchKeyValue(InkDissolver, "dissolvetype", "3");
			
			DispatchSpawn(InkDissolver);
		}
	}
	else
	{
		InkDissolver = CreateEntityByName("env_entity_dissolver");
		
		DispatchKeyValue(InkDissolver, "target", "deleted");
		DispatchKeyValue(InkDissolver, "magnitude", "0");
		DispatchKeyValue(InkDissolver, "dissolvetype", "3");
		
		DispatchSpawn(InkDissolver);
	}
	
	AcceptEntityInput(InkDissolver, "dissolve");
}

public Action:DelayRemove(Handle:timer, any:Ent)
{
	AcceptEntityInput(Ent, "Kill");
}

public Action:DelayActivate(Handle:timer, any:pack)
{
	ResetPack(pack);
	new Ent = ReadPackCell(pack);
	new Target = ReadPackCell(pack);
	
	INK_ActivateEnt(Ent, Target);
}

public Action:DelayLock(Handle:timer, any:Ent)
{
	decl String:sTargetClass[64];
	GetEntityClassname(Ent, sTargetClass, sizeof(sTargetClass));
	
	if(StrEqual(sTargetClass, "cel_door", false))
	{
		if(GetEntProp(Ent, Prop_Data, "m_bLocked") == 1)
			AcceptEntityInput(Ent, "Unlock");
		else AcceptEntityInput(Ent, "Lock");
	}
	else if(StrContains(sTargetClass, "cel_", false) == 0)
	{
		if(Entity_HasSpawnFlags(Ent, 256))
			Entity_RemoveSpawnFlags(Ent, 256);
		else Entity_AddSpawnFlags(Ent, 256);
	}
}

public Action:DelayBreak(Handle:timer, any:Ent)
{
	SetEntProp(Ent, Prop_Data, "m_takedamage", 2, 1);
					
	INK_RemoveEnt(Ent, false);
	AcceptEntityInput(Ent, "break");
}

public Action:DelaySolid(Handle:timer, any:Ent)
{
	new solidity = GetEntProp(Ent, Prop_Send, "m_nSolidType", 1);
					
	if(solidity == 6)
		DispatchKeyValue(Ent, "solid", "4");
	
	else DispatchKeyValue(Ent, "solid", "6");
}

public Action:KillUseTimer(Handle:timer, any:Ent)
{
	g_hUseTimer[Ent] = INVALID_HANDLE;
}


// Executed for each entity shortly after loading. Allows for welding/teleports/buttons/etc.
public Action:FixRelation(Handle:timer, any:pack)
{
	ResetPack(pack);
	new Ent = ReadPackCell(pack);
	new iWeldEnt = ReadPackCell(pack);
	
	decl String:sEntClass[32];
	GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
	
	new bool:bWelded;
	if(iWeldEnt > 0) bWelded = true;
	
	new bool:bTeleport, bool:bButton;
	if(StrEqual(sEntClass, "cel_teleport", false)) bTeleport = true;
	else if(StrEqual(sEntClass, "cel_button", false) || StrEqual(sEntClass, "cel_trigger", false)) bButton = true;
	
	// if entity is welded, is a teleport, or button:
	if(bWelded || bTeleport || bButton)
	{
		decl String:sEntTarget[32];
		GetEntPropString(Ent, Prop_Data, "m_target", sEntTarget, sizeof(sEntTarget));
		
		new Owner = INK_GetOwner(Ent);
		
		decl String:sEntName[90], String:sNameArray[2][32];
		GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
		ExplodeString(sEntName, "^", sNameArray, 2, sizeof(sNameArray[]));
		
		decl String:sEName[40], String:sENameArray[2][32], String:sTargetArray[6][32], String:sEntIndex[8];
		
		// Loop through entities:
		new iMaxEnts = GetMaxEntities();
		for(new E = MaxClients + 1; E <= iMaxEnts; E++)
		{
			if(IsValidEntity(E))
			{
				if(INK_GetOwner(E) == Owner)
				{
					GetEntPropString(E, Prop_Data, "m_iName", sEName, sizeof(sEName));
					ExplodeString(sEName, "^", sENameArray, 2, sizeof(sENameArray[]));
					
					if(StrEqual(sNameArray[1], sENameArray[1], false))
					{
						if(bWelded)
						{
							if(StringToInt(sENameArray[0]) == iWeldEnt)
								Entity_SetParent(Ent, E);
						}
						
						if(bTeleport)
						{
							if(StringToInt(sENameArray[0]) == StringToInt(sEntTarget))
							{
								IntToString(E, sEntTarget, sizeof(sEntTarget));
								DispatchKeyValue(Ent, "target", sEntTarget);
							}
						}
						
						else if(bButton)
						{
							ExplodeString(sEntTarget, "^", sTargetArray, 6, sizeof(sTargetArray[]));
							IntToString(E, sEntIndex, sizeof(sEntIndex));
							
							for(new x; x < 6; x++)
							{
								if(StringToInt(sENameArray[0]) == StringToInt(sTargetArray[x]))
								{
									ReplaceString(sEntTarget, sizeof(sEntTarget), sTargetArray[x], sEntIndex);
									DispatchKeyValue(Ent, "target", sEntTarget);
								}
							}
						}
					}
				}
			}
		}
	}
	
	return Plugin_Handled;
}

/************************************************************************************/
/*								--  (Natives & Stocks)  --							*/
/************************************************************************************/


// INK_SetOwner(Ent, Client, bool:clear = true)
public Native_INK_SetOwner(Handle:plugin, numParams)
{
	new Ent = GetNativeCell(1);
	new Client = GetNativeCell(2);
	new bool:clear = GetNativeCell(3);
	
	if(MaxClients >= Client > 0)
	{
		if(IsClientInGame(Client))
		{
			decl String:sGlobalName[4];
			IntToString(Client, sGlobalName, sizeof(sGlobalName));
			DispatchKeyValue(Ent, "globalname", sGlobalName);
			
			decl String:sEntName[90], String:sNameArray[3][32];
			GetEntPropString(Ent, Prop_Data, "m_iName", sEntName, sizeof(sEntName));
			ExplodeString(sEntName, "^", sNameArray, 3, sizeof(sNameArray[]));
			
			if(StrEqual(sEntName, ""))
			{
				Format(sEntName, sizeof(sEntName), "%d^^%s", Ent, g_sClientAuth[Client]);
				DispatchKeyValue(Ent, "targetname", sEntName);
			}
			// Clear entity from save:
			else if(!StrEqual(sNameArray[1], "") && !StrEqual(sNameArray[2], g_sClientAuth[Client], false))
			{
				new Handle:hClearKv = CreateKeyValues("Build");
				
				decl String:sClearPath[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, sClearPath, sizeof(sClearPath), "data/ink_build/saves/%s/%s.txt", sNameArray[2], sNameArray[1]);
				
				FileToKeyValues(hClearKv, sClearPath);
				
				if(KvJumpToKey(hClearKv, sNameArray[0]))
					KvDeleteThis(hClearKv);
				
				KvRewind(hClearKv);
				KeyValuesToFile(hClearKv, sClearPath);
				
				if(!KvGotoFirstSubKey(hClearKv, false))
					DeleteFile(sClearPath);
				
				CloseHandle(hClearKv);
				
				Format(sEntName, sizeof(sEntName), "%d^^%s", Ent, g_sClientAuth[Client]);
				DispatchKeyValue(Ent, "targetname", sEntName);
			}
			
			return true;
		}
	}
	
	if(clear)
	{
		new String:sClearGlobal[2];
		DispatchKeyValue(Ent, "globalname", sClearGlobal);
	}
	
	return false;
}

// INK_GetOwner(Ent)
public Native_INK_GetOwner(Handle:plugin, numParams)
{
	new Ent = GetNativeCell(1);
	
	new String:sGlobalName[4];
	GetEntPropString(Ent, Prop_Data, "m_iGlobalname", sGlobalName, sizeof(sGlobalName));
	
	return StringToInt(sGlobalName);
}

// INK_GetPropCount(Client)
public Native_INK_GetPropCount(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new Count;
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				decl String:sEntClass[16];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrContains(sEntClass, "prop_", false) == 0)
					Count++;
			}
		}
	}
	
	return Count;
}

// INK_GetCelCount(Client)
public Native_INK_GetCelCount(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new Count;
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				decl String:sEntClass[16];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrContains(sEntClass, "cel_", false) == 0)
					Count++;
			}
		}
	}
	
	return Count;
}

// INK_GetCelCount(Client)
public Native_INK_GetLightCount(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new Count;
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				decl String:sEntClass[16];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrEqual(sEntClass, "cel_light", false))
					Count++;
			}
		}
	}
	
	return Count;
}

// INK_GetBitCount(Client)
public Native_INK_GetBitCount(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new Count;
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
			{
				decl String:sEntClass[16];
				GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
				
				if(StrContains(sEntClass, "bit_", false) == 0)
					Count++;
			}
		}
	}
	
	return Count;
}

// INK_GetTotalCount(Client)
public Native_INK_GetTotalCount(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new Count;
	
	new iMaxEnts = GetMaxEntities();
	for(new Ent = MaxClients + 1; Ent <= iMaxEnts; Ent++)
	{
		if(IsValidEntity(Ent))
		{
			if(INK_GetOwner(Ent) == Client)
				Count++;
		}
	}
	
	return Count;
}

// INK_RemoveEnt(Ent, bool:dissolve = true, Float:delay = 0.1)
public Native_INK_RemoveEnt(Handle:plugin, numParams)
{
	new Ent = GetNativeCell(1);
	new bool:dissolve = GetNativeCell(2);
	new Float:delay = GetNativeCell(3);
	
	decl String:sEntClass[32];
	GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
	
	// Unweld children:
	new eChild = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
	if(StrContains(sEntClass, "prop_physics", false) == 0)
	{
		while(IsValidEntity(eChild))
		{
			Entity_RemoveParent(eChild);
			eChild = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
		}
	}
	
	decl String:sTarget[192], String:sLinkArray[6][8];
	
	// Stop sound/music:
	if(StrEqual(sEntClass, "cel_music", false) || StrEqual(sEntClass, "cel_sound", false))
	{
		GetEntPropString(Ent, Prop_Data, "m_target", sTarget, sizeof(sTarget));
		
		decl String:sMusicArray[2][128];
		ExplodeString(sTarget, "^", sMusicArray, 2, sizeof(sMusicArray[]));
		
		StopSound(Ent, SNDCHAN_AUTO, sMusicArray[0]);
		
		ClearTimer(g_hUseTimer[Ent]);
		
		g_fUseTime[Ent] = 0.0;
	}
	
	else if(StrEqual(sEntClass, "cel_teleport", false))
	{
		GetEntPropString(Ent, Prop_Data, "m_target", sTarget, sizeof(sTarget));
		new EntDest = StringToInt(sTarget);
		if(EntDest == 0) EntDest = -1;
		
		if(IsValidEntity(EntDest))
		{
			DispatchKeyValue(EntDest, "target", "");
			INK_RemoveEnt(EntDest, false);
		}
	}
	
	// Unhook button:
	new iMaxEnts = GetMaxEntities();
	for(new E = MaxClients + 1; E <= iMaxEnts; E++)
	{
		if(IsValidEntity(E))
		{
			if(INK_GetOwner(E) == INK_GetOwner(Ent))
			{
				decl String:sEClass[32];
				GetEntityClassname(E, sEClass, sizeof(sEClass));
				if(StrEqual(sEClass, "cel_button", false) || StrEqual(sEClass, "cel_trigger", false))
				{
					GetEntPropString(E, Prop_Data, "m_target", sTarget, sizeof(sTarget));
					ExplodeString(sTarget, "^", sLinkArray, 6, sizeof(sLinkArray[]));
					
					for(new x; x < 6; x++)
					{
						if(StringToInt(sLinkArray[x]) == Ent)
						{
							ReplaceString(sTarget, sizeof(sTarget), sLinkArray[x], "0");
							DispatchKeyValue(E, "target", sTarget);
						}
					}
				}
				else if(StrEqual(sEClass, "cel_link", false))
				{
					GetEntPropString(E, Prop_Data, "m_target", sTarget, sizeof(sTarget));
					ExplodeString(sTarget, "^", sLinkArray, 2, sizeof(sLinkArray[]));
					
					if(StringToInt(sLinkArray[1]) == Ent)
					{
						ReplaceString(sTarget, sizeof(sTarget), sLinkArray[1], "0");
						DispatchKeyValue(E, "target", sTarget);
					}
				}
			}
		}
	}
	
	g_fUseTime[Ent] = 0.0;
	
	// Dissolve/kill:
	if(dissolve)
	{
		DispatchKeyValue(Ent, "targetname", "deleted");
		CreateTimer(delay, DelayDissolve);
	}
	else CreateTimer(delay, DelayRemove, Ent);
}

// INK_EntToString(Ent, String:sEntString[], size, const Float:vecCenterPos[3] = {0.0, 0.0, 0.0})
public Native_INK_EntToString(Handle:plugin, numParam)
{
	new Ent = GetNativeCell(1);
	new len = GetNativeCell(3);
	
	if(len <= 0) return;
	
	decl String:sEntArray[20][256];
	GetEntityClassname(Ent, sEntArray[0], sizeof(sEntArray[]));
	
	new String:sEntString[len];
	
	decl Float:vecCenterPos[3];
	GetNativeArray(4, vecCenterPos, 3);
	
	if(StrContains(sEntArray[0], "prop_physics", false) == 0
	|| StrContains(sEntArray[0], "cel_", false) == 0
	|| StrContains(sEntArray[0], "bit_", false) == 0)
	{
		// Classname:
		if(StrEqual(sEntArray[0], "prop_physics_breakable", false))
			strcopy(sEntArray[0], sizeof(sEntArray[]), "prop_physics_override");
		
		// Model:
		GetEntPropString(Ent, Prop_Data, "m_ModelName", sEntArray[1], sizeof(sEntArray[]));
		
		// Spawnflags:
		new iSpawnFlags = GetEntProp(Ent, Prop_Data, "m_spawnflags", 1);
		IntToString(iSpawnFlags, sEntArray[2], sizeof(sEntArray[]));
		
		// Render:
		new iRenderFx = GetEntProp(Ent, Prop_Send, "m_nRenderFX", 1);
		IntToString(iRenderFx, sEntArray[3], sizeof(sEntArray[]));
		
		// Scale:
		new Float:fScale = GetEntPropFloat(Ent, Prop_Send, "m_flModelScale");
		FloatToString(fScale, sEntArray[4], sizeof(sEntArray[]));
		
		// Solidity:
		new iSolidity = GetEntProp(Ent, Prop_Send, "m_nSolidType", 1);
		IntToString(iSolidity, sEntArray[5], sizeof(sEntArray[]));
		
		// TakeDamage:
		new iDamage = GetEntProp(Ent, Prop_Data, "m_takedamage", 1);
		IntToString(iDamage, sEntArray[6], sizeof(sEntArray[]));
		
		// Movetype:
		new iMoveOff = GetEntSendPropOffs(Ent, "movetype");
		new iMovetype = GetEntData(Ent, iMoveOff, 1);
		IntToString(iMovetype, sEntArray[7], sizeof(sEntArray[]));
		
		// Skin:
		new iSkin = GetEntProp(Ent, Prop_Send, "m_nSkin", 1);
		IntToString(iSkin, sEntArray[8], sizeof(sEntArray[]));
		
		// Bodygroup:
		new iBodyGroup = GetEntProp(Ent, Prop_Send, "m_nBody");
		IntToString(iBodyGroup, sEntArray[9], sizeof(sEntArray[]));
		
		// Color:
		new iColorOff = GetEntSendPropOffs(Ent, "m_clrRender"), iColor[4];
		iColor[0] = GetEntData(Ent, iColorOff, 1);
		iColor[1] = GetEntData(Ent, iColorOff + 1, 1);
		iColor[2] = GetEntData(Ent, iColorOff + 2, 1);
		iColor[3] = GetEntData(Ent, iColorOff + 3, 1);
		Format(sEntArray[10], sizeof(sEntArray[]), "%d %d %d %d", iColor[0], iColor[1], iColor[2], iColor[3]);
		
		// Parenting:
		new iParent = GetEntPropEnt(Ent, Prop_Data, "m_pParent");
		IntToString(iParent, sEntArray[11], sizeof(sEntArray[]));
		
		// Position:
		decl Float:vecEntPos[3];
		INK_GetEntPos(Ent, vecEntPos);
		SubtractVectors(vecEntPos, vecCenterPos, vecEntPos);
		
		Format(sEntArray[12], sizeof(sEntArray[]), "%f %f %f", vecEntPos[0], vecEntPos[1], vecEntPos[2]);
		
		// Angle:
		decl Float:vecEntAng[3];
		INK_GetEntAng(Ent, vecEntAng);
		Format(sEntArray[13], sizeof(sEntArray[]), "%f %f %f", vecEntAng[0], vecEntAng[1], vecEntAng[2]);
		
		// Data String:
		
		// We get an error when trying to access this property on a cycler. WHY?!
		if(StrEqual(sEntArray[0], "cel_doll", false))
			strcopy(sEntArray[14], sizeof(sEntArray[]), "");
		else
			GetEntPropString(Ent, Prop_Data, "m_target", sEntArray[14], sizeof(sEntArray[]));
		
		if(StrEqual(sEntArray[0], "cel_light", false))
		{
			new EntLight = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
			
			// Light distance:
			new Float:iDistance = GetEntPropFloat(EntLight, Prop_Data, "m_Radius");
			IntToString(RoundFloat(iDistance), sEntArray[15], sizeof(sEntArray[]));
			
			// Light style:
			new iStyle = GetEntProp(EntLight, Prop_Send, "m_LightStyle", 1);
			IntToString(iStyle, sEntArray[16], sizeof(sEntArray[]));
			
			ImplodeStrings(sEntArray, 17, "|", sEntString, len);
		}
		else if(StrEqual(sEntArray[0], "cel_door", false))
		{
			// Hardware:
			new iHardware = GetEntProp(Ent, Prop_Data, "m_nHardwareType");
			IntToString(iHardware, sEntArray[15], sizeof(sEntArray[]));
			
			// Locked
			new iLocked = GetEntProp(Ent, Prop_Data, "m_bLocked");
			IntToString(iLocked, sEntArray[16], sizeof(sEntArray[]));
			
			ImplodeStrings(sEntArray, 17, "|", sEntString, len);
		}
		else if(StrEqual(sEntArray[0], "cel_doll", false))
		{
			new iAnim = GetEntProp(Ent, Prop_Send, "m_nSequence");
			IntToString(iAnim, sEntArray[15], sizeof(sEntArray[]));
			
			ImplodeStrings(sEntArray, 16, "|", sEntString, len);
		}
		else ImplodeStrings(sEntArray, 15, "|", sEntString, len);
	}
	
	// classname|model|flags|renderfx|scale|solidity|takedamage|movetype|skin|bodygroup|color|parenting|position|angle|data
	SetNativeString(2, sEntString, len);
}

// INK_StringToEnt(const String:sEntString[], const Float:vecCenterPos[3] = {0.0, 0.0, 0.0})
public Native_INK_StringToEnt(Handle:plugin, numParam)
{
	decl String:sEntString[256];
	GetNativeString(1, sEntString, sizeof(sEntString));
	
	decl String:sEntArray[20][64];
	ExplodeString(sEntString, "|", sEntArray, 20, sizeof(sEntArray[]));
	
	decl Float:vecCenterPos[3];
	GetNativeArray(2, vecCenterPos, 3);
	
	new isloading = GetNativeCell(3);
	new Ent = -1;
	
	// Classname:
	if(StrEqual(sEntArray[0], "cel_door", false))
		Ent = CreateEntityByName("prop_door_rotating");
	
	else if(StrEqual(sEntArray[0], "cel_doll", false))
		Ent = CreateEntityByName("cycler");
	
	else if(StrEqual(sEntArray[0], "bit_ammocrate", false))
		Ent = CreateEntityByName("item_ammo_crate");
	
	else if(StrEqual(sEntArray[0], "bit_charger", false))
	{
		if(StrEqual(sEntArray[2], "health", false))
			Ent = CreateEntityByName("item_healthcharger");
		else if(StrEqual(sEntArray[2], "suit", false))
			Ent = CreateEntityByName("item_suitcharger");
	}
	
	else if(StrContains(sEntArray[0], "prop_physics", false) == 0
	|| StrContains(sEntArray[0], "cel_", false) == 0
	|| StrContains(sEntArray[0], "bit_", false) == 0)
		Ent = CreateEntityByName("prop_physics_override");
	
	if(Ent != -1)
	{
		if(StrContains(sEntArray[0], "prop_physics", false) == -1)
			DispatchKeyValue(Ent, "classname", sEntArray[0]);
		
		// Model:
		PrecacheModel(sEntArray[1]);
		DispatchKeyValue(Ent, "model", sEntArray[1]);
		
		// Spawnflags:
		DispatchKeyValue(Ent, "spawnflags", sEntArray[2]);
		
		// Render:
		DispatchKeyValue(Ent, "renderfx", sEntArray[3]);
		
		// Apply door properties:
		if(StrEqual(sEntArray[0], "cel_door", false))
		{
			DispatchKeyValue(Ent, "distance", "90");
			DispatchKeyValue(Ent, "speed", "100");
			DispatchKeyValue(Ent, "dmg", "20");
			DispatchKeyValue(Ent, "opendir", "0");
			
			DispatchKeyValue(Ent, "returndelay", "-1");
			DispatchKeyValue(Ent, "forceclosed", "1");
			DispatchKeyValue(Ent, "OnFullyOpen", "!caller,close,,3,-1");
			
			DispatchKeyValue(Ent, "hardware", sEntArray[15]);
			DispatchKeyValue(Ent, "angles", sEntArray[13]);
			
			if(StringToInt(sEntArray[15]) == 1)
				AcceptEntityInput(Ent, "Lock");
		}
		else if(StrEqual(sEntArray[0], "bit_ammocrate", false))
		{
			DispatchKeyValue(Ent, "AmmoType", sEntArray[14]);
		}
		
		// Scale:
		DispatchKeyValue(Ent, "modelscale", sEntArray[4]);
		
		// Spawn ent:
		DispatchSpawn(Ent);
		
		// Solidity:
		SetEntProp(Ent, Prop_Send, "m_nSolidType", StringToInt(sEntArray[5]), 1);
		
		// Takedamage
		SetEntProp(Ent, Prop_Data, "m_takedamage", StringToInt(sEntArray[6]), 1);
		
		// Movetype
		new MoveType:mMoveType = MoveType:StringToInt(sEntArray[7]);
		SetEntityMoveType(Ent, mMoveType);
		
		if(mMoveType == MOVETYPE_VPHYSICS)
			AcceptEntityInput(Ent, "enablemotion");
		
		// Skin:
		SetEntProp(Ent, Prop_Send, "m_nSkin", StringToInt(sEntArray[8]), 1);
		
		SetEntProp(Ent, Prop_Send, "m_nBody", StringToInt(sEntArray[9]), 1);
		
		DispatchKeyValue(Ent, "rendermode", "1");
		
		// Color:
		decl String:sEntColors[4][4];
		ExplodeString(sEntArray[10], " ", sEntColors, 4, sizeof(sEntColors[]));
		SetEntityRenderColor(Ent, StringToInt(sEntColors[0]), StringToInt(sEntColors[1]), StringToInt(sEntColors[2]), StringToInt(sEntColors[3]));
		
		if(isloading)
		{
			new Handle:hRelationPack;
			CreateDataTimer(0.25, FixRelation, hRelationPack);
			
			WritePackCell(hRelationPack, Ent);
			WritePackCell(hRelationPack, StringToInt(sEntArray[11]));
		}
		
		// Position:
		decl String:sEntPos[3][16];
		ExplodeString(sEntArray[12], " ", sEntPos, 3, sizeof(sEntPos[]));
		
		decl Float:vecEntPos[3];
		vecEntPos[0] = StringToFloat(sEntPos[0]);
		vecEntPos[1] = StringToFloat(sEntPos[1]);
		vecEntPos[2] = StringToFloat(sEntPos[2]);
		
		AddVectors(vecCenterPos, vecEntPos, vecEntPos);
		
		// Angle:
		decl String:sEntAng[3][16];
		ExplodeString(sEntArray[13], " ", sEntAng, 3, sizeof(sEntAng[]));
		
		decl Float:vecEntAng[3];
		vecEntAng[0] = StringToFloat(sEntAng[0]);
		vecEntAng[1] = StringToFloat(sEntAng[1]);
		vecEntAng[2] = StringToFloat(sEntAng[2]);
		
		TeleportEntity(Ent, vecEntPos, vecEntAng, ZERO_VECTOR);
		
		// Data String:
		DispatchKeyValue(Ent, "target", sEntArray[14]);
		if(StrEqual(sEntArray[0], "cel_light", false))
		{
			new EntLight = CreateEntityByName("light_dynamic");
			if(EntLight != -1)
			{
				DispatchKeyValue(EntLight, "inner_cone", "300");
				DispatchKeyValue(EntLight, "cone", "500");
				DispatchKeyValue(EntLight, "spotlight_radius", "500");
				DispatchKeyValue(EntLight, "brightness", "0.5");
				
				// Light distance:
				DispatchKeyValue(EntLight, "distance", sEntArray[15]);
				
				// Light style:
				DispatchKeyValue(EntLight, "style", sEntArray[16]);
				
				DispatchSpawn(EntLight);
				
				Entity_SetParent(EntLight, Ent);
				TeleportEntity(EntLight, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);
				SetEntityRenderColor(EntLight, StringToInt(sEntColors[0]), StringToInt(sEntColors[1]), StringToInt(sEntColors[2]), 255);
				
				// Toggle light on use:
				
				AcceptEntityInput(Ent, "disableshadow");
			}
		}
		else if(StrEqual(sEntArray[0], "cel_ladder", false))
		{
			new EntLadder = CreateEntityByName("func_useableladder");
			if(EntLadder != -1)
			{
				DispatchKeyValue(EntLadder, "point0", "30 0 0");
				DispatchKeyValue(EntLadder, "point1", "30 0 128");
				DispatchKeyValue(EntLadder, "StartDisabled", "0");
				
				Entity_SetParent(EntLadder, Ent);
				TeleportEntity(EntLadder, ZERO_VECTOR, ZERO_VECTOR, ZERO_VECTOR);
			}
		}
		else if(StrEqual(sEntArray[0], "cel_doll", false))
		{
			DispatchKeyValue(Ent, "sequence", sEntArray[15]);
			SDKHook(Ent, SDKHook_OnTakeDamage, DollTakeDamage); 
		}
		else if(StrEqual(sEntArray[0], "cel_sound", false))
		{
			g_fUseTime[Ent] = GetGameTime();
		}
		else if(StrEqual(sEntArray[0], "cel_music", false))
		{
			g_fUseTime[Ent] = 0.0;
		}
		else if(StrEqual(sEntArray[0], "cel_fire", false))
		{
			new EntIgnite = CreateEntityByName("env_entity_igniter");
			DispatchKeyValue(EntIgnite, "target", "ignited");
			DispatchSpawn(EntIgnite);
			
			DispatchKeyValue(Ent, "targetname", "ignited");
			DispatchKeyValue(EntIgnite, "lifetime", "100000");
			AcceptEntityInput(EntIgnite, "ignite");
			
			DispatchKeyValue(Ent, "targetname", "");
			AcceptEntityInput(EntIgnite, "Kill");
		}
		else if(StrEqual(sEntArray[0], "cel_trigger", false))
		{
			SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		}
		else if(StrEqual(sEntArray[0], "bit_weapon", false))
		{
			SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		}
		else if(StrEqual(sEntArray[0], "bit_ammo", false))
		{
			SDKHook(Ent, SDKHook_StartTouch, OnEntTouch);
		}
		else if(StrEqual(sEntArray[0], "cel_camera", false))
		{
			new EntView = CreateEntityByName("point_viewcontrol");
			DispatchKeyValue(EntView, "spawnflags", "64");
			DispatchSpawn(EntView);
			
			Entity_SetParent(EntView, Ent);
			TeleportEntity(EntView, Float:{2.5, 0.0, 0.0}, ZERO_VECTOR, ZERO_VECTOR);
		}
		else if(StrEqual(sEntArray[0], "cel_teleport", false))
		{
			g_fUseTime[Ent] = 0.0;
		}
	}
	
	return Ent;
}

public Native_INK_ActivateEnt(Handle:plugin, numParam)
{
	// Grab native params:
	new Activator = GetNativeCell(1);
	new Ent = GetNativeCell(2);
	
	// Get entity classname:
	decl String:sEntClass[32];
	GetEntityClassname(Ent, sEntClass, sizeof(sEntClass));
	
	// Get entity target string (we store most entity-specific data in here):
	decl String:sTarget[256];
	GetEntPropString(Ent, Prop_Data, "m_target", sTarget, sizeof(sTarget));
	
	if(StrEqual(sEntClass, "cel_button", false) || StrEqual(sEntClass, "cel_trigger", false))
	{
		new String:sButtonArray[6][8];
		ExplodeString(sTarget, "^", sButtonArray, 6, sizeof(sButtonArray[]));
		
		// Loop through connected entities:
		for(new x; x < 6; x++)
		{
			new Target = StringToInt(sButtonArray[x]);
			if(Target != 0)
			{
				if(IsValidEntity(Target) && Target != Ent)
					INK_DelayActivate(Activator, Target, 0.1);
				else
				{
					ReplaceString(sTarget, sizeof(sTarget), sButtonArray[x], "0");
					DispatchKeyValue(Ent, "target", sTarget);
				}
			}
		}
		
		return;
	}
	
	if(StrEqual(sEntClass, "cel_internet", false) && MaxClients >= Activator > 0)
	{
		if(StrEqual(sTarget, "", false))
			INK_Message(Activator, "Do {green}!seturl{default} to attach a URL to this internet cel.");
		
		else
		{
			if(StrContains(sTarget, "://", false) == -1)
			{
				Format(sTarget, sizeof(sTarget), "http://%s", sTarget);
				DispatchKeyValue(Ent, "target", sTarget);
			}
			
			decl String:sFinalUrl[256];
			Format(sFinalUrl, sizeof(sFinalUrl), "http://voyagersclan.com/0?%s", sTarget);
			
			new Handle:hInternet = CreateKeyValues("data");
			
			KvSetString(hInternet, "title", "Internet");
			KvSetNum(hInternet, "type", MOTDPANEL_TYPE_URL);
			KvSetString(hInternet, "msg", sFinalUrl);
			
			ShowVGUIPanel(Activator, "info", hInternet, false);
			CloseHandle(hInternet);
		}
	}
	else if(StrEqual(sEntClass, "cel_sound", false))
	{
		if(g_fUseTime[Ent] < GetGameTime() - 1)
		{
			decl String:sSoundArray[2][64];
			ExplodeString(sTarget, "^", sSoundArray, 2, sizeof(sSoundArray[]));
			
			if(StrContains(sSoundArray[0], ".wav", false) != -1 || StrContains(sSoundArray[0], ".mp3", false) != -1)
			{
				PrecacheSound(sSoundArray[0]);
				PrefetchSound(sSoundArray[0]);
				EmitSoundToAll(sSoundArray[0], Ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, StringToInt(sSoundArray[1]));
				
				g_fUseTime[Ent] = GetGameTime();
			}
		}
	}
	else if(StrEqual(sEntClass, "cel_music", false))
	{
		decl String:sMusicArray[5][128];
		ExplodeString(sTarget, "^", sMusicArray, 5, sizeof(sMusicArray[]));
		
		if(g_fUseTime[Ent] < GetGameTime() - StringToInt(sMusicArray[1]))
		{
			if(StrContains(sMusicArray[0], ".wav", false) != -1 || StrContains(sMusicArray[0], ".mp3", false) != -1)
			{
				PrecacheSound(sMusicArray[0]);
				PrefetchSound(sMusicArray[0]);
				EmitSoundToAll(sMusicArray[0], Ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, StringToFloat(sMusicArray[2]), StringToInt(sMusicArray[4]));
				
				g_fUseTime[Ent] = GetGameTime();
				
				if(StringToInt(sMusicArray[3]) == 1)
				{
					g_hUseTimer[Ent] = INK_DelayActivate(Activator, Ent, StringToFloat(sMusicArray[1]) + 1);
					CreateTimer(StringToFloat(sMusicArray[1]) + 1, KillUseTimer, Ent);
				}
			}
		}
		else
		{
			StopSound(Ent, SNDCHAN_AUTO, sMusicArray[0]);
			
			ClearTimer(g_hUseTimer[Ent]);
			
			g_fUseTime[Ent] = 0.0;
		}
	}
	else if(StrEqual(sEntClass, "cel_teleport", false))
	{
		new EntDest = StringToInt(sTarget);
		if(EntDest > 0)
		{
			decl Float:vecDestPos[3];
			INK_GetEntPos(EntDest, vecDestPos);
			
			vecDestPos[2] += 16;
			
			decl Float:vecDestAng[3];
			INK_GetEntAng(EntDest, vecDestAng);
			
			decl Float:vecEntPos[3];
			INK_GetEntPos(Ent, vecEntPos);
			
			new Float:fLowX = vecEntPos[0] - 40;
			new Float:fHighX = vecEntPos[0] + 40;
			new Float:fLowY = vecEntPos[1] - 40;
			new Float:fHighY = vecEntPos[1] + 40;
			
			for(new C = 1; C <= MaxClients; C++)
			{
				if(IsClientInGame(C))
				{
					if(IsPlayerAlive(C))
					{
						decl Float:vecClientPos[3];
						GetClientAbsOrigin(C, vecClientPos);
						
						if(vecClientPos[0] > fLowX && vecClientPos[0] < fHighX && vecClientPos[1] > fLowY && vecClientPos[1] < fHighY)
						{
							if((vecEntPos[2] + 32) > vecClientPos[2] > (vecEntPos[2] - 8))
							{
								decl Float:vecFinalAng[3];
								GetClientEyeAngles(C, vecFinalAng);
								
								vecFinalAng[1] = vecDestAng[1];
								
								TeleportEntity(C, vecDestPos, vecFinalAng, NULL_VECTOR);
								
								// Effect:
								EmitSoundToAll("npc/roller/code2.wav", EntDest);
							}
						}
					}
				}
			}
		}
		else if(MaxClients >= Activator > 0)
			INK_Message(Activator, "Owner has not created a destination teleport.");
	}
	else if(StrEqual(sEntClass, "bit_weapon", false) && MaxClients >= Activator > 0)
	{
		if(!Client_HasWeapon(Activator, sTarget))
			Client_GiveWeaponAndAmmo(Activator, sTarget, false);
	}
	else if(StrEqual(sEntClass, "bit_ammo", false) && MaxClients >= Activator > 0)
	{
		if(Client_HasWeapon(Activator, sTarget))
			Client_GiveWeaponAndAmmo(Activator, sTarget, false);
	}
	else if(StrEqual(sEntClass, "cel_light", false))
	{
		new eLight = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");
		
		AcceptEntityInput(eLight, "toggle");
	}
	else if(StrEqual(sEntClass, "cel_camera", false) && MaxClients >= Activator > 0)
	{
		if(g_eCamera[Activator] == 0 && g_fCameraTime[Activator] <= GetGameTime() - 0.4)
		{
			g_eCamera[Activator] = GetEntPropEnt(Ent, Prop_Data, "m_hMoveChild");

			decl String:sClientTarget[16];
			Format(sClientTarget, sizeof(sClientTarget), "client_%d", Activator);
			
			DispatchKeyValue(Activator, "targetname", sClientTarget); 
			
			SetVariantString(sClientTarget); 
			AcceptEntityInput(g_eCamera[Activator], "Enable", Activator, g_eCamera[Activator]); 
			
			g_fCameraTime[Activator] = GetGameTime();
		}
	}
	else if(StrEqual(sEntClass, "cel_door", false))
	{
		new iLocked = GetEntProp(Ent, Prop_Data, "m_bLocked");
		
		if(iLocked == 1) AcceptEntityInput(Ent, "Unlock");
		
		AcceptEntityInput(Ent, "Open");
		
		if(iLocked == 1) AcceptEntityInput(Ent, "Lock");
	}
	else if(StrEqual(sEntClass, "cel_slider", false))
	{
		AcceptEntityInput(StringToInt(sTarget), "Toggle");
	}
}


// SPECIAL EFFECT STOCKS:

stock INK_ChangeBeam(Client)
{
	decl Float:vecClientPos[3];
	GetClientAbsOrigin(Client, vecClientPos);
	vecClientPos[2] += 40;
	
	decl Float:vecAimPos[3];
	INK_AimPosition(Client, vecAimPos);
	
	// Beam effect:
	TE_SetupBeamPoints(vecAimPos, vecClientPos, PhysBeam, HaloSprite, 0, 15, 0.1, 2.0, 2.0, 1, 0.0, PHYS_BLUE, 10);
	TE_SendToAll(0.0);
	
	// Spark effect:
	TE_SetupSparks(vecAimPos, ZERO_VECTOR, 1, 0);
	TE_SendToAll(0.0);
	
	// Sound effect:
	switch(GetRandomInt(0, 1))
	{
		case 0: EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", vecAimPos);
		case 1: EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", vecAimPos);
	}
}

stock INK_DeleteBeam(Client, Float:vecAimPos[3])
{
	decl Float:vecClientPos[3];
	GetClientAbsOrigin(Client, vecClientPos);
	vecClientPos[2] += 40;
	
	// Beam effect:
	TE_SetupBeamPoints(vecAimPos, vecClientPos, LaserSprite, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, PHYS_WHITE, 10);
	TE_SendToAll(0.0);
	
	// Ring effect:
	TE_SetupBeamRingPoint(vecAimPos, 10.0, 60.0, BeamSprite, HaloSprite, 0, 15, 0.5, 5.0, 0.0, PHYS_GREY, 10, 0);
	TE_SendToAll(0.0);
	
	// Sound effect:
	switch(GetRandomInt(0, 3))
	{
		case 0: EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate1.wav", vecAimPos);
		case 1: EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate2.wav", vecAimPos);
		case 2: EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate3.wav", vecAimPos);
		case 3: EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate4.wav", vecAimPos);
	}
}

stock INK_WeldBeam(Ent1, Ent2)
{
	// Beam effect:
	TE_SetupBeamEnts(Ent1, Ent2, CrystalBeam, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, PHYS_WHITE, 10);
	TE_SendToAll(0.0);
	
	EmitSoundToAll("weapons/physgun_off.wav", Ent2);
}

stock INK_SpawnEffect(Ent)
{
	decl Float:vecEntPos[3];
	INK_GetEntPos(Ent, vecEntPos);
	
	// Beam effect:
	TE_SetupEnergySplash(vecEntPos, ZERO_VECTOR, true);
	TE_SendToAll(0.0);
}


// MISC STOCKS:

stock INK_TooFast(Client, bool:msg = true)
{
	if(g_fSpawnTime[Client] <= GetGameTime() - 1.25)
	{
		g_fSpawnTime[Client] = GetGameTime();
		return false;
	}
	
	else if(msg)
	{
		switch(GetRandomInt(0, 3))
		{
			case 0: INK_Message(Client, "Cool your jets buddy.");
			case 1: INK_Message(Client, "Slow down there, Charlie.");
			case 2: INK_Message(Client, "Where's the rush?");
			case 3: INK_Message(Client, "Calm the hell down!");
		}
	}
	
	g_fSpawnTime[Client] = GetGameTime();
	return true;
}

stock ClearTimer(&Handle:timer)
{
	if(timer != INVALID_HANDLE)
		CloseHandle(timer);
	
	timer = INVALID_HANDLE;
}

// Executes for each client when they spawn or the plugin reloads:
stock INK_SetupClient(Client, discon = false)
{
	g_fSpawnTime[Client] = GetGameTime();
	
	for(new x; x < 256; x++)
		strcopy(g_sUndoQueue[Client][x], sizeof(g_sUndoQueue[][]), "");
	
	strcopy(g_sClientAuth[Client], sizeof(g_sClientAuth[]), "");
	
	g_eGrabEnt[Client] = 0;
	g_eGrabChild[Client] = 0;
	g_eCopyEnt[Client] = 0;
	
	g_eMovetoEnt[Client] = 0;
	g_eWeldEnt[Client] = 0;
	g_eTeleEnt[Client] = 0;
	g_eBeamEnt[Client] = 0;
	g_eWireEnt[Client] = 0;
	g_eCustomEnt[Client] = 0;
	
	g_iPlayerSize[Client] = 100;
	g_bDeathmatch[Client] = false;
	g_bStopFly[Client] = false;
	g_bStopCopy[Client] = false;
	
	g_iPrevLand[Client] = 0;
	g_iDeathLand[Client] = 0;
	g_eCamera[Client] = 0;
	g_fCameraTime[Client] = 0.0;
	
	INK_CreateLandEnts(Client, false);
	
	g_iLandCreate[Client] = 0;
	g_iLandGravity[Client] = GetConVarInt(sv_gravity);
	
	g_bSaving[Client] = false;
	strcopy(g_sSaveName[Client], sizeof(g_sSaveName[]), "");
	
	if(!discon)
	{
		do
		{	g_iLandColor[Client][0] = GetRandomInt(0, 255);
			g_iLandColor[Client][1] = GetRandomInt(0, 255);
			g_iLandColor[Client][2] = GetRandomInt(0, 255);
		}
		while((g_iLandColor[Client][0] + g_iLandColor[Client][1] + g_iLandColor[Client][2] < 200)
		||	  (g_iLandColor[Client][0] + g_iLandColor[Client][1] + g_iLandColor[Client][2] > 550));
		
		g_iLandColor[Client][3] = 255;
		
		SDKHook(Client, SDKHook_OnTakeDamage, ClientTakeDamage);
		SDKHook(Client, SDKHook_OnTakeDamagePost, ClientTakeDamagePost);
		// SDKHook(Client, SDKHook_Spawn, OnClientSpawn);
		
		GetClientAuthString(Client, g_sClientAuth[Client], sizeof(g_sClientAuth[]));
		ReplaceString(g_sClientAuth[Client], sizeof(g_sClientAuth[]), "STEAM_0:", "", false);
		ReplaceString(g_sClientAuth[Client], sizeof(g_sClientAuth[]), "STEAM_1:", "", false);
		ReplaceString(g_sClientAuth[Client], sizeof(g_sClientAuth[]), ":", "_", false);
	}
	
	decl String:Query[256];
	
	for(new C = 1; C <= MaxClients; C++)
	{
		g_bLandBan[Client][C] = false;
		g_bLandBan[C][Client] = false;
		
		if(!discon && C != Client)
		{
			if(IsClientInGame(C) && !StrEqual(g_sClientAuth[C], ""))
			{
				g_iBanPlayer[Client] = C;
				
				Format(Query, sizeof(Query), "SELECT * FROM `users_landbans` WHERE `Land` = '%s' AND `Banned` = '%s' LIMIT 0,1", g_sClientAuth[Client], g_sClientAuth[C]);
				SQL_TQuery(g_hBuildDB, DB_LoadLandban, Query, Client);
				
				
				g_iBanPlayer[C] = Client;
				
				Format(Query, sizeof(Query), "SELECT * FROM `users_landbans` WHERE `Land` = '%s' AND `Banned` = '%s' LIMIT 0,1", g_sClientAuth[C], g_sClientAuth[Client]);
				SQL_TQuery(g_hBuildDB, DB_LoadLandban, Query, C);
			}
		}
	}
}

stock INK_CreateLandEnts(Client, setup = true)
{
	decl String:sEntClass[32], String:sFindClass[32];
	
	Format(sFindClass, sizeof(sFindClass), "ink_landcorner_%d", Client);
	for(new x; x < 4; x++)
	{
		if(g_eLandCorner[Client][x] != 0 && IsValidEntity(g_eLandCorner[Client][x]))
		{
			GetEntityClassname(g_eLandCorner[Client][x], sEntClass, sizeof(sEntClass));
			
			if(StrEqual(sEntClass, sFindClass, false))
				AcceptEntityInput(g_eLandCorner[Client][x], "Kill");
			
			g_eLandCorner[Client][x] = 0;
		}
		
		if(setup)
		{
			g_eLandCorner[Client][x] = CreateEntityByName("info_target");
			DispatchSpawn(g_eLandCorner[Client][x]);
		}
	}
	
	Format(sFindClass, sizeof(sFindClass), "ink_landbeam_%d", Client);
	for(new x; x < 4; x++)
	{
		if(g_eLandBeam[Client][x] != 0 && IsValidEntity(g_eLandBeam[Client][x]))
		{
			GetEntityClassname(g_eLandBeam[Client][x], sEntClass, sizeof(sEntClass));
			
			if(StrEqual(sEntClass, sFindClass, false))
				AcceptEntityInput(g_eLandBeam[Client][x], "Kill");
			
			g_eLandBeam[Client][x] = 0;
		}
		
		if(setup)
		{
			if(x == 3)
				g_eLandBeam[Client][x] = INK_BeamEnt(g_eLandCorner[Client][x], g_eLandCorner[Client][0], "materials/sprites/laserbeam.vmt", 3.0, 3.0, g_iLandColor[Client]);
			else
				g_eLandBeam[Client][x] = INK_BeamEnt(g_eLandCorner[Client][x], g_eLandCorner[Client][x+1], "materials/sprites/laserbeam.vmt", 3.0, 3.0, g_iLandColor[Client]);
			
			DispatchKeyValue(g_eLandBeam[Client][x], "classname", sFindClass);
			SDKHook(g_eLandBeam[Client][x], SDKHook_SetTransmit, LandBeamTransmit);
		}
	}
}

stock INK_TopParent(Ent)
{
	new bool:bHasParent;
	
	do
	{	new eParent = GetEntPropEnt(Ent, Prop_Data, "m_pParent");
		bHasParent = IsValidEntity(eParent);
		
		if(bHasParent) Ent = eParent;
	}
	while (bHasParent);
	
	return Ent;
}

stock INK_WriteUndoQueue(Client, Ent)
{
	new iOpenIndex = Array_FindString(g_sUndoQueue[Client], 256, "");
	
	if(iOpenIndex != -1)
	{
		INK_EntToString(Ent, g_sUndoQueue[Client][iOpenIndex], sizeof(g_sUndoQueue[][]));
		g_iUndoOwner[Client][iOpenIndex] = INK_GetOwner(Ent);
	}
	
	else
	{
		for(new x = 1; x < 256; x++)
		{
			strcopy(g_sUndoQueue[Client][x-1], sizeof(g_sUndoQueue[][]), g_sUndoQueue[Client][x]);
			
			g_iUndoOwner[Client][x-1] = g_iUndoOwner[Client][x];
		}
		
		INK_EntToString(Ent, g_sUndoQueue[Client][255], sizeof(g_sUndoQueue[][]));
		g_iUndoOwner[Client][255] = INK_GetOwner(Ent);
	}
}

stock INK_CheckLimit(Client, String:sClassname[], bool:msg = true)
{
	if(StrContains(sClassname, "prop_physics", false) == 0)
	{
		new iPropLimit = GetConVarInt(sv_ink_maxprops);
		if(iPropLimit <= INK_GetPropCount(Client))
		{
			if(msg) INK_Message(Client, "Prop limit has been reached. (%d)", iPropLimit);
			return true;
		}
	}
	else if(StrContains(sClassname, "cel_", false) == 0)
	{
		if(StrContains(sClassname, "cel_light", false) == 0)
		{
			new iLightLimit = GetConVarInt(sv_ink_maxlights);
			if(iLightLimit <= INK_GetLightCount(Client))
			{
				if(msg) INK_Message(Client, "Light limit has been reached. (%d)", iLightLimit);
				return true;
			}
		}
		
		new iCelLimit = GetConVarInt(sv_ink_maxcels);
		if(iCelLimit <= INK_GetCelCount(Client))
		{
			if(msg) INK_Message(Client, "Cel limit has been reached. (%d)", iCelLimit);
			return true;
		}
	}
	else if(StrContains(sClassname, "bit_", false) == 0)
	{
		new iBitLimit = GetConVarInt(sv_ink_maxbits);
		if(iBitLimit <= INK_GetBitCount(Client))
		{
			if(msg) INK_Message(Client, "Bit limit has been reached. (%d)", iBitLimit);
			return true;
		}
	}
	
	return false;
}

stock INK_GetLand(Float:vecPos[3], bool:ignore_setup = false)
{
	for(new Client = 1; Client <= MaxClients; Client++)
	{
		if(g_iLandCreate[Client] > 1 || (ignore_setup && g_iLandCreate[Client] == 1))
		{
			new Float:fLowX = 999999.0, Float:fHighX = -999999.0, Float:fLowY = 999999.0, Float:fHighY = -999999.0;
			
			for(new Check; Check < 4; Check++)
			{
				if(fLowX > g_vecLandPoints[Client][Check][0])
					fLowX = g_vecLandPoints[Client][Check][0];
				
				if(fHighX < g_vecLandPoints[Client][Check][0])
					fHighX = g_vecLandPoints[Client][Check][0];
				
				if(fLowY > g_vecLandPoints[Client][Check][1])
					fLowY = g_vecLandPoints[Client][Check][1];
				
				if(fHighY < g_vecLandPoints[Client][Check][1])
					fHighY = g_vecLandPoints[Client][Check][1];
			}
			
			if(vecPos[0] > fLowX && vecPos[0] < fHighX && vecPos[1] > fLowY && vecPos[1] < fHighY)
			{
				if((g_fLandCeiling[Client] + 8) > vecPos[2] > (g_vecLandPoints[Client][0][2] - 8))
					return Client;
			}
		}
	}
	
	return 0;
}

stock TE_SetupBeamEnts(StartEntity, EndEntity, ModelIndex, HaloIndex, StartFrame, FrameRate, Float:Life, Float:Width, Float:EndWidth, FadeLength, Float:Amplitude, const Color[4], Speed)
{
	TE_Start("BeamEnts");
	TE_WriteEncodedEnt("m_nStartEntity", StartEntity);
	TE_WriteEncodedEnt("m_nEndEntity", EndEntity);
	TE_WriteNum("m_nModelIndex", ModelIndex);
	TE_WriteNum("m_nHaloIndex", HaloIndex);
	TE_WriteNum("m_nStartFrame", StartFrame);
	TE_WriteNum("m_nFrameRate", FrameRate);
	TE_WriteFloat("m_fLife", Life);
	TE_WriteFloat("m_fWidth", Width);
	TE_WriteFloat("m_fEndWidth", EndWidth);
	TE_WriteFloat("m_fAmplitude", Amplitude);
	TE_WriteNum("r", Color[0]);
	TE_WriteNum("g", Color[1]);
	TE_WriteNum("b", Color[2]);
	TE_WriteNum("a", Color[3]);
	TE_WriteNum("m_nSpeed", Speed);
	TE_WriteNum("m_nFadeLength", FadeLength);
}

stock INK_BeamEnt(StartEnt, EndEnt, String:Sprite[], Float:fWidth, Float:fEndWidth, const Color[4])
{
	new Ent = CreateEntityByName("env_beam");
	if(Ent != -1)
	{
		SetEntityModel(Ent, Sprite);
		SetEntityRenderColor(Ent, Color[0], Color[1], Color[2], Color[3]);
		
		DispatchSpawn(Ent);
		
		SetEntPropFloat(Ent, Prop_Send, "m_fStartFrame", 0.0);
		SetEntPropFloat(Ent, Prop_Send, "m_flFrameRate", 15.0);
		SetEntPropFloat(Ent, Prop_Send, "m_fSpeed", 10.0);
		SetEntPropFloat(Ent, Prop_Send, "m_fFadeLength", 1.0);
		SetEntPropFloat(Ent, Prop_Send, "m_fAmplitude", 0.0);
		
		SetEntPropEnt(Ent, Prop_Send, "m_hAttachEntity", StartEnt);
		SetEntPropEnt(Ent, Prop_Send, "m_hAttachEntity", EndEnt, 1);
		SetEntProp(Ent, Prop_Send, "m_nNumBeamEnts", 2);
		SetEntProp(Ent, Prop_Send, "m_nBeamType", 2);
		
		SetEntPropFloat(Ent, Prop_Data, "m_fWidth", fWidth);
		SetEntPropFloat(Ent, Prop_Data, "m_fEndWidth", fEndWidth);
		
		ActivateEntity(Ent);
		AcceptEntityInput(Ent, "TurnOn");
	}
	
	return Ent;
}

stock INK_SpriteOriented(Float:vecPos[3], Float:vecMaxs[3], Float:vecMins[3], Float:vecAng[3], String:sSprite[], const Color[4])
{
	new Ent = CreateEntityByName("env_sprite_oriented");
	if(Ent != -1)
	{
		SetEntityModel(Ent, sSprite);
		
		decl String:sColor[20];
		Format(sColor, sizeof(sColor), "%d %d %d", Color[0], Color[1], Color[2]);
		DispatchKeyValue(Ent, "rendercolor", sColor);
		
		decl String:sAmt[8];
		IntToString(Color[3], sAmt, sizeof(sAmt));
		DispatchKeyValue(Ent, "renderamt", sAmt);
		
		DispatchSpawn(Ent);
		
		TeleportEntity(Ent, vecPos, vecAng, NULL_VECTOR);
		
		if(vecMaxs[0] != vecMins[0] || vecMaxs[1] != vecMins[1] || vecMaxs[2] != vecMins[2])
		{
			SetEntPropVector(Ent, Prop_Send, "m_vecMaxs", vecMaxs);
			SetEntPropVector(Ent, Prop_Send, "m_vecMins", vecMins);
		}
		
		ActivateEntity(Ent);
		AcceptEntityInput(Ent, "TurnOn");
	}
	
	return Ent;
}

stock Handle:INK_DelayActivate(Activator, Ent, Float:delay = 0.25)
{
	new Handle:hPack;
	new Handle:hTimer = CreateDataTimer(delay, DelayActivate, hPack);
	
	WritePackCell(hPack, Activator);
	WritePackCell(hPack, Ent);
	
	return hTimer;
}


// SIMPLE MSG STOCKS:

stock INK_EntMessage(Client, String:Msg[], Ent, String:Msg2[] = "", any:...)
{
	decl String:sEntClass[32];
	new String:sBrokeClass[2][32];
	
	GetEntityClassname(Ent, sEntClass, 32);
	
	if(StrEqual(Msg2, ""))
	{
		if(StrContains(sEntClass, "_", false) == -1)
			INK_Message(Client, "%s %s{default}.", Msg, sEntClass);
		
		else
		{
			ExplodeString(sEntClass, "_", sBrokeClass, 2, sizeof(sBrokeClass[]));
			INK_Message(Client, "%s %s %s{default}.", Msg, sBrokeClass[1], sBrokeClass[0]);
		}
	}
	
	else
	{
		decl String:sMsgformat[256];
		VFormat(sMsgformat, sizeof(sMsgformat), Msg2, 5);
		
		if(StrContains(sEntClass, "_", false) == -1)
			INK_Message(Client, "%s %s %s{default}.", Msg, sEntClass, sMsgformat);
		
		else
		{
			ExplodeString(sEntClass, "_", sBrokeClass, 2, sizeof(sBrokeClass[]));
			INK_Message(Client, "%s %s %s %s{default}.", Msg, sBrokeClass[1], sBrokeClass[0], sMsgformat);
		}
	}
}

stock INK_NoTarget(Client)
{
	INK_Message(Client, "You're not looking at anything.");
}

stock INK_NotYours(Client)
{
	INK_Message(Client, "This entity does not belong to you.");
}

/************************************************************************************/
/*								 --  (Misc Bullshit)  --							*/
/************************************************************************************/


public bool:FilterPlayer(entity, contentsMask, any:data)
{
	return (entity != data && entity > MaxClients);
}

public Action:LandBeamTransmit(Ent, Client)
{
	new Land;
	
	for(new C = 1; C <= MaxClients; C++)
	{
		for(new x; x < 4; x++)
		{
			if(g_eLandBeam[C][x] == Ent)
			{
				Land = C;
				
				if(Land == Client)
					return Plugin_Continue;
				
				break;
			}
		}
		
		if(Land != 0)
			break;
	}
	
	if(g_iLandCreate[Land] > 1)
		return Plugin_Continue;
	
	return Plugin_Handled;
}
