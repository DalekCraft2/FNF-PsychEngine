package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import options.Options.OptionUtils;
#if FEATURE_MODS
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef AchievementData =
{
	var name:String;
	var description:String;
	var icon:String;
	var unlocksAfter:String;
	var hidden:Bool;
	var customGoal:Bool;
}

// TODO I think that they removed the JSON stuff for achievements. I'll need to reimplement that.
class Achievements
{
	public static var achievementList:Array<AchievementData> = [
		// Gets filled when loading achievements
	];
	public static var achievementsMap:Map<String, Bool> = new Map<String, Bool>();
	public static var achievementsLoaded:Map<String, AchievementData> = new Map<String, AchievementData>();

	public static var henchmenDeath:Int = 0;

	public static function unlockAchievement(name:String):Void
	{
		Debug.logTrace('Completed achievement "$name"');
		achievementsMap.set(name, true);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		// TODO Stop relying on FlxG.save for so much stuff.
		FlxG.save.data.achievementsMap = achievementsMap;
		FlxG.save.flush();
	}

	public static function isAchievementUnlocked(name:String)
	{
		if (achievementsMap.exists(name) && achievementsMap.get(name))
		{
			return true;
		}
		return false;
	}

	public static function getAchievementIndex(name:String)
	{
		for (i in 0...achievementList.length)
		{
			var achievement = achievementList[i];
			if (achievement.icon == name)
			{
				return i;
			}
		}
		return -1;
	}

	public static function loadAchievements():Void
	{
		#if FEATURE_MODS
		reloadAchievementData();
		#end

		if (FlxG.save.data != null)
		{
			if (FlxG.save.data.achievementsMap != null)
			{
				achievementsMap = FlxG.save.data.achievementsMap;
			}
			if (FlxG.save.data.achievementsUnlocked != null)
			{
				Debug.logTrace("Trying to load stuff");
				var savedStuff:Array<String> = FlxG.save.data.achievementsUnlocked;
				for (achievementId in savedStuff)
				{
					achievementsMap.set(achievementId, true);
				}
			}
			if (henchmenDeath == 0 && FlxG.save.data.henchmenDeath != null)
			{
				henchmenDeath = FlxG.save.data.henchmenDeath;
			}
		}

		// You might be asking "Why didn't you just fucking load it directly dumbass??"
		// Well, Mr. Smartass, consider that this class was made for Mind Games Mod's demo,
		// i'm obviously going to change the "Psyche" achievement's objective so that you have to complete the entire week
		// with no misses instead of just Psychic once the full release is out. So, for not having the rest of your achievements lost on
		// the full release, we only save the achievements' tag names instead. This also makes me able to rename
		// achievements later as long as the tag names aren't changed of course.

		// Edit: Oh yeah, just thought that this also makes me able to change the achievements orders easier later if i want to.
		// So yeah, if you didn't thought about that i'm smarter than you, i think

		// buffoon

		// EDIT 2: Uhh this is weird, this message was written for Mind Games, so it doesn't apply logically for Psych Engine LOL
	}

	public static function reloadAchievementData()
	{
		achievementList = [];
		achievementsLoaded.clear();
		#if FEATURE_MODS
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'modsList.txt';
		var directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
		if (FileSystem.exists(modsListPath))
		{
			var stuff:Array<String> = CoolUtil.coolTextFile(modsListPath);
			for (mod in stuff)
			{
				var splitName:Array<String> = mod.trim().split('|');
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
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.txt('achievements/achievementList.txt'));
		for (achievement in sexList)
		{
			if (Paths.fileExists('$achievement.json', TEXT, true, ''))
				addAchievement(achievement);
		}

		#if FEATURE_MODS
		for (folder in directories)
		{
			var directory:String = '${folder}data/achievements/';
			if (FileSystem.exists(directory))
			{
				var listOfAchievements:Array<String> = CoolUtil.coolTextFile(directory + 'achievementsList.txt');
				for (daAchievement in listOfAchievements)
				{
					var path:String = '$directory$daAchievement.json';
					if (FileSystem.exists(path))
					{
						addAchievement(daAchievement);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var cutName:String = file.substr(0, file.length - '.json'.length);
						addAchievement(cutName);
					}
				}
			}
		}
		#end

		Debug.logTrace('List: $achievementList');
		Debug.logTrace('Loaded: $achievementsLoaded');
	}

	private static function addAchievement(achievement:String)
	{
		if (!achievementsLoaded.exists(achievement))
		{
			var achievementData:AchievementData = getAchievementData(achievement);
			if (achievementData != null)
			{
				achievementsLoaded.set(achievement, achievementData);
				achievementList.push(achievementData);
			}
		}
	}

	private static function getAchievementData(achievement:String):AchievementData
	{
		var achievementPath:String = 'achievements/$achievement';
		var rawJson = Paths.loadJson(achievementPath);
		var achievementData:AchievementData = cast rawJson;
		return achievementData;
	}
}

class AttachedAchievement extends FlxSprite
{
	public var sprTracker:FlxSprite;

	private var tag:String;

	public function new(x:Float = 0, y:Float = 0, name:String)
	{
		super(x, y);

		changeAchievement(name);
		antialiasing = OptionUtils.options.globalAntialiasing;
	}

	public function changeAchievement(tag:String)
	{
		this.tag = tag;
		reloadAchievementImage();
	}

	public function reloadAchievementImage()
	{
		if (Achievements.isAchievementUnlocked(tag))
		{
			var graphic = Paths.image('achievements/$tag');
			if (graphic == null)
				graphic = Paths.image('achievements/missing');
			loadGraphic(graphic);
		}
		else
		{
			loadGraphic(Paths.image('achievements/locked'));
		}
		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float)
	{
		if (sprTracker != null)
			setPosition(sprTracker.x - 130, sprTracker.y + 25);

		super.update(elapsed);
	}
}

class Achievement extends FlxSpriteGroup
{
	public var onFinish:Void->Void = null;

	var alphaTween:FlxTween;

	public function new(name:String, ?camera:FlxCamera = null)
	{
		super(x, y);
		OptionUtils.saveOptions(OptionUtils.options);

		var id:Int = Achievements.getAchievementIndex(name);
		var achievementBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		achievementBG.scrollFactor.set();

		var achievementIcon:FlxSprite = new FlxSprite(achievementBG.x + 10, achievementBG.y + 10).loadGraphic(Paths.image('achievements/$name'));
		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = OptionUtils.options.globalAntialiasing;

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280,
			Achievements.achievementList[id].name, 16);
		achievementName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set();

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, Achievements.achievementList[id].description, 16);
		achievementText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementText.scrollFactor.set();

		add(achievementBG);
		add(achievementName);
		add(achievementText);
		add(achievementIcon);

		var cam:Array<FlxCamera> = FlxCamera.defaultCameras;
		if (camera != null)
		{
			cam = [camera];
		}
		alpha = 0;
		achievementBG.cameras = cam;
		achievementName.cameras = cam;
		achievementText.cameras = cam;
		achievementIcon.cameras = cam;
		alphaTween = FlxTween.tween(this, {alpha: 1}, 0.5, {
			onComplete: function(twn:FlxTween)
			{
				alphaTween = FlxTween.tween(this, {alpha: 0}, 0.5, {
					startDelay: 2.5,
					onComplete: function(twn:FlxTween)
					{
						alphaTween = null;
						remove(this);
						if (onFinish != null)
							onFinish();
					}
				});
			}
		});
	}

	override function destroy()
	{
		if (alphaTween != null)
		{
			alphaTween.cancel();
		}
		super.destroy();
	}
}
