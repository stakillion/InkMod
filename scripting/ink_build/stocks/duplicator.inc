/*
 *
 *	InkMod - Entity Duplicator
 *	Stores data from a InkMod entity into KeyValues, or creates an entity from a KeyValues handle
 *
**/
#define _ink_build_stocks_duplicator_


stock KeyValues Ink_EntToKeyValues(int ent, KeyValues kv = view_as<KeyValues>(INVALID_HANDLE), const float origin[3] = {0.0, 0.0, 0.0}, const float angles[3] = {0.0, 0.0, 0.0}, bool storeOwner = false)
{
	if (ent == INVALID_ENT_REFERENCE) {
		return view_as<KeyValues>(INVALID_HANDLE);
	}
	if (Object[ent] == null) {
		return view_as<KeyValues>(INVALID_HANDLE);
	}

	// create keyvalues
	if (kv == INVALID_HANDLE) {
		kv = new KeyValues("Entities");
	}

	// get entity classname
	char entClass[32];
	GetEntPropString(ent, Prop_Data, "m_iClassname", entClass, sizeof(entClass));

	// get entity name
	char entName[32];
	Entity_GetName(ent, entName, sizeof(entName));

	// create entity key
	char keyName[64];
	Format(keyName, sizeof(keyName), "%s-%s", entClass, entName);
	kv.JumpToKey(keyName, true);

	// store ent origin
	float rotatedOrigin[3];
	Math_RotateVector(origin, angles, rotatedOrigin);
	float entOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
	SubtractVectors(entOrigin, rotatedOrigin, entOrigin);
	kv.SetVector("origin", entOrigin);

	// store ent angles
	float entAngles[3];
	GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", entAngles);
	kv.SetVector("angles", entAngles);

	// store ent model
	char entModel[PLATFORM_MAX_PATH];
	GetEntPropString(ent, Prop_Data, "m_ModelName", entModel, sizeof(entModel));
	kv.SetString("model", entModel);

	int value;
	char string[512];

	StringMapSnapshot snapshot = Object[ent].Snapshot();
	int length = snapshot.Length;
	char keyname[128];
	// store dynamic object data
	for (int i = 0; i < length; i++) {
		snapshot.GetKey(i, keyname, sizeof(keyname));

		// special cases
		if (StrEqual(keyname, "owner") && !storeOwner) {
			// dont store owner unless specified
			continue;
		}
		
		if (StrEqual(keyname, "modelscale")) {
			float scale;
			Object[ent].GetValue(keyname, scale);
			kv.SetFloat(keyname, scale);
		} else if (StrEqual(keyname, "rendercolor")) {
			int color[4] = {255, ...};
			Object[ent].GetArray(keyname, color, 4);
			kv.SetColor4(keyname, color);
		}
		// everything else
		else if (Object[ent].GetValue(keyname, value)) {
			kv.SetNum(keyname, value);
		}
		else if (Object[ent].GetString(keyname, string, sizeof(string))) {
			kv.SetString(keyname, string);
		}
	}

	// entity-specific properties
	if (StrContains(entClass, "prop_doll") == 0) {
		// store current animation frame
		float entCycle = GetEntPropFloat(ent, Prop_Send, "m_flCycle");
		if (entCycle != 0.0) {
			kv.SetFloat("cycle", entCycle);
		}
	} else if (StrContains(entClass, "prop_dynamic") == 0) {
		GetEntPropString(ent, Prop_Data, "m_iszDefaultAnim", string, sizeof(string));
		kv.SetString("animation", string)
		int solid = Entity_GetSolidType(ent);
		kv.SetNum("solid", solid);
	} else if (StrContains(entClass, "prop_door") == 0) {
		// store door hardware type
		int hardware = GetEntProp(ent, Prop_Data, "m_nHardwareType");
		kv.SetNum("hardware", hardware);
	} else if (StrContains(entClass, "prop_light") == 0) {
		// store light distance
		int light = GetEntPropEnt(ent, Prop_Data, "m_hMoveChild");
		float distance = GetEntPropFloat(light, Prop_Data, "m_Radius");
		kv.SetFloat("distance", distance);
	} else if (StrContains(entClass, "prop_vehicle") == 0) {
		// store vehicle script
		GetEntPropString(ent, Prop_Data, "m_vehicleScript", string, sizeof(string));
		kv.SetString("vehiclescript", string);

		// store vehicle type
		value = GetEntProp(ent, Prop_Data, "m_nVehicleType");
		kv.SetNum("vehicletype", value);
	}

	kv.GoBack();

	return kv;
}

