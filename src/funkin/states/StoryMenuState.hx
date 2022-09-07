package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funkin.chart.container.Song;
import funkin.chart.container.SongMetadata.SongMetadataDef;
import funkin.chart.container.SongMetadata;
import funkin.states.substates.GameplayChangersSubState;
import funkin.states.substates.ResetScoreSubState;
import haxe.io.Path;

using StringTools;

#if FEATURE_DISCORD
import funkin.Discord.DiscordClient;
#end

class StoryMenuState extends MusicBeatState implements ListMenu
{
	public static var weekCompleted:Map<String, Bool> = [];

	private static var lastDifficultyName:String = '';

	private var scoreText:FlxText;

	private var curDifficulty:Int = 1;

	private var txtWeekTitle:FlxText;
	private var bgSprite:FlxSprite;

	private static var curSelected:Int = 0;

	private var txtTracklist:FlxText;

	private var grpWeekText:FlxTypedGroup<StoryMenuItem>;
	private var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	private var grpLocks:FlxTypedGroup<FlxSprite>;

	private var difficultySelectors:FlxGroup;
	private var sprDifficulty:FlxSprite;
	private var leftArrow:FlxSprite;
	private var rightArrow:FlxSprite;

	private var weeks:Array<Week> = [];

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus');
		#end

