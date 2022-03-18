package;

import flixel.graphics.FlxGraphic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.utils.Assets;
#if FEATURE_MODS
import haxe.io.Path;
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

class Achievement extends FlxSpriteGroup
{
	// Gets filled when loading achievements
	public static var achievementList:Array<String> = [];
	public static var achievementsMap:Map<String, Bool> = [];
	public static var achievementsLoaded:Map<String, AchievementData> = [];

	public static var henchmenDeath:Int = 0;

	public var onFinish:() -> Void = null;

	var alphaTween:FlxTween;

	public static function unlockAchievement(name:String):Void
	{
		Debug.logTrace('Completed achievement "$name"');
		achievementsMap.set(name, true);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		// TODO Stop relying on FlxG.save for so much stuff.
		FlxG.save.data.achievementsMap = achievementsMap;
		FlxG.save.flush();
	}

	public static function isAchievementUnlocked(name:String):Bool
	{
		if (achievementsMap.exists(name) && achievementsMap.get(name))
		{
			return true;
		}
		return false;
	}

	public static function getAchievementIndex(name:String):Int
	{
		return achievementList.indexOf(name);
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

	public static function reloadAchievementData():Void
	{
		achievementList = [];
		achievementsLoaded.clear();
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
			var pathThing:String = '${Path.join([Paths.mods(), modDirectory])}/';
			if (!disabledMods.contains(modDirectory) && !directories.contains(modDirectory))
			{
				directories.push(pathThing);
				// Debug.logTrace('Pushed Directory: $modDirectory');
			}
		}
		#else
		var directories:Array<String> = [Paths.getPreloadPath()];
		#end

		var achievementList:Array<String> = CoolUtil.coolTextFile(Paths.txt('achievements/achievementList'));
		for (achievementId in achievementList)
		{
			for (directory in directories)
			{
				var fileToCheck:String = '${directory}data/achievements/${achievementId}.json';
				if (!achievementsLoaded.exists(achievementId))
				{
					var achievementData:AchievementData = getAchievementData(fileToCheck);
					if (achievementData != null)
					{
						achievementsLoaded.set(achievementId, achievementData);
						Achievement.achievementList.push(achievementId);
					}
				}
			}
		}

		#if FEATURE_MODS
		for (directory in directories)
		{
			var achievementDirectory:String = '${directory}data/achievements/';
			if (FileSystem.exists(achievementDirectory))
			{
				var listOfAchievements:Array<String> = CoolUtil.coolTextFile('${achievementDirectory}achievementsList.txt');
				for (achievementId in listOfAchievements)
				{
					var path:String = '$achievementDirectory$achievementId.json';
					if (FileSystem.exists(path))
					{
						addAchievement(achievementId);
					}
				}

				for (file in FileSystem.readDirectory(achievementDirectory))
				{
					var path:String = Path.join([achievementDirectory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var achievementId:String = file.substr(0, file.length - '.json'.length);
						addAchievement(achievementId);
					}
				}
			}
		}
		#end
	}

	private static function addAchievement(achievementId:String):Void
	{
		if (!achievementsLoaded.exists(achievementId))
		{
			var achievementData:AchievementData = getAchievementData(achievementId);
			if (achievementData != null)
			{
				achievementsLoaded.set(achievementId, achievementData);
				achievementList.push(achievementId);
			}
		}
	}

	private static function getAchievementData(achievementPath:String):AchievementData
	{
		var rawJson:String = null;
		#if FEATURE_MODS
		if (FileSystem.exists(achievementPath))
		{
			rawJson = File.getContent(achievementPath);
		}
		#else
		if (Assets.exists(achievementPath))
		{
			rawJson = Assets.getText(achievementPath);
		}
		#end

		if (rawJson != null && rawJson.length > 0)
		{
			return cast Json.parse(rawJson);
		}
		return null;
	}

	public function new(name:String, ?camera:FlxCamera = null)
	{
		super(x, y);

		Options.saveOptions();

		var id:Int = getAchievementIndex(name);
		var achievementBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		achievementBG.scrollFactor.set();

		var achievementIcon:FlxSprite = new FlxSprite(achievementBG.x + 10, achievementBG.y + 10).loadGraphic(Paths.getGraphic('achievements/$name'));
		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = Options.save.data.globalAntialiasing;

		var achievementId:String = achievementList[id];
		var achievement:AchievementData = achievementsLoaded.get(achievementId);

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280, achievement.name, 16);
		achievementName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set();

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, achievement.description, 16);
		achievementText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementText.scrollFactor.set();

		add(achievementBG);
		add(achievementName);
		add(achievementText);
		add(achievementIcon);

		alpha = 0;
		alphaTween = FlxTween.tween(this, {alpha: 1}, 0.5, {
			onComplete: (twn:FlxTween) ->
			{
				alphaTween = FlxTween.tween(this, {alpha: 0}, 0.5, {
					startDelay: 2.5,
					onComplete: (twn:FlxTween) ->
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

	override function destroy():Void
	{
		super.destroy();

		if (alphaTween != null)
		{
			alphaTween.cancel();
		}
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
		antialiasing = Options.save.data.globalAntialiasing;
	}

	public function changeAchievement(tag:String):Void
	{
		this.tag = tag;
		reloadAchievementImage();
	}

	public function reloadAchievementImage():Void
	{
		if (Achievement.isAchievementUnlocked(tag))
		{
			var graphic:FlxGraphic = Paths.getGraphic('achievements/$tag');
			if (graphic == null)
				graphic = Paths.getGraphic('achievements/missing');
			loadGraphic(graphic);
		}
		else
		{
			loadGraphic(Paths.getGraphic('achievements/locked'));
		}
		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x - 130, sprTracker.y + 25);
	}
}
