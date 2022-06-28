package;

import flixel.util.FlxArrayUtil;
#if FEATURE_ACHIEVEMENTS
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import haxe.io.Path;
import util.CoolUtil;

using StringTools;

typedef AchievementDef =
{
	var name:String;
	var description:String;
	var icon:String;
	var unlocksAfter:String;
	var hidden:Bool;
	// TODO Figure out how this was used initially
	var customGoal:Bool;
	var modDirectory:String;
}

class Achievement extends FlxSpriteGroup
{
	// Gets filled when loading achievements
	public static var achievementsLoaded:Map<String, AchievementDef> = [];
	public static var achievementList:Array<String> = [];
	public static var achievementMap:Map<String, Bool> = [];

	public static var henchmenDeath:Int = 0;

	public var onFinish:() -> Void;

	private var alphaTween:FlxTween;

	public static function unlockAchievement(id:String):Void
	{
		Debug.logTrace('Completed achievement "$id"');
		achievementMap.set(id, true);
		FlxG.sound.play(Paths.getSound('confirmMenu'), 0.7);
		EngineData.save.data.achievementMap = achievementMap;
		EngineData.flushSave();
	}

	public static function isAchievementUnlocked(id:String):Bool
	{
		return achievementMap.exists(id) && achievementMap.get(id);
	}

	public static function loadAchievements():Void
	{
		reloadAchievementDef();

		if (EngineData.save.data != null)
		{
			if (EngineData.save.data.achievementMap != null)
			{
				achievementMap = EngineData.save.data.achievementMap;
			}
			if (EngineData.save.data.achievementsUnlocked != null)
			{
				var achievementsUnlocked:Array<String> = EngineData.save.data.achievementsUnlocked;
				for (achievementId in achievementsUnlocked)
				{
					if (!achievementMap.exists(achievementId))
					{
						achievementMap.set(achievementId, true);
					}
				}
				// Get rid of this probably-legacy data
				EngineData.save.data.achievementsUnlocked = null;
			}
			if (henchmenDeath == 0 && EngineData.save.data.henchmenDeath != null)
			{
				henchmenDeath = EngineData.save.data.henchmenDeath;
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

	public static function reloadAchievementDef():Void
	{
		FlxArrayUtil.clearArray(achievementList);
		achievementsLoaded.clear();

		var directories:Array<String> = Paths.getDirectoryLoadOrder();

		for (directory in directories)
		{
			var achievementDirectory:String = Path.join([directory, 'data/achievements']);
			var achievementListPath:String = Path.join([achievementDirectory, Path.withExtension('achievementList', Paths.TEXT_EXT)]);
			if (Paths.exists(achievementListPath))
			{
				// Add achievements from achievementList.txt first
				var achievementListFromDir:Array<String> = CoolUtil.listFromTextFile(achievementListPath);
				for (achievementId in achievementListFromDir)
				{
					var path:String = Path.join([achievementDirectory, Path.withExtension(achievementId, Paths.JSON_EXT)]);
					if (Paths.exists(path))
					{
						addAchievement(achievementId, path);
					}
				}
			}

			if (Paths.fileSystem.exists(achievementDirectory))
			{
				// Add any achievements what were not included in the list but were in the directory
				for (file in Paths.fileSystem.readDirectory(achievementDirectory))
				{
					var path:String = Path.join([achievementDirectory, file]);
					if (!Paths.fileSystem.isDirectory(path) && Path.extension(path) == Paths.JSON_EXT)
					{
						var achievementId:String = Path.withoutExtension(file);
						addAchievement(achievementId, path);
					}
				}
			}
		}
	}

	private static function addAchievement(id:String, path:String):Void
	{
		if (!achievementsLoaded.exists(id))
		{
			var def:AchievementDef = Paths.getJsonDirect(path);
			if (def != null)
			{
				achievementsLoaded.set(id, def);
				achievementList.push(id);
			}
		}
	}

	public function new(id:String)
	{
		super(x, y);

		EngineData.flushSave();

		var achievementDef:AchievementDef = achievementsLoaded.get(id);

		var achievementBG:FlxSprite = new FlxSprite(60, 50).makeGraphic(420, 120, FlxColor.BLACK);
		achievementBG.scrollFactor.set();

		var achievementIcon:FlxSprite = new FlxSprite(achievementBG.x + 10,
			achievementBG.y + 10).loadGraphic(Paths.getGraphic(Path.join(['achievements', achievementDef.icon])));
		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();
		achievementIcon.antialiasing = Options.save.data.globalAntialiasing;

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280, achievementDef.name, 16);
		achievementName.setFormat(Paths.font('vcr.ttf'), achievementName.size, FlxColor.WHITE, LEFT);
		achievementName.scrollFactor.set();

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, achievementDef.description, 16);
		achievementText.setFormat(Paths.font('vcr.ttf'), achievementText.size, FlxColor.WHITE, LEFT);
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

	override public function destroy():Void
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

	// TODO Try to think of a name other than "id", because "ID" is a field used in FlxBasic
	private var id:String;

	public function new(x:Float = 0, y:Float = 0, id:String)
	{
		super(x, y);

		changeAchievement(id);
		antialiasing = Options.save.data.globalAntialiasing;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x - 130, sprTracker.y + 25);
	}

	public function changeAchievement(id:String):Void
	{
		this.id = id;
		reloadAchievementImage();
	}

	public function reloadAchievementImage():Void
	{
		if (Achievement.isAchievementUnlocked(id))
		{
			var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(id);
			if (achievementDef != null)
			{
				var graphic:FlxGraphicAsset = Paths.getGraphic(Path.join(['achievements', achievementDef.icon]));
				if (graphic == null)
					graphic = Paths.getGraphic('achievements/missing');
				loadGraphic(graphic);
			}
		}
		else
		{
			loadGraphic(Paths.getGraphic('achievements/locked'));
		}
		scale.set(0.7, 0.7);
		updateHitbox();
	}
}
#end
