#define _ink_build_included_


forward void OnLandClientEntered(int land, int client);
forward void OnLandClientExited(int land, int client);
forward void OnLandEntityEntered(int land, int ent);
forward void OnLandEntityExited(int land, int ent);

public SharedPlugin __pl_ink_build = 
{
	name = "InkMod Build",
	file = "ink_build.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};