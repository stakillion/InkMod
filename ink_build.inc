/**
 * Gives the ownership of an entity to a client.
 *
 * @param Ent			Ent to give.
 * @param Client		Client to give ownership to.
 * @param clear			If true (default) and client is not in game, clear ownership.
 * @return				True if Client is in game, else false.
 */
native INK_SetOwner(Ent, Client, bool:clear = false);

/**
 * Retrieves the owner of an entity.
 *
 * @param Ent			Ent to check.
 * @return				Client index if prop has owner, -1 if invalid entity. else 0.
 */
native INK_GetOwner(Ent);

/**
 * Retrieves the amount of props a player has spawned.
 *
 * @param Client		Client index.
 * @return				Prop count.
 */
native INK_GetPropCount(Client);

/**
 * Retrieves the amount of cels a player has spawned.
 *
 * @param Client		Client index.
 * @return				Cel count.
 */
native INK_GetCelCount(Client);

/**
 * Retrieves the amount of lights a player has spawned.
 *
 * @param Client		Client index.
 * @return				Light count.
 */
native INK_GetLightCount(Client);

/**
 * Retrieves the amount of bits a player has spawned.
 *
 * @param Client		Client index.
 * @return				Bit count.
 */
native INK_GetBitCount(Client);

/**
 * Retrieves the total amount of entities a player has spawned.
 *
 * @param Client		Client index.
 * @return				Ent count.
 */
native INK_GetTotalCount(Client);

/**
 * Safely removes an entity.
 *
 * @param Ent			Entity index.
 * @param dissolve		If true (default), dissolve entity. Else kill.
 * @param delay			Timer delay. (default 0.1)
 * @noreturn
 */
native INK_RemoveEnt(Ent, bool:dissolve = true, Float:delay = 0.1);

/**
 * Retrieves the data string from an entity. Does not store ownership.
 *
 * @param Ent			Entity index.
 * @param String		String buffer to copy to.
 * @param size			Size of string buffer.
 * @param pos			Relative coordinates to store origin.
 * @noreturn
 */
native INK_EntToString(Ent, String:sEntString[], size, const Float:vecCenterPos[3] = {0.0, 0.0, 0.0});

/**
 * Returns with an entity made using a string made with the eiamgiaeg  ei  entto string oh my god im so tired
 *
 * @param String		String to grab the entity data from.
 * @param pos			Relative coordinates to set origin.
 * @return				Entity index.
 */
native INK_StringToEnt(const String:sEntString[], const Float:vecCenterPos[3] = {0.0, 0.0, 0.0}, bool:isloading = false);

/**
 * Activates the specified entity.
 *
 * @param Entity		Entity
 * @param Client		Optional player index, required for cel_internets.
 * @noreturn
 */
native INK_ActivateEnt(Ent, Target, Power = true);