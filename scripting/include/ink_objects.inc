#define _ink_objects_included_


forward void OnObjectsReady();
forward void OnObjectCreated(int index, StringMap obj);
forward void OnObjectDestroyed(int index);
native StringMap GetInkObject(int index, bool create = false);

#if !defined REQUIRE_PLUGIN
public void __pl_ink_objects_SetNTVOptional()
{
	MarkNativeAsOptional("GetInkObject");
}
#endif

public SharedPlugin __pl_ink_objects = 
{
	name = "InkMod Objects",
	file = "ink_objects.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};