stock int Ink_KeyValuesToEnt(KeyValues entKv, const float origin[3] = {0.0, 0.0, 0.0}, const float angles[3] = {0.0, 0.0, 0.0}, bool restoreOwner = false, bool restoreFrozen = false)
{
	int ent = INVALID_ENT_REFERENCE;

	char keyName[256];
	entKv.GetSectionName(keyName, sizeof(keyName));

	if (StrContains(keyName, "-") == -1) {
		entKv.GotoFirstSubKey(true);
		entKv.GetSectionName(keyName, sizeof(keyName));
	}

	char entKey[3][32];
	ExplodeString(keyName, "-", entKey, 3, sizeof(entKey[]));

	char entModel[PLATFORM_MAX_PATH];
	entKv.GetString("model", entModel, sizeof(entModel));

	// create entity
	if (StrContains(entKey[0], "prop_physics") == 0) {
		ent = Ink_CreatePhysicsProp(entModel);

	} else if (StrContains(entKey[0], "prop_dynamic") == 0) {
		char animation[PLATFORM_MAX_PATH];
		entKv.GetString("animation", animation, sizeof(animation));
		int solid = entKv.GetNum("solid", 6);
		ent = Ink_CreateDynamicProp(entModel, animation, solid);

	} else if (StrContains(entKey[0], "prop_doll") == 0) {
		ent = Ink_CreateDollProp(entModel);

	} else if (StrContains(entKey[0], "prop_door") == 0) {
		int hardware = entKv.GetNum("hardware");
		ent = Ink_CreateDoor(entModel, hardware);

	} else if (StrContains(entKey[0], "prop_ladder") == 0) {
		ent = Ink_CreateLadder(entModel);

	} else if (StrContains(entKey[0], "prop_light") == 0) {
		int distance = entKv.GetNum("distance");
		ent = Ink_CreateLight(entModel, distance);

	} else if (StrContains(entKey[0], "prop_vehicle") == 0) {
		char entVehicleScript[PLATFORM_MAX_PATH];
		entKv.GetString("vehiclescript", entVehicleScript, sizeof(entVehicleScript));
		ent = Ink_CreateVehicle(entModel, entVehicleScript, entKv.GetNum("vehicletype"));

	} else if (StrContains(entKey[0], "prop_internet") == 0) {
		ent = Ink_CreateInternet(entModel);

	} else {
		entKv.GoBack();
		return INVALID_ENT_REFERENCE;
	}

	Entity_SetName(ent, "%s%i", entKey[1], EntIndexToEntRef(ent));

	entKv.GotoFirstSubKey(false);

	char keyValue[256];
	do {
		entKv.GetSectionName(keyName, sizeof(keyName));

		if (StrEqual(keyName, "type")) {
			continue;
		} else if (StrEqual(keyName, "model")) {
			continue;

		} else if (StrEqual(keyName, "origin")) {
			float rotatedOrigin[3];
			Math_RotateVector(origin, angles, rotatedOrigin);
			// copy origin from kv
			float entOrigin[3];
			entKv.GetVector(NULL_STRING, entOrigin);
			// teleport entity relative to given origin
			AddVectors(rotatedOrigin, entOrigin, entOrigin);
			TeleportEntity(ent, entOrigin, NULL_VECTOR, NULL_VECTOR);

		} else if (StrEqual(keyName, "angles")) {
			// copy angles from kv
			float entAngles[3];
			entKv.GetVector(NULL_STRING, entAngles);
			// set on entity
			TeleportEntity(ent, NULL_VECTOR, entAngles, NULL_VECTOR);
			if (StrContains(entKey[0], "prop_door") == 0) {
				DispatchSpawn(ent);
			}

		} else if (restoreOwner && StrEqual(keyName, "owner")) {
			// set owner on entity
			Object[ent].SetValue("owner", entKv.GetNum(NULL_STRING, -1));

		} else if (StrEqual(keyName, "rendercolor")) {
			// copy color from kv
			int entColor[4];
			entKv.GetColor4(NULL_STRING, entColor);
			// set on entity
			Ink_SetEntColor(ent, entColor);

		} else if (StrEqual(keyName, "movetype")) {
			if (restoreFrozen) {
				// set frozen state on entity
				bool frozen = !entKv.GetNum(NULL_STRING, 0);
				Ink_SetEntFrozen(ent, frozen);
			}

		} else if (StrEqual(keyName, "skin")) {
			// set skin on entity
			Ink_SetEntSkin(ent, entKv.GetNum(NULL_STRING, 0));

		} else if (StrEqual(keyName, "locked")) {
			// set locked on entity
			Ink_SetEntLocked(ent, view_as<bool>(entKv.GetNum(NULL_STRING, 0)));

		} else if (StrEqual(keyName, "modelscale")) {
			// set scale on entity
			Ink_SetEntScale(ent, entKv.GetFloat(NULL_STRING, 1.0));

		} else if (StrEqual(keyName, "sequence")) {
			// set sequence on entity
			Ink_SetEntSequence(ent, entKv.GetNum(NULL_STRING, 0));

		} else if (StrEqual(keyName, "playbackrate")) {
			// set playbackrate on entity
			Ink_SetEntPlaybackRate(ent, entKv.GetFloat(NULL_STRING, 1.0));

		} else if (StrEqual(keyName, "cycle")) {
			// set cycle on entity
			SetEntPropFloat(ent, Prop_Send, "m_flCycle", entKv.GetFloat(NULL_STRING, 0.0));

		} else {
			// copy remaining keyvalues to entity object
			switch (entKv.GetDataType(NULL_STRING)) {
				case KvData_Int: {
					Object[ent].SetValue(keyName, entKv.GetNum(NULL_STRING));
				}
				case KvData_Float: {
					Object[ent].SetValue(keyName, entKv.GetFloat(NULL_STRING));
				}
				default: {
					entKv.GetString(NULL_STRING, keyValue, sizeof(keyValue));
					Object[ent].SetString(keyName, keyValue);
				}
			}
		}
	} while (entKv.GotoNextKey(false));

	entKv.GoBack();
	return ent;
}
