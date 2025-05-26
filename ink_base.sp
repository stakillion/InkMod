#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <smlib>

new String:PropPath[PLATFORM_MAX_PATH];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("INK_AimTarget", Native_INK_AimTarget);
	CreateNative("INK_AimPosition", Native_INK_AimPosition);
	CreateNative("INK_Message", Native_INK_Message);
	CreateNative("INK_TraceUpward", Native_INK_TraceUpward);
	CreateNative("INK_GetEntPos", Native_INK_GetEntPos);
	CreateNative("INK_GetEntAng", Native_INK_GetEntAng);
	CreateNative("INK_GetAimNormal", Native_INK_GetAimNormal);
	CreateNative("INK_ValidString", Native_INK_ValidString);
	//CreateNative("INK_BeamPointTE", Native_INK_BeamPointTE);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	AddCommandListener(HandleSay, "say");
	AddCommandListener(HandleTeamSay, "say_team");
	
	BuildPath(Path_SM, PropPath, sizeof(PropPath), "data/ink_build/props.txt");
}

public Action:HandleSay(Client, const String:command[], argc)
{
	if(Client == 0) return Plugin_Continue;
	
	decl String:sArgString[254];
	GetCmdArgString(sArgString, sizeof(sArgString));
	
	StripQuotes(sArgString);
	TrimString(sArgString);
	
	decl String:sFindCmd[2];
	strcopy(sFindCmd, sizeof(sFindCmd), sArgString);
	
	if(StrEqual(sFindCmd, "!") || StrEqual(sFindCmd, "/") || StrEqual(sFindCmd, "+") || StrEqual(sFindCmd, "-"))
	{
		new String:sCmdArg[2][254];
		ExplodeString(sArgString, " ", sCmdArg, 2, sizeof(sCmdArg[]), true);
		
		decl String:sFixedCmd[64];
		strcopy(sFixedCmd, sizeof(sFixedCmd), sCmdArg[0]);
		String_ToLower(sFixedCmd, sFixedCmd, sizeof(sFixedCmd));
		
		ReplaceStringEx(sFixedCmd, sizeof(sFixedCmd), sFindCmd, "n_");
		
		if(GetCommandFlags(sFixedCmd) != INVALID_FCVAR_FLAGS)
		{
			FakeClientCommand(Client, "%s %s", sFixedCmd, sCmdArg[1]);
			return Plugin_Handled;
		}
		
		if(GetCommandFlags("n_spawn") != INVALID_FCVAR_FLAGS)
		{
			ReplaceStringEx(sFixedCmd, sizeof(sFixedCmd), "n_", "");
			
			decl String:sPropString[128];
			
			// Attempt to match a model to the given prop alias:
			new Handle:hPropHandle = CreateKeyValues("Props");
			FileToKeyValues(hPropHandle, PropPath);
			KvGetString(hPropHandle, sFixedCmd, sPropString, sizeof(sPropString), "Null");
			
			// If no model was found:
			if(StrContains(sPropString, "Null", false) != -1 && !StrEqual(sPropString, ""))
			{
				// Attempt to correct:
				if(StrContains(sFixedCmd, "1", false) != -1)
				{
					ReplaceString(sFixedCmd, sizeof(sFixedCmd), "1", "");
					KvGetString(hPropHandle, sFixedCmd, sPropString, sizeof(sPropString), "Null");
				}
				else
				{
					Format(sFixedCmd, sizeof(sFixedCmd), "%s1", sFixedCmd);
					KvGetString(hPropHandle, sFixedCmd, sPropString, sizeof(sPropString), "Null");
				}
			}
			CloseHandle(hPropHandle);
			
			if(StrContains(sPropString, "Null", false) == -1 && !StrEqual(sPropString, ""))
			{
				FakeClientCommand(Client, "n_spawn %s %s", sFixedCmd, sCmdArg[1]);
				return Plugin_Handled;
			}
		}
		
		strcopy(sFixedCmd, sizeof(sFixedCmd), sCmdArg[0]);
		ReplaceStringEx(sFixedCmd, sizeof(sFixedCmd), sFindCmd, "sm_");
		String_ToLower(sFixedCmd, sFixedCmd, sizeof(sFixedCmd));
		
		if(GetCommandFlags(sFixedCmd) != INVALID_FCVAR_FLAGS)
			return Plugin_Handled;
	}
	
	decl String:sClientName[MAX_NAME_LENGTH];
	GetClientName(Client, sClientName, sizeof(sClientName));
	
	CRemoveTags(sClientName, sizeof(sClientName));
	CRemoveTags(sArgString, sizeof(sArgString));
	
	CPrintToChatAllEx(Client, "{teamcolor}%s{default}: %s", sClientName, sArgString);
	
	CRemoveTags(sArgString, sizeof(sArgString));
	PrintToServer("%N: %s", Client, sArgString);
	
	return Plugin_Handled;
}

