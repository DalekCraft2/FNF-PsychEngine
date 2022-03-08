package;

import haxe.Json;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
#if FEATURE_MODS
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef WeekData =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

class Week
{
	public static var weeksLoaded:Map<String, Week> = new Map<String, Week>();
	public static var weeksList:Array<String> = [];

	public var folder:String = '';

	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var freeplayColor:Array<Int>;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekData():WeekData
	{
		var weekData:WeekData = {
			songs: [
				["bopeebo", "dad", [146, 113, 253]],
				["fresh", "dad", [146, 113, 253]],
				["dadbattle", "dad", [146, 113, 253]]
			],
			weekCharacters: ['dad', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			freeplayColor: [146, 113, 253],
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
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
		freeplayColor = weekData.freeplayColor;
		startUnlocked = weekData.startUnlocked;
		hiddenUntilUnlocked = weekData.hiddenUntilUnlocked;
		hideStoryMode = weekData.hideStoryMode;
		hideFreeplay = weekData.hideFreeplay;
		difficulties = weekData.difficulties;

		this.fileName = fileName;
	}

	public static function reloadWeekData(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if FEATURE_MODS
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'modsList.txt';
		var directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
		if (FileSystem.exists(modsListPath))
		{
			var stuff:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (i in 0...stuff.length)
			{
				var splitName:Array<String> = stuff[i].trim().split('|');
				if (splitName[1] == '0') // Disable mod
				{
					disabledMods.push(splitName[0]);
				}
				else // Sort mod loading order based on modsList.txt file
				{
					var path = haxe.io.Path.join([Paths.mods(), splitName[0]]);
					// Debug.logTrace('Trying to push: ${splitName[0]}');
					if (FileSystem.isDirectory(path)
						&& !Paths.ignoreModFolders.contains(splitName[0])
						&& !disabledMods.contains(splitName[0])
						&& !directories.contains(path + '/'))
					{
						directories.push(path + '/');
						// Debug.logTrace('Pushed Directory: ${splitName[0]}');
					}
				}
			}
		}

		var modsDirectories:Array<String> = Paths.getModDirectories();
		for (folder in modsDirectories)
		{
			var pathThing:String = haxe.io.Path.join([Paths.mods(), folder]) + '/';
			if (!disabledMods.contains(folder) && !directories.contains(pathThing))
			{
				directories.push(pathThing);
				// Debug.logTrace('Pushed Directory: $folder');
			}
		}
		#else
		var directories:Array<String> = [Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getPreloadPath('weeks/weekList.txt'));
		for (i in 0...sexList.length)
		{
			for (j in 0...directories.length)
			{
				var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if (!weeksLoaded.exists(sexList[i]))
				{
					var weekData:WeekData = getWeekData(fileToCheck);
					if (weekData != null)
					{
						var week:Week = new Week(weekData, sexList[i]);

						#if FEATURE_MODS
						if (j >= originalLength)
						{
							week.folder = directories[j].substring(Paths.mods().length, directories[j].length - 1);
						}
						#end

						if (week != null
							&& (isStoryMode == null || (isStoryMode && !week.hideStoryMode) || (!isStoryMode && !week.hideFreeplay)))
						{
							weeksLoaded.set(sexList[i], week);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if FEATURE_MODS
		for (i in 0...directories.length)
		{
			var directory:String = directories[i] + 'weeks/';
			if (FileSystem.exists(directory))
			{
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if (FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}
		#end
	}

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
	{
		if (!weeksLoaded.exists(weekToCheck))
		{
			var weekData:WeekData = getWeekData(path);
			if (weekData != null)
			{
				var week:Week = new Week(weekData, weekToCheck);
				if (i >= originalLength)
				{
					#if FEATURE_MODS
					week.folder = directory.substring(Paths.mods().length, directory.length - 1);
					#end
				}
				if ((PlayState.isStoryMode && !week.hideStoryMode) || (!PlayState.isStoryMode && !week.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, week);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	private static function getWeekData(path:String):WeekData
	{
		var rawJson:String = null;
		#if FEATURE_MODS
		if (FileSystem.exists(path))
		{
			rawJson = File.getContent(path);
		}
		#else
		if (OpenFlAssets.exists(path))
		{
			rawJson = Assets.getText(path);
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

	public static function setDirectoryFromWeek(?data:Week = null)
	{
		Paths.currentModDirectory = '';
		if (data != null && data.folder != null && data.folder.length > 0)
		{
			Paths.currentModDirectory = data.folder;
		}
	}

	public static function loadTheFirstEnabledMod()
	{
		Paths.currentModDirectory = '';

		#if FEATURE_MODS
		if (FileSystem.exists("modsList.txt"))
		{
			var list:Array<String> = CoolUtil.listFromString(File.getContent("modsList.txt"));
			var foundTheTop = false;
			for (i in list)
			{
				var dat = i.split("|");
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
