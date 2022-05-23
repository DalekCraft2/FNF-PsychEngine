package;

#if FEATURE_ACHIEVEMENTS
import Achievement.AchievementDef;
import Achievement.AttachedAchievement;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class AchievementsMenuState extends MusicBeatState
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

		// var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		// menuBG.color = 0xFF9372FF; // Tint used to get menuBGBlue from menuDesat (or, at least, it is close to what the tint is)
		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuBGBlue'));
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = Options.save.data.globalAntialiasing;
		add(menuBG);

		grpAchievements = new FlxTypedGroup();
		add(grpAchievements);

		Achievement.loadAchievements();
		for (i in 0...Achievement.achievementList.length)
		{
			var achievementId:String = Achievement.achievementList[i];
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
			curSelected += change;
			if (curSelected < 0)
				curSelected = achievements.length - 1;
			if (curSelected >= achievements.length)
				curSelected = 0;

			for (i in 0...grpAchievements.members.length)
			{
				var item:Alphabet = grpAchievements.members[i];
				item.targetY = i - curSelected;

				item.alpha = 0.6;
				if (item.targetY == 0)
				{
					item.alpha = 1;
				}
			}

			for (i in 0...achievementArray.length)
			{
				var achievement:AttachedAchievement = achievementArray[i];
				achievement.alpha = 0.6;
				if (i == curSelected)
				{
					achievement.alpha = 1;
				}
			}
			var achievementId:String = Achievement.achievementList[achievementIndex[curSelected]];
			var achievementDef:AchievementDef = Achievement.achievementsLoaded.get(achievementId);
			descText.text = achievementDef.description;
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		}
	}
}
#end