public Action:HandleTeamSay(Client, const String:command[], argc)
{
	decl String:sArgString[254];
	GetCmdArgString(sArgString, sizeof(sArgString));
	
	StripQuotes(sArgString);
	TrimString(sArgString);
	
	decl String:sClientName[MAX_NAME_LENGTH];
	GetClientName(Client, sClientName, sizeof(sClientName));
	
	CRemoveTags(sClientName, sizeof(sClientName));
	CRemoveTags(sArgString, sizeof(sArgString));
	
	new teamnum = GetClientTeam(Client);
	decl String:sTeamName[32];
	GetTeamName(teamnum, sTeamName, sizeof(sTeamName));
	String_ToUpper(sTeamName, sTeamName, sizeof(sTeamName));
	
	if(teamnum == 0)
	{
		CPrintToChatAllEx(Client, "{teamcolor}%s{default}: %s", sClientName, sArgString);
		PrintToServer("(%s) %N: %s", sTeamName, Client, sArgString);
	}
	
	else
	{
		for(new c = 1; c <= MaxClients; c++)
		{
			if(IsClientInGame(c))
			{
				if(GetClientTeam(c) == teamnum)
					CPrintToChatEx(Client, c, "{teamcolor}(%s) %s{default}: %s", sTeamName, sClientName, sArgString);
			}
		}
		
		CRemoveTags(sArgString, sizeof(sArgString));
		PrintToServer("(%s) %N: %s", sTeamName, Client, sArgString);
	}
	
	return Plugin_Handled;
}

public Native_INK_AimTarget(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	new bool:hitclients = GetNativeCell(2);
	new Ent = -1;
	
	if(IsClientInGame(Client))
	{
		decl Float:vecEyeAng[3], Float:vecEyePos[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientEyePosition(Client, vecEyePos);
		
		decl Handle:hTraceRay;
		
		if(hitclients) hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterEnt, Client);
		else hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterPlayer, Client);
		
		if(TR_DidHit(hTraceRay)) Ent = TR_GetEntityIndex(hTraceRay);
		if(Ent == 0) Ent = -1;
		
		CloseHandle(hTraceRay);
	}
	
	return Ent;
}

public Native_INK_AimPosition(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1), bool:bTraceHit;
	new bool:hitclients = GetNativeCell(3);
	decl Float:vecAimPos[3];
	
	if(IsClientInGame(Client))
	{
		decl Float:vecEyeAng[3], Float:vecEyePos[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientEyePosition(Client, vecEyePos);
		
		decl Handle:hTraceRay;
		
		if(hitclients) hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterEnt, Client);
		else hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterPlayer, Client);
		
		if(TR_DidHit(hTraceRay))
		{
			TR_GetEndPosition(vecAimPos, hTraceRay);
			bTraceHit = true;
		}
		
		CloseHandle(hTraceRay);
	}
	
	if(bTraceHit) SetNativeArray(2, vecAimPos, 3);
	return bTraceHit;
}