		PlayState.isStoryMode = true;
		Week.reloadWeekData(true);

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.tempo;
		}

		if (curSelected >= Week.weekList.length)
			curSelected = 0;

		scoreText = new FlxText(10, 10, 0, 'SCORE: 49324858', 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), scoreText.size);

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, 32);
		txtWeekTitle.setFormat(Paths.font('vcr.ttf'), txtWeekTitle.size, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var rankText:FlxText = new FlxText(0, 10, 0, 'RANK: GREAT', scoreText.size);
		rankText.setFormat(Paths.font('vcr.ttf'), rankText.size);
		rankText.screenCenter(X);

		var uiTexture:FlxFramesCollection = Paths.getFrames(Path.join(['ui', 'story', 'campaign_menu_UI_assets']));
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = Options.profile.globalAntialiasing;

		grpWeekText = new FlxTypedGroup();
		add(grpWeekText);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		grpWeekCharacters = new FlxTypedGroup();

		grpLocks = new FlxTypedGroup();
		add(grpLocks);

		var num:Int = 0;
		for (i in 0...Week.weekList.length)
		{
			var weekName:String = Week.weekList[i];
			var week:Week = Week.weeksLoaded.get(weekName);
			var isLocked:Bool = weekIsLocked(weekName);
			if (!isLocked || !week.hiddenUntilUnlocked)
			{
				weeks.push(week);
				Week.setDirectoryFromWeek(week);
				var weekThing:StoryMenuItem = new StoryMenuItem(0, bgSprite.y + 396, weekName);
				weekThing.y += ((weekThing.height + 20) * num);
				weekThing.targetY = num;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);
				weekThing.antialiasing = Options.profile.globalAntialiasing;

				// Needs an offset thingie
				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.frames = uiTexture;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = i;
					lock.antialiasing = Options.profile.globalAntialiasing;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		Week.setDirectoryFromWeek(weeks[0]);

		var charArray:Array<String> = null;
		if (weeks.length > 0)
		{
			charArray = weeks[0].weekCharacters;
		}
		else
		{
			charArray = ['', '', ''];
		}

		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		if (weeks.length > 0)
		{
			var menuItem:StoryMenuItem = grpWeekText.members[0];
			leftArrow = new FlxSprite(menuItem.x + menuItem.width + 10, menuItem.y + 10);
		}
		else
		{
			leftArrow = new FlxSprite(0, bgSprite.y + 396 + 10);
			leftArrow.screenCenter(X);
			leftArrow.x += 10;
		}

		leftArrow.frames = uiTexture;
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.addByPrefix('press', 'arrow push left');
		leftArrow.animation.play('idle');
		leftArrow.antialiasing = Options.profile.globalAntialiasing;
		difficultySelectors.add(leftArrow);

		Difficulty.difficulties = Difficulty.DEFAULT_DIFFICULTIES.copy();
		if (lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.DEFAULT_DIFFICULTY;
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.DEFAULT_DIFFICULTIES.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite(0, leftArrow.y);
		sprDifficulty.antialiasing = Options.profile.globalAntialiasing;
		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(leftArrow.x + 376, leftArrow.y);
		rightArrow.frames = uiTexture;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', 'arrow push right', 24, false);
		rightArrow.animation.play('idle');
		rightArrow.antialiasing = Options.profile.globalAntialiasing;
		difficultySelectors.add(rightArrow);

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07,
			bgSprite.y + 425).loadGraphic(Paths.getGraphic(Path.join(['ui', 'story', 'Menu_Tracks'])));
		tracksSprite.antialiasing = Options.profile.globalAntialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = rankText.font;
		txtTracklist.color = 0xFFE55777;
		add(txtTracklist);
		// add(rankText);
		add(scoreText);
		add(txtWeekTitle);

		changeSelection();
		changeDifficulty();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 30, 0, 1)));
		if (Math.abs(intendedScore - lerpScore) < 10)
			lerpScore = intendedScore;

		scoreText.text = 'WEEK SCORE: $lerpScore';

		if (!movedBack && !selectedWeek)
		{
			var upP:Bool = controls.UI_UP_P;
			var downP:Bool = controls.UI_DOWN_P;
			if (upP)
			{
				changeSelection(-1);
			}
			if (downP)
			{
				changeSelection(1);
			}
			if (FlxG.mouse.wheel != 0)
			{
				changeSelection(-FlxG.mouse.wheel);
			}

			if (controls.UI_RIGHT)
				rightArrow.animation.play('press')
			else
				rightArrow.animation.play('idle');

			if (controls.UI_LEFT)
				leftArrow.animation.play('press');
			else
				leftArrow.animation.play('idle');

			if (controls.UI_RIGHT_P)
				changeDifficulty(1);
			else if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			else if (upP || downP)
				changeDifficulty();

			if (FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubState());
			}
			else if (controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curSelected));
			}
			else if (controls.ACCEPT)
			{
				selectWeek();
			}
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			persistentUpdate = false;
			FlxG.sound.play(Paths.getSound('cancelMenu'));
			movedBack = true;
			FlxG.switchState(new MainMenuState());
		}

		for (lock in grpLocks)
		{
			lock.y = grpWeekText.members[lock.ID].y;
			lock.visible = (lock.y > FlxG.height / 2);
		}
	}

	override public function closeSubState():Void
	{
		super.closeSubState();

		persistentUpdate = true;
		changeSelection();
	}

	override public function beatHit(beat:Int):Void
	{
		super.beatHit(beat);

		for (character in grpWeekCharacters)
		{
			if (character.dances || beat % 2 == 0)
			{
				character.bopHead();
			}
		}
	}

	private var movedBack:Bool = false;
	private var selectedWeek:Bool = false;
	private var stopspamming:Bool = false;

	private function selectWeek():Void
	{
		if (weeks.length > 0)
		{
			if (!weekIsLocked(weeks[curSelected].id))
			{
				if (!selectedWeek)
				{
					if (!stopspamming)
					{
						FlxG.sound.play(Paths.getSound('confirmMenu'));

						grpWeekText.members[curSelected].startFlashing();

						var bf:MenuCharacter = grpWeekCharacters.members[1];
						bf.playConfirmAnim();
						stopspamming = true;
					}

					PlayState.storyPlaylist = weeks[curSelected].songs;
					PlayState.isStoryMode = true;
					PlayState.chartingMode = false;
					selectedWeek = true;

					var difficulty:String = Difficulty.getDifficultyFilePath(curDifficulty);
					if (difficulty == null)
						difficulty = '';

					PlayState.storyDifficulty = curDifficulty;

					PlayState.song = Song.loadSong(PlayState.storyPlaylist[0], difficulty);
					PlayState.campaignScore = 0;
					PlayState.campaignSicks = 0;
					PlayState.campaignGoods = 0;
					PlayState.campaignBads = 0;
					PlayState.campaignShits = 0;
					PlayState.campaignMisses = 0;
					new FlxTimer().start(1, (tmr:FlxTimer) ->
					{
						LoadingState.loadAndSwitchState(new PlayState(), true);
					});
				}
			}
			else
			{
				FlxG.sound.play(Paths.getSound('cancelMenu'));
			}
		}
	}

	private var tweenDifficulty:FlxTween;

	private function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.difficulties.length - 1);

		Week.setDirectoryFromWeek(weeks[curSelected]);

		var diff:String = Difficulty.difficulties[curDifficulty];
		var newImage:FlxGraphicAsset = Paths.getGraphic(Path.join(['ui', 'story', 'difficulties', Paths.formatToSongPath(diff)]));

		if (sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			sprDifficulty.x = leftArrow.x + 60;
			sprDifficulty.x += (308 - sprDifficulty.width) / 3;
			sprDifficulty.alpha = 0;
			sprDifficulty.y = leftArrow.y - 15;

			if (tweenDifficulty != null)
				tweenDifficulty.cancel();
			tweenDifficulty = FlxTween.tween(sprDifficulty, {y: leftArrow.y + 15, alpha: 1}, 0.07, {
				onComplete: (twn:FlxTween) ->
				{
					tweenDifficulty = null;
				}
			});
		}
		lastDifficultyName = diff;

		#if !switch
		if (weeks.length > 0)
		{
			intendedScore = HighScore.getWeekScore(weeks[curSelected].id, curDifficulty);
		}
		#end
	}

	private var lerpScore:Int = 0;
	private var intendedScore:Int = 0;

	private function changeSelection(change:Int = 0):Void
	{
		if (weeks.length > 0)
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, weeks.length - 1);

			var week:Week = weeks[curSelected];
			Week.setDirectoryFromWeek(week);

			var storyName:String = week.storyName;
			txtWeekTitle.text = storyName.toUpperCase();
			txtWeekTitle.x = FlxG.width - 10 - txtWeekTitle.width;

			var unlocked:Bool = !weekIsLocked(week.id);
			for (i => item in grpWeekText.members)
			{
				item.targetY = i - curSelected;
				if (item.targetY == 0 && unlocked)
					item.alpha = 1;
				else
					item.alpha = 0.6;
			}

			bgSprite.visible = true;
			var assetName:String = week.weekBackground;
			if (assetName == null || assetName.length < 1)
			{
				bgSprite.visible = false;
			}
			else
			{
				var bgPath:String = Path.join(['ui', 'story', 'backgrounds', assetName]);
				if (!Paths.exists(Paths.image(bgPath), IMAGE))
				{
					Debug.logError('Could not find story menu background with ID "$assetName"; using default');
					bgPath = Path.join(['ui', 'story', 'backgrounds', 'blank']); // Prevents crash from missing background
				}
				var graphic:FlxGraphicAsset = Paths.getGraphic(bgPath);
				bgSprite.loadGraphic(graphic);
			}
			PlayState.storyWeek = curSelected;

			Difficulty.difficulties = Difficulty.DEFAULT_DIFFICULTIES.copy();
			var diffs:Array<String> = Week.getCurrentWeek().difficulties;
			difficultySelectors.visible = unlocked;

			if (diffs != null && diffs.length > 0)
			{
				var i:Int = diffs.length - 1;
				while (i >= 0)
				{
					if (diffs[i] != null)
					{
						diffs[i] = diffs[i].trim();
						if (diffs[i].length < 1)
							diffs.remove(diffs[i]);
					}
					i--;
				}

				if (diffs.length > 0 && diffs[0].length > 0)
				{
					Difficulty.difficulties = diffs;
				}
			}

			if (Difficulty.difficulties.contains(Difficulty.DEFAULT_DIFFICULTY))
			{
				curDifficulty = Math.round(Math.max(0, Difficulty.DEFAULT_DIFFICULTIES.indexOf(Difficulty.DEFAULT_DIFFICULTY)));
			}
			else
			{
				curDifficulty = 0;
			}

			var newPos:Int = Difficulty.difficulties.indexOf(lastDifficultyName);
			if (newPos > -1)
			{
				curDifficulty = newPos;
			}
			updateText();

			if (change != 0)
				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		}
	}

	private function weekIsLocked(name:String):Bool
	{
		var week:Week = Week.weeksLoaded.get(name);
		return (!week.startUnlocked
			&& week.weekBefore.length > 0
			&& (!weekCompleted.exists(week.weekBefore) || !weekCompleted.get(week.weekBefore)));
	}

	private function updateText():Void
	{
		var weekArray:Array<String> = weeks[curSelected].weekCharacters;
		for (i => char in grpWeekCharacters.members)
		{
			char.changeCharacter(weekArray[i]);
		}

		var week:Week = weeks[curSelected];
		var stringThing:Array<String> = [];
		for (songId in week.songs)
		{
			var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadataDef(songId);
			stringThing.push(songMetadataDef.name);
		}

		txtTracklist.text = '';
		for (string in stringThing)
		{
			txtTracklist.text += '$string\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		#if !switch
		intendedScore = HighScore.getWeekScore(weeks[curSelected].id, curDifficulty);
		#end
	}
}
