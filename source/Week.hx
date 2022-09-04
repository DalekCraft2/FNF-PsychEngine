package;

import flixel.util.FlxArrayUtil;
import haxe.io.Path;
import states.PlayState;
import util.CoolUtil;

using StringTools;

typedef WeekDef =
{
	songs:Array<String>,
	weekCharacters:Array<String>,
	weekBackground:String,
	weekBefore:String,
	storyName:String,
	weekName:String,
	startUnlocked:Bool,
	hiddenUntilUnlocked:Bool,
	hideStoryMode:Bool,
	hideFreeplay:Bool,
	difficulties:Array<String>
}

class Week
{
	/**
	 * The week ID used in case the requested week is missing.
	 */
	public static inline final DEFAULT_WEEK:String = 'tutorial';

	public static var weeksLoaded:Map<String, Week> = [];
	public static var weekList:Array<String> = [];

	public var id:String;
	public var folder:String = '';

	// JSON variables
	public var songs:Array<String>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:Array<String>;

	public static function createTemplateWeekDef():WeekDef
	{
		var weekDef:WeekDef = {
			songs: ['bopeebo', 'fresh', 'dadbattle'],
			weekCharacters: ['dad', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: '',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: []
		};
		return weekDef;
	}

	// HELP: Is there any way to convert a WeekDef to Week without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekDef:WeekDef, id:String)
	{
		songs = weekDef.songs;
		weekCharacters = weekDef.weekCharacters;
		weekBackground = weekDef.weekBackground;
		weekBefore = weekDef.weekBefore;
		storyName = weekDef.storyName;
		weekName = weekDef.weekName;
		startUnlocked = weekDef.startUnlocked;
		hiddenUntilUnlocked = weekDef.hiddenUntilUnlocked;
		hideStoryMode = weekDef.hideStoryMode;
		hideFreeplay = weekDef.hideFreeplay;
		difficulties = weekDef.difficulties;

		this.id = id;
	}

	public static function reloadWeekData(isStoryMode:Bool = false):Void
	{
		// TODO This is very similar to the method for reloading Achievements, so I feel like there should instead be a common method

		FlxArrayUtil.clearArray(weekList);
		weeksLoaded.clear();

		var directories:Array<String> = Paths.getDirectoryLoadOrder();

		for (directory in directories)
		{
			var weekDirectory:String = Path.join([directory, 'data', 'weeks']);
			var weekListPath:String = Path.join([weekDirectory, Path.withExtension('weekList', Paths.TEXT_EXT)]);
			if (Paths.exists(weekListPath))
			{
				// Add weeks from weekList.txt first
				var weekListFromDir:Array<String> = CoolUtil.listFromTextFile(weekListPath);
				for (weekId in weekListFromDir)
				{
					var path:String = Path.join([weekDirectory, Path.withExtension(weekId, Paths.JSON_EXT)]);
					if (Paths.exists(path))
					{
						addWeek(weekId, path,
							directory); // FIXME This will set the vanilla weeks' directory name to "assets" when it should be an empty string
					}
				}
			}

			if (Paths.fileSystem.exists(weekDirectory))
			{
				// Add any weeks what were not included in the list but were in the directory
				for (file in Paths.fileSystem.readDirectory(weekDirectory))
				{
					var path:String = Path.join([weekDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.JSON_EXT)
					{
						var weekId:String = Path.withoutExtension(file);
						addWeek(weekId, path, directory);
					}
				}
			}
		}
	}

	private static function addWeek(id:String, path:String, directory:String):Void
	{
		if (!weeksLoaded.exists(id))
		{
			var def:WeekDef = Paths.getJsonDirect(path);
			if (def != null)
			{
				var week:Week = new Week(def, id);
				#if FEATURE_MODS
				// week.folder = directory.substring(Paths.MOD_DIRECTORY.length, directory.length);
				week.folder = Path.withoutDirectory(directory);
				#end
				if ((PlayState.isStoryMode && !week.hideStoryMode) || (!PlayState.isStoryMode && !week.hideFreeplay))
				{
					weeksLoaded.set(id, week);
					weekList.push(id);
				}
			}
		}
	}

	// FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE
	// To use on PlayState.hx or Highscore stuff
	public static function getCurrentWeekId():String
	{
		return weekList[PlayState.storyWeek];
	}

	// Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():Week
	{
		return weeksLoaded.get(getCurrentWeekId());
	}

	public static function setDirectoryFromWeek(?week:Week):Void
	{
		Paths.currentModDirectory = '';
		if (week != null && week.folder != null && week.folder.length > 0)
		{
			Paths.currentModDirectory = week.folder;
		}
	}

	// TODO Shouldn't this be in a class related to Mods, like Mod.hx or ModCore.hx?
	public static function loadTheFirstEnabledMod():Void
	{
		Paths.currentModDirectory = '';

		#if FEATURE_MODS
		var modListPath:String = Path.withExtension('modList', Paths.TEXT_EXT);
		if (Paths.exists(modListPath))
		{
			var list:Array<String> = CoolUtil.listFromString(Paths.getTextDirect(modListPath));
			var foundTheTop:Bool = false;
			for (i in list)
			{
				var dat:Array<String> = i.split('|');
				if (dat[1] == '1' && !foundTheTop)
				{
					foundTheTop = true;
					Paths.currentModDirectory = dat[0];
				}
			}
		}
		#end
	}
}