public Native_INK_Message(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1);
	if(IsClientInGame(Client))
	{
		decl String:buffer[512], written;
		FormatNativeString(0, 2, 3, sizeof(buffer), written, buffer);
		Format(buffer, sizeof(buffer), "{blue}[INK]{default} %s", buffer);
		
		CPrintToChat(Client, buffer);
		
		return true;
	}
	
	return false;
}

public Native_INK_TraceUpward(Handle:plugin, numParams)
{
	new bool:bTraceHit;
	
	decl Float:vecTracePos[3], Float:vecEndPos[3];
	GetNativeArray(1, vecTracePos, 3);
	
	vecTracePos[2]++;
	
	new Handle:hTraceRay = TR_TraceRayFilterEx(vecTracePos, Float:{-90.0, 0.0, 0.0}, MASK_NPCWORLDSTATIC, RayType_Infinite, FilterAll);
	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(vecEndPos, hTraceRay);
		bTraceHit = true;
	}
	
	CloseHandle(hTraceRay);
	
	if(bTraceHit) SetNativeArray(2, vecEndPos, 3);
	return bTraceHit;
}

public Native_INK_GetEntPos(Handle:plugin, numParams)
{
	new Ent = GetNativeCell(1);
	new EntParent = Entity_GetParent(Ent);
	new bool:bValidParent;
	
	decl Float:vecEntPos[3];
	
	if(IsValidEntity(EntParent))
	{
		Entity_RemoveParent(Ent);
		GetEntPropVector(Ent, Prop_Data, "m_vecAbsOrigin", vecEntPos);
		Entity_SetParent(Ent, EntParent);
		
		bValidParent = true;
	}
	else GetEntPropVector(Ent, Prop_Data, "m_vecAbsOrigin", vecEntPos);
	
	SetNativeArray(2, vecEntPos, 3);
	return bValidParent;
}

public Native_INK_GetEntAng(Handle:plugin, numParams)
{
	new Ent = GetNativeCell(1);
	new EntParent = Entity_GetParent(Ent);
	new bool:bValidParent;
	
	decl Float:vecEntAng[3];
	
	if(IsValidEntity(EntParent))
	{
		Entity_RemoveParent(Ent);
		GetEntPropVector(Ent, Prop_Data, "m_angRotation", vecEntAng);
		Entity_SetParent(Ent, EntParent);
		
		bValidParent = true;
	}
	else GetEntPropVector(Ent, Prop_Data, "m_angRotation", vecEntAng);
	
	SetNativeArray(2, vecEntAng, 3);
	return bValidParent;
}

public Native_INK_GetAimNormal(Handle:plugin, numParams)
{
	new Client = GetNativeCell(1), bool:bTraceHit;
	new bool:hitclients = GetNativeCell(3);
	decl Float:vecNormal[3];
	
	if(IsClientInGame(Client))
	{
		decl Float:vecEyeAng[3], Float:vecEyePos[3];
		GetClientEyeAngles(Client, vecEyeAng);
		GetClientEyePosition(Client, vecEyePos);
		
		decl Handle:hTraceRay;
		
		if(hitclients) hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterEnt, Client);
		else hTraceRay = TR_TraceRayFilterEx(vecEyePos, vecEyeAng, (MASK_SHOT_HULL|MASK_SHOT), RayType_Infinite, FilterPlayer, Client);
		
		if(TR_DidHit(hTraceRay))
		{
			TR_GetPlaneNormal(hTraceRay, vecNormal);
			bTraceHit = true;
		}
		
		CloseHandle(hTraceRay);
	}
	
	if(bTraceHit) SetNativeArray(2, vecNormal, 3);
	return bTraceHit;
}

