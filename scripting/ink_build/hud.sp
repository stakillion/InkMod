/*
 *
 *	InkMod Build - Hud
 *
**/
#define _ink_build_hud_


public Action DrawHud(Handle timer, int ent)
{
	for (int client = 1; client <= MaxClients; client++) {

		if (!IsClientInGame(client)) {
			continue;
		}

		float aimPos[3];
		int target = Ink_GetClientAim(client, aimPos);

		SetHudTextParamsEx(3.050, -0.110, 0.4, {255, 0, 0, 255});

		if (target != -1 && Object[target] != null) {
			int owner = Ink_GetEntOwner(target);

			char entClass[128];
			GetEntityClassname(target, entClass, sizeof(entClass));

			char entName[64], explodedName[2][32];
			Entity_GetName(target, entName, sizeof(entName));
			ExplodeString(entName, "-", explodedName, 2, sizeof(explodedName[]));

			if (StrEqual(entClass, "prop_physics") || StrEqual(entClass, "prop_cycler") || StrEqual(entClass, "prop_dynamic")) {
				ShowHudText(client, 6, "Prop: %s   \nOwner: %N   ", explodedName[0], owner);
			} else {
				ShowHudText(client, 6, "Entity: %s   \nOwner: %N   ", explodedName[0], owner);
			}
		} else {
			int land = -1;
			for (int c = 1; c <= MaxClients; c++) {
				if (!IsClientInGame(c) || Object[c] == null) {
					continue;
				}

				float landPoints[2][3];
				if (!Object[c].GetArray("land.offset", landPoints[1], 3) 
				|| !Object[c].GetArray("land.origin", landPoints[0], 3)) {
					continue;
				}

				if (InLand(aimPos, landPoints)) {
					land = c;
					break;
				}
			}

			if (land != -1) {
				ShowHudText(client, 6, "Land: %N   ", land);
			} else {
				ShowHudText(client, 6, " ");
			}
		}
	}

	return Plugin_Handled;
}