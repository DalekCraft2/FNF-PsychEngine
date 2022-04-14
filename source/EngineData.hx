package;

import flixel.util.FlxSave;

// Uh, I can find more stuff to put in here, I swear.
class EngineData
{
	// TODO Use FlxVersion for this (Possibly not; the version has a letter which doesn't fit into the FlxVersion format)
	public static final ENGINE_VERSION:String = '0.5.2h'; // This is also used for Discord RPC
	public static var save(default, null):FlxSave = new FlxSave();

	public static function bindSave(name:String = 'mockEngineData', ?path:String):Void
	{
		save.bind(name, path);
		Debug.logTrace('Data loaded!');
	}

	public static function flushSave():Void
	{
		#if FEATURE_ACHIEVEMENTS
		EngineData.save.data.achievementsMap = Achievement.achievementMap;
		EngineData.save.data.henchmenDeath = Achievement.henchmenDeath;
		#end

		save.flush();
		Debug.logTrace('Data saved!');
	}
}