public Native_INK_ValidString(Handle:plugin, numParams)
{
	new size;
	GetNativeStringLength(1, size);
	
	new String:sCheck[size + 1];
	GetNativeString(1, sCheck, size + 1);
	
	for(new i; i < size; i++)
	{ 
		if(sCheck[i] != 'a' && sCheck[i] != 'A' && sCheck[i] != '1' 
		&& sCheck[i] != 'b' && sCheck[i] != 'B' && sCheck[i] != '2' 
		&& sCheck[i] != 'c' && sCheck[i] != 'C' && sCheck[i] != '3' 
		&& sCheck[i] != 'd' && sCheck[i] != 'D' && sCheck[i] != '4' 
		&& sCheck[i] != 'e' && sCheck[i] != 'E' && sCheck[i] != '5' 
		&& sCheck[i] != 'f' && sCheck[i] != 'F' && sCheck[i] != '6' 
		&& sCheck[i] != 'g' && sCheck[i] != 'G' && sCheck[i] != '7' 
		&& sCheck[i] != 'h' && sCheck[i] != 'H' && sCheck[i] != '8' 
		&& sCheck[i] != 'i' && sCheck[i] != 'I' && sCheck[i] != '9' 
		&& sCheck[i] != 'j' && sCheck[i] != 'J' && sCheck[i] != '0' 
		&& sCheck[i] != 'k' && sCheck[i] != 'K' 
		&& sCheck[i] != 'l' && sCheck[i] != 'L' 
		&& sCheck[i] != 'm' && sCheck[i] != 'M' 
		&& sCheck[i] != 'n' && sCheck[i] != 'N' 
		&& sCheck[i] != 'o' && sCheck[i] != 'O' 
		&& sCheck[i] != 'p' && sCheck[i] != 'P' 
		&& sCheck[i] != 'q' && sCheck[i] != 'Q' 
		&& sCheck[i] != 'r' && sCheck[i] != 'R' 
		&& sCheck[i] != 's' && sCheck[i] != 'S' 
		&& sCheck[i] != 't' && sCheck[i] != 'T' 
		&& sCheck[i] != 'u' && sCheck[i] != 'U' 
		&& sCheck[i] != 'v' && sCheck[i] != 'V' 
		&& sCheck[i] != 'w' && sCheck[i] != 'W' 
		&& sCheck[i] != 'x' && sCheck[i] != 'X' 
		&& sCheck[i] != 'y' && sCheck[i] != 'Y' 
		&& sCheck[i] != 'z' && sCheck[i] != 'Z' )
			return false;
	}
	
	return true;
}

// public Native_INK_BeamPointTE(Handle:plugin, numParams)
// {
	// new Client = GetNativeCell(1);
	
	// new Float:StartPoint[3];
	// GetNativeArray(2, StartPoint, 3);
	
	// new Float:EndPoint[3];
	// GetNativeArray(3, EndPoint, 3);
	
	// new ModelIndex = GetNativeCell(4);
	// new Float:Life = GetNativeCell(5);
	// new Float:Width = GetNativeCell(6);
	// new Float:EndWidth = GetNativeCell(7);
	
	// new Color[4];
	// GetNativeArray(8, Color, 4);
	
	// new Speed = GetNativeCell(9);
	
	// /* new Handle:hBeamPack;
	
	// CreateDataTimer(TempEnts / 40.0, DelayBeamPoints, hBeamPack);
	
	// WritePackCell(hBeamPack, Client);
	
	// WritePackFloat(hBeamPack, StartPoint[0]);
	// WritePackFloat(hBeamPack, StartPoint[1]);
	// WritePackFloat(hBeamPack, StartPoint[2]);
	
	// WritePackFloat(hBeamPack, EndPoint[0]);
	// WritePackFloat(hBeamPack, EndPoint[1]);
	// WritePackFloat(hBeamPack, EndPoint[2]);
	
	// WritePackCell(hBeamPack, ModelIndex);
	
	// WritePackFloat(hBeamPack, Life);
	// WritePackFloat(hBeamPack, Width);
	// WritePackFloat(hBeamPack, EndWidth);
	
	// WritePackCell(hBeamPack, Color[0]);
	// WritePackCell(hBeamPack, Color[1]);
	// WritePackCell(hBeamPack, Color[2]);
	// WritePackCell(hBeamPack, Color[3]);
	
	// WritePackCell(hBeamPack, Speed); */
	
	// /* TE_Start("BeamPoints");
	// TE_WriteVector("m_vecStartPoint", StartPoint);
	// TE_WriteVector("m_vecEndPoint", EndPoint);
	// TE_WriteNum("m_nModelIndex", ModelIndex);
	// TE_WriteNum("m_nHaloIndex", HaloSprite);
	// TE_WriteNum("m_nStartFrame", 0);
	// TE_WriteNum("m_nFrameRate", 15);
	// TE_WriteFloat("m_fLife", Life + (TempEnts / 40.0));
	// TE_WriteFloat("m_fWidth", Width);
	// TE_WriteFloat("m_fEndWidth", EndWidth);
	// TE_WriteFloat("m_fAmplitude", 0.0);
	// TE_WriteNum("r", Color[0]);
	// TE_WriteNum("g", Color[1]);
	// TE_WriteNum("b", Color[2]);
	// TE_WriteNum("a", Color[3]);
	// TE_WriteNum("m_nSpeed", Speed);
	// TE_WriteNum("m_nFadeLength", 1);
	
	// if(MaxClients >= Client > 0)
		// TE_SendToClient(Client, TempEnts / 40.0);
	// else
		// TE_SendToAll(TempEnts / 40.0);
	
	// TempEnts++;
