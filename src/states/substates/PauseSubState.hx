package states.substates;

import chart.container.Song;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import ui.Alphabet;

class PauseSubState extends MusicBeatSubState implements ListMenu
{
	public static var songName:String = '';

	private static var pauseMusic:FlxSound;

	private var grpMenuShit:FlxTypedGroup<Alphabet>;
	private var menuItems:Array<String> = [];
	private var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Options', 'Change Difficulty', 'Exit to Menu'];
	private var difficultyChoices:Array<String> = [];
	private var curSelected:Int = 0;

	private var practiceText:FlxText;
	private var skipTimeText:FlxText;
	private var skipTimeTracker:Alphabet;
	private var curTime:Float = Math.max(0, Conductor.songPosition);

	private var goToOptions:Bool = false;

	override public function create():Void
	{
		super.create();

		persistentDraw = false; // This is so the pause screen is hidden when an OptionsSubState is opened

		if (Difficulty.difficulties.length <= 1)
			menuItemsOG.remove('Change Difficulty'); // No need to change difficulty if there is only one!

		if (PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');

			var num:Int = 0;
			if (!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle BotPlay');
		}
		menuItems = menuItemsOG;

		if (PlayState.isStoryMode)
		{
			menuItemsOG.insert(2, 'Restart with Cutscene');
		}

		for (diff in Difficulty.difficulties)
		{
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		if (pauseMusic == null || !pauseMusic.playing)
		{
			pauseMusic = new FlxSound();
			if (songName != null)
			{
				pauseMusic.loadEmbedded(Paths.getMusic(songName), true, true);
			}
			else if (Options.save.data.pauseMusic != 'None')
			{
				pauseMusic.loadEmbedded(Paths.getMusic(Paths.formatToSongPath(Options.save.data.pauseMusic)), true, true);
			}
			pauseMusic.volume = 0;
			pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
			pauseMusic.fadeIn(20);

			FlxG.sound.list.add(pauseMusic);
		}

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.song.name, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font('vcr.ttf'), levelInfo.size, FlxColor.WHITE, RIGHT);
		levelInfo.updateHitbox();
		levelInfo.alpha = 0;
		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, Difficulty.difficultyString(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), levelDifficulty.size, FlxColor.WHITE, RIGHT);
		levelDifficulty.updateHitbox();
		levelDifficulty.alpha = 0;
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 15 + 64, 0, 'Blueballed: ${PlayState.deathCounter}', 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), blueballedTxt.size, FlxColor.WHITE, RIGHT);
		blueballedTxt.updateHitbox();
		blueballedTxt.alpha = 0;
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, 'PRACTICE MODE', 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), practiceText.size, FlxColor.WHITE, RIGHT);
		practiceText.updateHitbox();
		practiceText.visible = PlayStateChangeables.practiceMode;
		practiceText.x = FlxG.width - (practiceText.width + 20);
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, 'CHARTING MODE', 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), chartingText.size, FlxColor.WHITE, RIGHT);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup();
		add(grpMenuShit);

		regenMenu();
	}

	private var holdTime:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// This has to be done on the update after the Accept key is pressed, otherwise the options menu automatically selects the first category
		if (goToOptions)
		{
			openSubState(new OptionsSubState(true));
			goToOptions = false;
		}

		updateSkipTextStuff();

		var upP:Bool = controls.UI_UP_P;
		var downP:Bool = controls.UI_DOWN_P;
		var accepted:Bool = controls.ACCEPT;

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

		var selectedOption:String = menuItems[curSelected];
		switch (selectedOption)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if (holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if (curTime >= FlxG.sound.music.length)
						curTime -= FlxG.sound.music.length;
					else if (curTime < 0)
						curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (accepted)
		{
			if (menuItems == difficultyChoices)
			{
				if (menuItems.length - 1 != curSelected && difficultyChoices.contains(selectedOption))
				{
					var name:String = PlayState.song.id;
					var difficulty:String = Difficulty.getDifficultyFilePath(curSelected);
					PlayState.song = Song.loadSong(name, difficulty);
					PlayState.storyDifficulty = curSelected;
					FlxG.resetState();
					FlxG.sound.music.stop();
					PlayState.changedDifficulty = true;
					PlayState.chartingMode = false;
					return;
				}

				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (selectedOption)
			{
				case 'Resume':
					close();
				case 'Restart Song':
					PlayState.instance.restartSong();
				case 'Restart with Cutscene':
					PlayState.instance.restartSong();
					PlayState.seenCutscene = false;
				case 'Options':
					goToOptions = true;
				// openSubState(new OptionsSubState(true));
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					regenMenu();
				case 'Leave Charting Mode':
					PlayState.instance.restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if (curTime < Conductor.songPosition)
					{
						PlayState.startTime = curTime;
						PlayState.instance.restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case 'End Song':
					close();
					PlayState.instance.finishSong(true);
				case 'Toggle Practice Mode':
					PlayStateChangeables.practiceMode = !PlayStateChangeables.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayStateChangeables.practiceMode;
				case 'Toggle BotPlay':
					PlayStateChangeables.botPlay = !PlayStateChangeables.botPlay;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayStateChangeables.botPlay;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Exit to Menu':
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					if (PlayState.loadRep)
					{
						Options.save.data.botPlay = false;
						Options.save.data.scrollSpeed = 1;
						Options.save.data.downScroll = false;
					}
					PlayState.loadRep = false;
					PlayState.stageTesting = false;

					if (PlayState.isStoryMode)
					{
						FlxG.switchState(new StoryMenuState());
					}
					else
					{
						FlxG.switchState(new FreeplayState());
					}
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
			}
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		if (!goToOptions)
		{
			if (pauseMusic.fadeTween != null)
			{
				pauseMusic.fadeTween.cancel();
				pauseMusic.fadeTween.destroy();
			}
			pauseMusic.destroy();
			pauseMusic = null;
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);

		for (i => item in grpMenuShit.members)
		{
			item.targetY = i - curSelected;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;

				if (item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}

		if (change != 0)
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
	}

	private function regenMenu():Void
	{
		grpMenuShit.forEach((obj:Alphabet) ->
		{
			grpMenuShit.remove(obj);
			obj.destroy();
		});
		grpMenuShit.clear();

		for (i => menuItem in menuItems)
		{
			var item:Alphabet = new Alphabet(0, 70 * i + 30, menuItem, true, false);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if (menuItem == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, 64);
				skipTimeText.setFormat(Paths.font('vcr.ttf'), skipTimeText.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
	}

	private function updateSkipTextStuff():Void
	{
		if (skipTimeText == null)
			return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	private function updateSkipTimeText():Void
	{
		skipTimeText.text = '${FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / TimingConstants.MILLISECONDS_PER_SECOND)), false)} / ${FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / TimingConstants.MILLISECONDS_PER_SECOND)), false)}';
	}
}
