package;

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
	public static var goToOptions:Bool = false;
	public static var goBack:Bool = false;

	private var grpMenuShit:FlxTypedGroup<Alphabet>;

	private var menuItems:Array<String> = [];
	private var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Options', 'Change Difficulty', 'Exit to Menu'];
	private var difficultyChoices:Array<String> = [];
	private var curSelected:Int = 0;

	public static var playingPause:Bool = false;

	private var pauseMusic:FlxSound;
	private var practiceText:FlxText;
	private var skipTimeText:FlxText;
	private var skipTimeTracker:Alphabet;
	private var curTime:Float = Math.max(0, Conductor.songPosition);

	public static var songName:String = '';

	override public function create():Void
	{
		super.create();

		if (CoolUtil.difficulties.length <= 1)
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

		for (diff in CoolUtil.difficulties)
		{
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		if (!playingPause)
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
			pauseMusic.ID = 9000;

			FlxG.sound.list.add(pauseMusic);
		}
		else
		{
			for (i in FlxG.sound.list)
			{
				if (i.ID == 9000) // jankiest static variable
					pauseMusic = i;
			}
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

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, CoolUtil.difficultyString(), 32);
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

		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

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

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
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
				if (menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
				{
					var name:String = PlayState.song.songId;
					var difficulty:String = CoolUtil.getDifficultyFilePath(curSelected);
					PlayState.song = Song.loadFromJson(name, difficulty);
					PlayState.storyDifficulty = curSelected;
					FlxG.resetState();
					FlxG.sound.music.volume = 0;
					PlayState.changedDifficulty = true;
					PlayState.chartingMode = false;
					return;
				}

				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case 'Resume':
					close();
				case 'Restart Song':
					restartSong();
				case 'Options':
					// FIXME Pause music never stops if one enters the options menu and then leaves both it and the pause menu
					goToOptions = true;
					close();
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
			pauseMusic.destroy();
			playingPause = false;
		}
	}

	public static function restartSong(noTrans:Bool = false):Void
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

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

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

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

		/*for (obj in grpMenuShit.members)
			{
				obj.kill();
				grpMenuShit.remove(obj, true);
				obj.destroy();
		}*/

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
