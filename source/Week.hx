package;

import haxe.Json;
import openfl.utils.Assets;
#if FEATURE_MODS
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

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
	public static var weeksLoaded:Map<String, Week> = [];
	public static var weeksList:Array<String> = [];

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

	public var fileName:String;

	public static function createWeekData():WeekData
	{
		var weekData:WeekData = {
			songs: ["bopeebo", "fresh", "dadbattle"],
			weekCharacters: ['dad', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: 'tutorial',
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
	public function new(weekData:WeekData, fileName:String)
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

		this.fileName = fileName;
	}

	public static function reloadWeekData(isStoryMode:Null<Bool> = false):Void
	{
		weeksList = [];
		weeksLoaded.clear();
		#if FEATURE_MODS
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'modsList.txt';
		var directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
		if (FileSystem.exists(modsListPath))
		{
			var modList:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (mod in modList)
			{
				var splitName:Array<String> = mod.trim().split('|');
				if (splitName[1] == '0') // Disable mod
				{
					disabledMods.push(splitName[0]);
				}
				else // Sort mod loading order based on modsList.txt file
				{
					// TODO Maybe use the Path class as an object more often instead of Strings
					var path:String = Path.join([Paths.mods(), splitName[0]]);
					// Debug.logTrace('Trying to push: ${splitName[0]}');
					if (FileSystem.isDirectory(path)
						&& !Paths.IGNORE_MOD_FOLDERS.contains(splitName[0])
						&& !disabledMods.contains(splitName[0])
						&& !directories.contains('$path/'))
					{
						directories.push('$path/');
						// Debug.logTrace('Pushed Directory: ${splitName[0]}');
					}
				}
			}
		}

		var modsDirectories:Array<String> = Paths.getModDirectories();
		for (modDirectory in modsDirectories)
		{
			var modPath:String = '${Path.join([Paths.mods(), modDirectory])}/';
			if (!disabledMods.contains(modDirectory) && !directories.contains(modPath))
			{
				directories.push(modPath);
				// Debug.logTrace('Pushed Directory: $modDirectory');
			}
		}
		#else
		var directories:Array<String> = [Paths.getPreloadPath()];
		#end

		var weekList:Array<String> = CoolUtil.coolTextFile(Paths.getPreloadPath('data/weeks/weekList.txt'));
		for (weekId in weekList)
		{
			for (directory in directories)
			{
				var fileToCheck:String = '${directory}data/weeks/${weekId}.json';
				if (!weeksLoaded.exists(weekId))
				{
					var weekData:WeekData = getWeekData(fileToCheck);
					if (weekData != null)
					{
						var week:Week = new Week(weekData, weekId);
						#if FEATURE_MODS
						week.folder = directory.substring(Paths.mods().length, directory.length - 1);
						#end

						if (week != null
							&& (isStoryMode == null || (isStoryMode && !week.hideStoryMode) || (!isStoryMode && !week.hideFreeplay)))
						{
							weeksLoaded.set(weekId, week);
							weeksList.push(weekId);
						}
					}
				}
			}
		}

		#if FEATURE_MODS
		for (directory in directories)
		{
			var weekDirectory:String = '${directory}data/weeks/';
			if (FileSystem.exists(weekDirectory))
			{
				var weekList:Array<String> = CoolUtil.coolTextFile('$weekDirectory/weekList.txt');
				for (weekId in weekList)
				{
					var path:String = '$weekDirectory$weekId.json';
					if (FileSystem.exists(path))
					{
						addWeek(weekId, path, directory);
					}
				}

				for (file in FileSystem.readDirectory(weekDirectory))
				{
					var path:String = Path.join([weekDirectory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var weekId:String = file.substr(0, file.length - '.json'.length);
						addWeek(weekId, path, directory);
					}
				}
			}
		}
		#end
	}

	private static function addWeek(weekId:String, path:String, directory:String):Void
	{
		if (!weeksLoaded.exists(weekId))
		{
			var weekData:WeekData = getWeekData(path);
			if (weekData != null)
			{
				var week:Week = new Week(weekData, weekId);
				#if FEATURE_MODS
				week.folder = directory.substring(Paths.mods().length, directory.length - 1);
				#end
				if ((PlayState.isStoryMode && !week.hideStoryMode) || (!PlayState.isStoryMode && !week.hideFreeplay))
				{
					weeksLoaded.set(weekId, week);
					weeksList.push(weekId);
				}
			}
		}
	}

	private static function getWeekData(weekPath:String):WeekData
	{
		var rawJson:String = null;
		#if FEATURE_MODS
		if (FileSystem.exists(weekPath))
		{
			rawJson = File.getContent(weekPath);
		}
		#else
		if (Assets.exists(weekPath))
		{
			rawJson = Assets.getText(weekPath);
		}
		#end

		if (rawJson != null && rawJson.length > 0)
		{
			return cast Json.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE
	// To use on PlayState.hx or Highscore stuff
	public static function getWeekDataName():String
	{
		return weeksList[PlayState.storyWeek];
	}

	// Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():Week
	{
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
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
		if (FileSystem.exists("modsList.txt"))
		{
			var list:Array<String> = CoolUtil.listFromString(File.getContent("modsList.txt"));
			var foundTheTop = false;
			for (i in list)
			{
				var dat:Array<String> = i.split("|");
				if (dat[1] == "1" && !foundTheTop)
				{
					foundTheTop = true;
					Paths.currentModDirectory = dat[0];
				}
			}
		}
		#end
	}
}
