package;

import haxe.io.Path;

using StringTools;

#if sys
import sys.FileSystem;
#end

typedef WeekData =
{
	// JSON variables
	var songs:Array<String>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:Array<String>;
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

	public static function createTemplateWeekData():WeekData
	{
		var weekData:WeekData = {
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
		return weekData;
	}

	// HELP: Is there any way to convert a WeekData to Week without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekData:WeekData, id:String)
	{
		songs = weekData.songs;
		weekCharacters = weekData.weekCharacters;
		weekBackground = weekData.weekBackground;
		weekBefore = weekData.weekBefore;
		storyName = weekData.storyName;
		weekName = weekData.weekName;
		startUnlocked = weekData.startUnlocked;
		hiddenUntilUnlocked = weekData.hiddenUntilUnlocked;
		hideStoryMode = weekData.hideStoryMode;
		hideFreeplay = weekData.hideFreeplay;
		difficulties = weekData.difficulties;

		this.id = id;
	}

	public static function reloadWeekData(isStoryMode:Bool = false):Void
	{
		// TODO This is very similar to the method for reloading Achievements, so I feel like there should instead be a common method

		weekList = [];
		weeksLoaded.clear();

		var directories:Array<String> = Paths.getDirectoryLoadOrder();

		for (directory in directories)
		{
			var weekDirectory:String = Path.join([directory, 'data/weeks']);
			var weekListPath:String = Path.join([weekDirectory, 'weekList.txt']);
			if (Paths.exists(weekListPath))
			{
				// Add weeks from weekList.txt first
				var weekListFromDir:Array<String> = CoolUtil.coolTextFile(weekListPath);
				for (weekId in weekListFromDir)
				{
					var path:String = Path.join([weekDirectory, Path.withExtension(weekId, 'json')]);
					if (Paths.exists(path))
					{
						addWeek(weekId, path, directory);
					}
				}
			}

			#if sys
			if (FileSystem.exists(weekDirectory))
			{
				// Add any weeks what were not included in the list but were in the directory
				for (file in FileSystem.readDirectory(weekDirectory))
				{
					var path:String = Path.join([weekDirectory, file]);
					if (!FileSystem.isDirectory(path) && Path.extension(path) == 'json')
					{
						var weekId:String = Path.withoutExtension(file);
						addWeek(weekId, path, directory);
					}
				}
			}
			#end
		}
	}

	private static function addWeek(id:String, path:String, directory:String):Void
	{
		if (!weeksLoaded.exists(id))
		{
			var data:WeekData = Paths.getJsonDirect(path);
			if (data != null)
			{
				var week:Week = new Week(data, id);
				#if FEATURE_MODS
				week.folder = directory.substring(Paths.mods().length, directory.length);
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
	public static function getWeekDataId():String
	{
		return weekList[PlayState.storyWeek];
	}

	// Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():Week
	{
		return weeksLoaded.get(getWeekDataId());
	}

	public static function setDirectoryFromWeek(?data:Week):Void
	{
		Paths.currentModDirectory = '';
		if (data != null && data.folder != null && data.folder.length > 0)
		{
			Paths.currentModDirectory = data.folder;
		}
	}

	public static function loadTheFirstEnabledMod():Void
	{
		Paths.currentModDirectory = '';

		#if FEATURE_MODS
		if (Paths.exists('modList.txt'))
		{
			var list:Array<String> = CoolUtil.listFromString(Paths.getTextDirect('modList.txt'));
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
