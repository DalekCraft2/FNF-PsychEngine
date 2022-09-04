package states;

#if FEATURE_ACHIEVEMENTS
import Achievement.AchievementDef;
import Achievement.AttachedAchievement;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.io.Path;
import ui.Alphabet;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class AchievementsMenuState extends MusicBeatState implements ListMenu
{
	private static var curSelected:Int = 0;

	private var achievements:Array<String> = [];
	private var grpAchievements:FlxTypedGroup<Alphabet>;

	private var achievementArray:Array<AttachedAchievement> = [];
	private var achievementIndex:Array<Int> = [];
	private var descText:FlxText;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		DiscordClient.changePresence('Achievements Menu');
		#end

		// var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
		// menuBG.color = 0xFF9372FF; // Tint used to get menuBGBlue from menuDesat (or, at least, it is close to what the tint is)
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuBGBlue'])));
		menuBG.scale.set(1.1, 1.1);
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = Options.save.data.globalAntialiasing;
		add(menuBG);

		grpAchievements = new FlxTypedGroup();
		add(grpAchievements);

		Achievement.loadAchievements();
		for (i => achievementId in Achievement.achievementList)
		{
			var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(achievementId);
			if (!achievementDef.hidden || Achievement.achievementMap.exists(achievementId))
			{
				achievements.push(achievementDef.name);
				achievementIndex.push(i);
			}
		}

		for (i in 0...achievements.length)
		{
			var achievementId:String = Achievement.achievementList[achievementIndex[i]];
			var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(achievementId);
			var optionText:Alphabet = new Alphabet(0, (100 * i) + 210, Achievement.isAchievementUnlocked(achievementId) ? achievementDef.name : '?', false,
				false);
			optionText.isMenuItem = true;
			optionText.x += 280;
			optionText.xAdd = 200;
			optionText.targetY = i;
			grpAchievements.add(optionText);

			var icon:AttachedAchievement = new AttachedAchievement(optionText.x - 105, optionText.y, achievementId);
			icon.sprTracker = optionText;
			achievementArray.push(icon);
			add(icon);
		}

		descText = new FlxText(150, 600, 980, 32);
		descText.setFormat(Paths.font('vcr.ttf'), descText.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		if (achievementArray.length > 1)
		{
			changeSelection();
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (achievementArray.length > 1)
		{
			if (controls.UI_UP_P)
			{
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(1);
			}

			if (FlxG.mouse.wheel != 0)
			{
				changeSelection(-FlxG.mouse.wheel);
			}
		}

		if (controls.BACK)
		{
			persistentUpdate = false;
			FlxG.sound.play(Paths.getSound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		if (achievements.length > 0)
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, achievements.length - 1);

			for (i => item in grpAchievements.members)
			{
				item.targetY = i - curSelected;

				item.alpha = 0.6;
				// if (item.targetY == 0)
				if (i == curSelected)
				{
					item.alpha = 1;
				}
			}

			for (i => achievement in achievementArray)
			{
				achievement.alpha = 0.6;
				if (i == curSelected)
				{
					achievement.alpha = 1;
				}
			}
			var achievementId:String = Achievement.achievementList[achievementIndex[curSelected]];
			var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(achievementId);
			descText.text = achievementDef.description;

			if (change != 0)
				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		}
	}
}
#end