// }

/* public Action:DelayBeamPoints(Handle:timer, any:pack)
{
	ResetPack(pack);
	
	new Client = ReadPackCell(pack);
	
	new Float:StartPoint[3];
	StartPoint[0] = ReadPackFloat(pack);
	StartPoint[1] = ReadPackFloat(pack);
	StartPoint[2] = ReadPackFloat(pack);
	
	new Float:EndPoint[3];
	EndPoint[0] = ReadPackFloat(pack);
	EndPoint[1] = ReadPackFloat(pack);
	EndPoint[2] = ReadPackFloat(pack);
	
	new ModelIndex = ReadPackCell(pack);
	new Float:Life = ReadPackFloat(pack);
	new Float:Width = ReadPackFloat(pack);
	new Float:EndWidth = ReadPackFloat(pack);
	
	new Color[4];
	Color[0] = ReadPackCell(pack);
	Color[1] = ReadPackCell(pack);
	Color[2] = ReadPackCell(pack);
	Color[3] = ReadPackCell(pack);
	
	new Speed = ReadPackCell(pack);
	
	TE_Start("BeamPoints");
	TE_WriteVector("m_vecStartPoint", StartPoint);
	TE_WriteVector("m_vecEndPoint", EndPoint);
	TE_WriteNum("m_nModelIndex", ModelIndex);
	TE_WriteNum("m_nHaloIndex", HaloSprite);
	TE_WriteNum("m_nStartFrame", 0);
	TE_WriteNum("m_nFrameRate", 15);
	TE_WriteFloat("m_fLife", Life);
	TE_WriteFloat("m_fWidth", Width);
	TE_WriteFloat("m_fEndWidth", EndWidth);
	TE_WriteFloat("m_fAmplitude", 0.0);
	TE_WriteNum("r", Color[0]);
	TE_WriteNum("g", Color[1]);
	TE_WriteNum("b", Color[2]);
	TE_WriteNum("a", Color[3]);
	TE_WriteNum("m_nSpeed", Speed);
	TE_WriteNum("m_nFadeLength", 1);
	
	if(MaxClients >= Client > 0)
		TE_SendToClient(Client, TempEnts / 40.0);
	else
		TE_SendToAll(TempEnts / 40.0);
	
	TempEnts++;
} */

public bool:FilterEnt(entity, contentsMask, any:data)
{
	return (entity != data);
}

public bool:FilterPlayer(entity, contentsMask, any:data)
{
	return (entity != data && entity > MaxClients);
}

public bool:FilterAll(entity, contentsMask, any:data)
{
	return (entity < 1);
}