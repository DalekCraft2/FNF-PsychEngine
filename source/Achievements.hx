package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import options.Options.OptionUtils;

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
	public static var achievementsStuff:Array<AchievementData> = [
		// Name, Description, Achievement save tag, Hidden achievement
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
	public static var achievementsMap:Map<String, Bool> = new Map<String, Bool>();

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
			loadGraphic(Paths.image('achievementgrid'), true, 150, 150);
			animation.add('icon', [Achievements.getAchievementIndex(tag)], 0, false, false);
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
		var achievementBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		achievementBG.scrollFactor.set();

		var achievementIcon:FlxSprite = new FlxSprite(achievementBG.x + 10, achievementBG.y + 10).loadGraphic(Paths.image('achievementgrid'), true, 150, 150);
		achievementIcon.animation.add('icon', [id], 0, false, false);
		achievementIcon.animation.play('icon');
		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = OptionUtils.options.globalAntialiasing;

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280,
			Achievements.achievementsStuff[id].name, 16);
		achievementName.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set();

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, Achievements.achievementsStuff[id].description, 16);
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
