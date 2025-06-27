/*
 *
 *	InkMod General Stocks
 *
**/
#define _ink_stocks_included


/**************************
          Clients          
**************************/

stock int Ink_GetClientAim(int client, float hitPos[3] = NULL_VECTOR, float hitNormal[3] = NULL_VECTOR, int flags = MASK_SHOT_HULL|MASK_SHOT)
{
	int target = -1;

	float eyeAng[3], eyePos[3];
	GetClientEyeAngles(client, eyeAng);
	GetClientEyePosition(client, eyePos);

	Handle trace = TR_TraceRayFilterEx(eyePos, eyeAng, flags, RayType_Infinite, Filter_Dissolving, client);
	if (TR_DidHit(trace)) {

		target = TR_GetEntityIndex(trace);

		TR_GetEndPosition(hitPos, trace);
		TR_GetPlaneNormal(trace, hitNormal);
	}

	delete trace;

	if (target == 0) {
		return -1;
	}

	return target;
}


/***************************
          Entities          
***************************/

stock void Ink_CalcEntSpawnPos(int ent, int spawner, float entPos[3], float entAng[3])
{
	// grab spawner position
	float spawnerPos[3], spawnerAng[3];
	GetClientAbsOrigin(spawner, spawnerPos);
	GetClientEyeAngles(spawner, spawnerAng);

	// grab model dimensions
	float entMins[3];
	GetEntPropVector(ent, Prop_Send, "m_vecMinsPreScaled", entMins);

	// do quick maths
	entPos[0] = spawnerPos[0] + Cosine(DegToRad(spawnerAng[1])) * (48 - entMins[0]);
	entPos[1] = spawnerPos[1] + Sine(DegToRad(spawnerAng[1])) * (48 - entMins[0]);
	entPos[2] = spawnerPos[2] - entMins[2];

	entAng[0] = 0.0;
	entAng[1] = spawnerAng[1];
	entAng[2] = 0.0;
}

stock int Ink_GetEntTopParent(int ent)
{
	bool parentValid = true;
	while (parentValid) {

		int entParent = Entity_GetParent(ent);
		parentValid = (entParent != INVALID_ENT_REFERENCE);

		if (parentValid) {
			ent = entParent;
		}
	}

	return ent;
}


/***********************
          Data          
***********************/

stock int Ink_ModelFromAlias(const char[] alias, char[] model, int modelSize, char[] anim, int animSize, int &solid = 6, bool &enabled = false)
{
	// load props file
	char propPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, propPath, sizeof(propPath), "data/inkmod/props.txt");

	KeyValues propKv = new KeyValues("Props");
	propKv.ImportFromFile(propPath);

	enabled = false;

	if (propKv.JumpToKey(alias)) {
		// get prop data
		int propType = -1;

		propKv.GetString("model", model, modelSize);
		enabled = view_as<bool>(propKv.GetNum("enabled"));

		if (propKv.GetNum("physics")) {
			propType = 1;
		} else if (propKv.GetNum("cycler")) {
			propType = 2;
		} else if (propKv.GetString("dynamic", anim, animSize)) {
			propType = 3;
			solid = propKv.GetNum("solid", 6);
		}

		delete propKv;
		return propType;
	}

	delete propKv;
	return -1;
}

stock bool Ink_VehicleFromAlias(const char[] alias, char[] model, int modelSize, char[] script, int scriptSize, int &type, bool &enabled = false)
{
	// load props file
	char vehiclePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, vehiclePath, sizeof(vehiclePath), "data/inkmod/vehicles.txt");

	KeyValues vehicleKv = new KeyValues("Vehicles");
	vehicleKv.ImportFromFile(vehiclePath);

	type = -1;
	enabled = false;

	if (vehicleKv.JumpToKey(alias)) {
		// get prop data
		char vehicleModel[128], vehicleScript[128];
		int vehicleType, vehicleEnabled;

		vehicleKv.GetString("model", vehicleModel, sizeof(vehicleModel));
		vehicleKv.GetString("script", vehicleScript, sizeof(vehicleScript));
		vehicleType = vehicleKv.GetNum("type", -1);
		vehicleEnabled = vehicleKv.GetNum("enabled", 0);

		// copy to buffers
		strcopy(model, modelSize, vehicleModel);
		strcopy(script, scriptSize, vehicleScript);
		type = vehicleType;
		enabled = view_as<bool>(vehicleEnabled);

		delete vehicleKv;
		return true;
	}

	delete vehicleKv;
	return false;
}

stock bool Ink_ColorFromAlias(const char[] alias, int color[4])
{
	// load colors file
	char colorPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, colorPath, sizeof(colorPath), "data/inkmod/colors.txt");

	KeyValues colorKv = new KeyValues("Colors");
	colorKv.ImportFromFile(colorPath);

	if (colorKv.GetDataType(alias) == KvData_None) {
		delete colorKv;
		return false;
	}

	// get color
	int alpha = color[3];
	colorKv.GetColor4(alias, color);
	color[3] = alpha;

	delete colorKv;
	return true;
}

/***********************
          Misc          
***********************/

stock void TE_SetupBeamEnts(int StartEntity, int EndEntity, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, 
				float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed)
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

stock void TE_SetupBeamEntPoint(const float start[3], int EndEntity, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, 
				float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed)
{
	TE_Start("BeamEntPoint");
	TE_WriteVector("m_vecStartPoint", start);
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

stock bool Filter_Dissolving(int ent, int contentsMask, any data)
{
	if (ent == data) {
		return false;
	}
	if (ent <= MaxClients) {
		return false;
	}

	char entName[16];
	GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));
	
	return !StrEqual(entName, "dissolving");
}
stock bool Filter_Player(int ent, int contentsMask, any data)
{
	return (ent != data && (ent > MaxClients || ent == 0));
}
stock bool Filter_Data(int ent, int contentsMask, any data)
{
	return (ent != data);
}
stock bool Filter_WorldOnly(int ent, int contentsMask, any data)
{
	return (ent == 0);
}
stock bool Filter_Vehicle(int ent, int contentsMask, any data)
{
	return (ent != data && ent != GetEntPropEnt(data, Prop_Send, "m_hPlayer"));
}

stock float AngleDiff(float destAngle, float srcAngle)
{
	float delta = destAngle - srcAngle;
	delta = delta - 360.0 * RoundToFloor(delta / 360.0);

	if (destAngle > srcAngle && delta >= 180) {
		delta -= 360;
	}
	else if (delta <= -180) {
		delta += 360;
	}

	return delta;
}

stock bool IsAlphanumeric(const char[] string)
{
	int x;
	while (string[x] != '\0') {
		if (!IsCharNumeric(string[x]) && !IsCharAlpha(string[x])) {
			return false;
		}
		x++;
	}

	return true;
}