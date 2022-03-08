package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.Json;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
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

class Achievements
{
	public static var achievementShits:Array<AchievementData> = [
		// Name, Description, Achievement save tag, Unlocks after, Hidden achievement
		// Set unlock after to "null" if it doesnt unlock after a week!!
		{
			name: "Freaky on a Friday Night",
			description: "Play on a Friday... Night.",
			icon: 'friday_night_play',
			unlocksAfter: null,
			hidden: true,
			customGoal: false
		},
		{
			name: "She Calls Me Daddy Too",
			description: "Beat Week 1 on Hard with no Misses.",
			icon: 'week1_nomiss',
			unlocksAfter: 'week1',
			hidden: false,
			customGoal: false
		},
		{
			name: "No More Tricks",
			description: "Beat Week 2 on Hard with no Misses.",
			icon: 'week2_nomiss',
			unlocksAfter: 'week2',
			hidden: false,
			customGoal: false
		},
		{
			name: "Call Me The Hitman",
			description: "Beat Week 3 on Hard with no Misses.",
			icon: 'week3_nomiss',
			unlocksAfter: 'week3',
			hidden: false,
			customGoal: false
		},
		{
			name: "Lady Killer",
			description: "Beat Week 4 on Hard with no Misses.",
			icon: 'week4_nomiss',
			unlocksAfter: 'week4',
			hidden: false,
			customGoal: false
		},
		{
			name: "Missless Christmas",
			description: "Beat Week 5 on Hard with no Misses.",
			icon: 'week5_nomiss',
			unlocksAfter: 'week5',
			hidden: false,
			customGoal: false
		},
		{
			name: "Highscore!!",
			description: "Beat Week 6 on Hard with no Misses.",
			icon: 'week6_nomiss',
			unlocksAfter: 'week6',
			hidden: false,
			customGoal: false
		},
		{
			name: "You'll Pay For That...",
			description: "Beat Week 7 on Hard with no Misses.",
			icon: 'week7_nomiss',
			unlocksAfter: 'week7',
			hidden: true,
			customGoal: false
		},
		{
			name: "What a Funkin' Disaster!",
			description: "Complete a Song with a rating lower than 20%.",
			icon: 'ur_bad',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Perfectionist",
			description: "Complete a Song with a rating of 100%.",
			icon: 'ur_good',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Roadkill Enthusiast",
			description: "Watch the Henchmen die over 100 times.",
			icon: 'roadkill_enthusiast',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Oversinging Much...?",
			description: "Hold down a note for 10 seconds.",
			icon: 'oversinging',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Hyperactive",
			description: "Finish a Song without going Idle.",
			icon: 'hype',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Just the Two of Us",
			description: "Finish a Song pressing only two keys.",
			icon: 'two_keys',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Toaster Gamer",
			description: "Have you tried to run the game on a toaster?",
			icon: 'toastie',
			unlocksAfter: null,
			hidden: false,
			customGoal: false
		},
		{
			name: "Debugger",
			description: "Beat the \"Test\" Stage from the Chart Editor.",
			icon: 'debugger',
			unlocksAfter: null,
			hidden: true,
			customGoal: false
		}
	];

	public static var achievementsStuff:Array<AchievementData> = [
		// Gets filled when loading achievements
	];

