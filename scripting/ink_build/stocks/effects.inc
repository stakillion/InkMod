/*
 *
 *	InkMod Build - Effects
 *	Stocks for playing special effects
 *
**/
#define _ink_build_stocks_effects_


stock void Ink_SpawnEffect(float origin[3])
{
	// Beam effect:
	TE_SetupEnergySplash(origin, ZERO_VECTOR, true);
	TE_SendToAll(0.0);
}

stock void Ink_ToolEffect(int client, float hitPos[3])
{
	int clientWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	int clientViewModel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");

	// worldmodel beam effect
	int beamColor[4] = {100, 200, 255, 255};
	// send to clients
	for (int sendClient = 1; sendClient <= MaxClients; sendClient++) {
		if (sendClient == client) {
			continue;
		}
		if (!IsClientInGame(sendClient)) {
			continue;
		}

		TE_SetupBeamEntPoint(hitPos, clientWeapon, PhysBeam, HaloSprite, 0, 15, 0.1, 2.0, 2.0, 1, 0.0, beamColor, 10);
		TE_SendToClient(sendClient, 0.0);
	}

	// viewmodel beam effect
	TE_SetupBeamEntPoint(hitPos, clientViewModel, PhysBeam, HaloSprite, 0, 15, 0.1, 2.0, 2.0, 1, 0.0, beamColor, 10);
	TE_SendToClient(client, 0.0);

	// spark effect
	TE_SetupSparks(hitPos, view_as<float>({0.0, 0.0, 0.0}), 1, 0);
	TE_SendToAll(0.0);

	// sound effect
	switch (GetRandomInt(0, 1)) {
		case 0: {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot1.wav", hitPos);
		}
		case 1: {
			EmitAmbientSound("weapons/airboat/airboat_gun_lastshot2.wav", hitPos);
		}
	}
}

stock void Ink_RemoveEffect(int client, float hitPos[3])
{
	int clientWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	int clientViewModel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");

	// beam effect
	int beamColor[4] = {255, 255, 255, 200};
	// send to clients
	for (int sendClient = 1; sendClient <= MaxClients; sendClient++) {
		if (sendClient == client) {
			continue;
		}
		if (!IsClientInGame(sendClient)) {
			continue;
		}

		TE_SetupBeamEntPoint(hitPos, clientWeapon, LaserSprite, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, beamColor, 10);
		TE_SendToClient(sendClient, 0.0);
	}

	TE_SetupBeamEntPoint(hitPos, clientViewModel, LaserSprite, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, beamColor, 10);
	TE_SendToClient(client, 0.0);

	// ring effect
	int ringColor[4] = {255, 255, 255, 300};
	TE_SetupBeamRingPoint(hitPos, 10.0, 60.0, BeamSprite, HaloSprite, 0, 15, 0.5, 5.0, 0.0, ringColor, 10, 0);
	TE_SendToAll(0.0);

	// sound effect
	switch (GetRandomInt(0, 3)) {
		case 0: {
			EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate1.wav", hitPos);
		}
		case 1: {
			EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate2.wav", hitPos);
		}
		case 2: {
			EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate3.wav", hitPos);
		}
		case 3: {
			EmitAmbientSound("ambient/levels/citadel/weapon_disintegrate4.wav", hitPos);
		}
	}
}

stock void Ink_WeldEffect(int ent1, int ent2)
{
	// beam effect
	int beamColor[4] = {255, 255, 255, 200};
	TE_SetupBeamEnts(ent1, ent2, CrystalBeam, HaloSprite, 0, 15, 0.25, 1.0, 1.0, 1, 0.0, beamColor, 10);
	TE_SendToAll(0.0);

	// sound effect
	EmitSoundToAll("weapons/physgun_off.wav", ent2);
}
