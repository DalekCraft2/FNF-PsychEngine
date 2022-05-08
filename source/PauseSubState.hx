package;

import options.OptionsSubState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;

class PauseSubState extends MusicBeatSubState
{
	public static var songName:String = '';

	private static var pauseMusic:FlxSound;
	private static var volumeTween:FlxTween;

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

			FlxG.sound.list.add(pauseMusic);

			volumeTween = FlxTween.tween(pauseMusic, {volume: 0.5}, 20);
		}

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.song.songName, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font('vcr.ttf'), levelInfo.size, RIGHT);
		levelInfo.updateHitbox();
		levelInfo.alpha = 0;
		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, Difficulty.difficultyString(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), levelDifficulty.size, RIGHT);
		levelDifficulty.updateHitbox();
		levelDifficulty.alpha = 0;
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 15 + 64, 0, 'Blueballed: ${PlayState.deathCounter}', 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), blueballedTxt.size, RIGHT);
		blueballedTxt.updateHitbox();
		blueballedTxt.alpha = 0;
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, 'PRACTICE MODE', 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), practiceText.size, RIGHT);
		practiceText.updateHitbox();
		practiceText.visible = PlayStateChangeables.practiceMode;
		practiceText.x = FlxG.width - (practiceText.width + 20);
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, 'CHARTING MODE', 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), chartingText.size, RIGHT);
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
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
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
					var name:String = PlayState.song.songId;
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
					restartSong();
				case 'Restart with Cutscene':
					restartSong();
					PlayState.seenCutscene = false;
				case 'Options':
					goToOptions = true;
				// openSubState(new OptionsSubState(true));
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					regenMenu();
				case 'Leave Charting Mode':
					restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if (curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
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
			Debug.logTrace('Destroying music for pause menu');
			if (volumeTween != null)
			{
				volumeTween.cancel();
				volumeTween.destroy();
				volumeTween = null;
			}
			pauseMusic.destroy();
			pauseMusic = null;
		}
	}

	public static function restartSong(noTrans:Bool = false):Void
	{
		PlayState.instance.paused = true; // For scripts
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.stop();
		}
		if (PlayState.instance.vocals != null && PlayState.instance.vocals.playing)
		{
			PlayState.instance.vocals.stop();
		}

		if (noTrans)
		{
			FlxTransitionableState.skipNextTransOut = true;
		}
		FlxG.resetState();
		PlayState.stageTesting = false;
	}

	private function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		for (i in 0...grpMenuShit.members.length)
		{
			var item:Alphabet = grpMenuShit.members[i];
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
	}

	private function regenMenu():Void
	{
		for (i in 0...grpMenuShit.members.length)
		{
			var obj:Alphabet = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (i in 0...menuItems.length)
		{
			var item:Alphabet = new Alphabet(0, 70 * i + 30, menuItems[i], true, false);
			item.isMenuItem = true;
			item.targetY = i;
			grpMenuShit.add(item);

			if (menuItems[i] == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, 64);
				skipTimeText.setFormat(Paths.font('vcr.ttf'), skipTimeText.size, CENTER, OUTLINE, FlxColor.BLACK);
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
		skipTimeText.text = '${FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)} / ${FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false)}';
	}
}
