package;

#if FEATURE_ACHIEVEMENTS
import Achievement.AchievementData;
import Achievement.AttachedAchievement;
#if FEATURE_DISCORD
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

using StringTools;

class AchievementsMenuState extends MusicBeatState
{
	private var options:Array<String> = [];
	private var grpOptions:FlxTypedGroup<Alphabet>;

	private static var curSelected:Int = 0;

	private var achievementArray:Array<AttachedAchievement> = [];
	private var achievementIndex:Array<Int> = [];
	private var descText:FlxText;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		DiscordClient.changePresence('Achievements Menu', null);
		#end

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuBGBlue'));
		// menuBG.color = 0xFF9271FD; // TODO Find the colors used to tint the menuDesat image to get menuBG and menuBGBlue
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = Options.save.data.globalAntialiasing;
		add(menuBG);

		grpOptions = new FlxTypedGroup();
		add(grpOptions);

		Achievement.loadAchievements();
		for (i in 0...Achievement.achievementList.length)
		{
			var achievementId:String = Achievement.achievementList[i];
			var achievementData:AchievementData = Achievement.achievementsLoaded.get(achievementId);
			if (!achievementData.hidden || Achievement.achievementMap.exists(achievementId))
			{
				options.push(achievementData.name);
				achievementIndex.push(i);
			}
		}

		for (i in 0...options.length)
		{
			var achievementId:String = Achievement.achievementList[achievementIndex[i]];
			var achievementData:AchievementData = Achievement.achievementsLoaded.get(achievementId);
			var optionText:Alphabet = new Alphabet(0, (100 * i) + 210, Achievement.isAchievementUnlocked(achievementId) ? achievementData.name : '?', false,
				false);
			optionText.isMenuItem = true;
			optionText.x += 280;
			optionText.xAdd = 200;
			optionText.targetY = i;
			grpOptions.add(optionText);

			var icon:AttachedAchievement = new AttachedAchievement(optionText.x - 105, optionText.y, achievementId);
			icon.sprTracker = optionText;
			achievementArray.push(icon);
			add(icon);
		}

		descText = new FlxText(150, 600, 980, 32);
		descText.setFormat(Paths.font('vcr.ttf'), descText.size, CENTER, OUTLINE, FlxColor.BLACK);
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
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		// TODO Try to change the variables what are named like this so I know what the fuck I'm looking at
		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

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
		var achievementData:AchievementData = Achievement.achievementsLoaded.get(achievementId);
		descText.text = achievementData.description;
		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
	}
}
#end
