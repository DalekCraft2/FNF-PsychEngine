package;

import flixel.util.FlxSave;
import haxe.Http;

using StringTools;

// Uh, I can find more stuff to put in here, I swear.
class EngineData
{
	// TODO Use FlxVersion for this (Possibly not; the version has a letter which doesn't fit into the FlxVersion format)

	/**
	 * The current version of this FNF engine. The value is retrieved during compilation from the "FNF_ENGINE_VERSION" definition in the Project.xml file.
	 * This is also used for Discord RPC.
	 */
	public static final ENGINE_VERSION:String = haxe.macro.Compiler.getDefine('FNF_ENGINE_VERSION');

	public static var latestVersion(default, null):String;
	public static var save(default, null):FlxSave = new FlxSave();

	public static function bindSave(name:String = 'mockEngineData', ?path:String):Void
	{
		var success:Bool = save.bind(name, path);
		if (success)
		{
			Debug.logInfo('Data loaded!');
		}
		else
		{
			Debug.logError('Could not bind save data!');
		}
	}

	public static function flushSave():Void
	{
		#if FEATURE_ACHIEVEMENTS
		EngineData.save.data.achievementsMap = Achievement.achievementMap;
		EngineData.save.data.henchmenDeath = Achievement.henchmenDeath;
		#end

		var success:Bool = save.flush();
		if (success)
		{
			Debug.logInfo('Data saved!');
		}
		else
		{
			Debug.logError('Could not flush save data!');
		}
	}

	public static function fetchLatestVersion():Void
	{
		Debug.logInfo('Checking for update');
		var http:Http = new Http('https://raw.githubusercontent.com/ShadowMario/FNF-PsychEngine/main/gitVersion.txt');
		http.onData = (data:String) ->
		{
			latestVersion = data.split('\n')[0].trim();
			var curVersion:String = EngineData.ENGINE_VERSION.trim();
			Debug.logInfo('Version online: $latestVersion, Your version: $curVersion');
			if (latestVersion != curVersion)
			{
				Debug.logWarn('Versions aren\'t matching!');
				// mustUpdate = true;
			}
		}
		http.onError = (error:String) ->
		{
			Debug.logError('Error: $error');
		}
		http.request();
	}
}