	public static var achievementsMap:Map<String, Bool> = new Map<String, Bool>();
	public static var loadedAchievements:Map<String, AchievementData> = new Map<String, AchievementData>();

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
		if (achievementsMap.exists(name))
		{
			return achievementsMap.get(name);
		}
		return false;
	}

	public static function getAchievementIndex(name:String)
	{
		for (i in 0...achievementsStuff.length)
		{
			if (achievementsStuff[i].icon == name)
			{
				return i;
			}
		}
		return -1;
	}

	public static function loadAchievements():Void
	{
		achievementsStuff = [];
		achievementsStuff = achievementShits;

		#if FEATURE_MODS
		// reloadAchievements(); //custom achievements do not work. will add once it doesn't do the duplication bug -bb
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
				for (i in 0...savedStuff.length)
				{
					achievementsMap.set(savedStuff[i], true);
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

		// EDIT 2: Uhh this is weird, this message was written for MInd Games, so it doesn't apply logically for Psych Engine LOL
	}

	public static function reloadAchievements()
	{ // Achievements in game are hardcoded, no need to make a folder for them
		// TODO Screw hardcoding. I want to make these into JSONs.
		loadedAchievements.clear();

		#if FEATURE_MODS // Based on Week.hx
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'modsList.txt';
		var directories:Array<String> = [Paths.mods()];
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

		for (i in 0...directories.length)
		{
			var directory:String = directories[i] + 'achievements/';

			// Debug.logTrace(directory);
			if (FileSystem.exists(directory))
			{
				var listOfAchievements:Array<String> = CoolUtil.coolTextFile(directory + 'achievementList.txt');

				for (achievement in listOfAchievements)
				{
					var path:String = directory + achievement + '.json';

					if (FileSystem.exists(path) && !loadedAchievements.exists(achievement) && achievement != PlayState.othersCodeName)
					{
						loadedAchievements.set(achievement, getAchievementInfo(path));
					}

					// Debug.logTrace(path);
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);

					var cutName:String = file.substr(0, file.length - 5);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json') && !loadedAchievements.exists(cutName) && cutName != PlayState.othersCodeName)
					{
						loadedAchievements.set(cutName, getAchievementInfo(path));
					}

					// Debug.logTrace(file);
				}
			}
		}

		for (json in loadedAchievements)
		{
			// Debug.logTrace(json);
			achievementsStuff.push({
				name: json.name,
				description: json.description,
				icon: json.icon,
				unlocksAfter: json.unlocksAfter,
				hidden: json.hidden,
				customGoal: json.customGoal
			});
		}
		#end
	}

	private static function getAchievementInfo(path:String):AchievementData
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
			var imagePath:FlxGraphic = Paths.image('achievementgrid');
			var isModIcon:Bool = false;

			if (Achievements.loadedAchievements.exists(tag))
			{
				isModIcon = true;
				imagePath = Paths.image(Achievements.loadedAchievements.get(tag).icon);
			}

			var index:Int = Achievements.getAchievementIndex(tag);
			if (isModIcon)
				index = 0;

			// Debug.logTrace(imagePath);

			loadGraphic(imagePath, true, 150, 150);
			animation.add('icon', [index], 0, false, false);
			animation.play('icon');
		}
		else
		{
			loadGraphic(Paths.image('lockedachievement'));
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
		var achieveName:String = Achievements.achievementsStuff[id].name;
		var text:String = Achievements.achievementsStuff[id].description;

		if (Achievements.loadedAchievements.exists(name))
		{
			id = 0;
			achieveName = Achievements.loadedAchievements.get(name).name;
			text = Achievements.loadedAchievements.get(name).description;
		}

		var achievementBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		achievementBG.scrollFactor.set();

		var imagePath = Paths.image('achievementgrid');
		var modsImage = null;
		var isModIcon:Bool = false;

		// fucking hell bro
		/*if (Achievements.loadedAchievements.exists(name)) {
			isModIcon = true;
			modsImage = Paths.image(Achievements.loadedAchievements.get(name).icon);
		}*/

		var index:Int = Achievements.getAchievementIndex(name);
		if (isModIcon)
			index = 0;

		// Debug.logTrace(imagePath);
		// Debug.logTrace(modsImage);

		var achievementIcon:FlxSprite = new FlxSprite(achievementBG.x + 10,
			achievementBG.y + 10).loadGraphic((isModIcon ? modsImage : imagePath), true, 150, 150);
		achievementIcon.animation.add('icon', [index], 0, false, false);
		achievementIcon.animation.play('icon');
		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = OptionUtils.options.globalAntialiasing;

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280, achieveName, 16);
		achievementName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set();

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, text, 16);
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
