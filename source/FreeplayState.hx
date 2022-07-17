package;

import chart.container.Song;
import editors.ChartEditorState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.io.Path;
import openfl.events.MouseEvent;
import ui.Alphabet;
import ui.HealthIcon;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class FreeplayState extends MusicBeatState
{
	public static final DEFAULT_COLOR:FlxColor = 0xFF665AFF;
	private static var curSelected:Int = 0;
	private static var lastDifficultyName:String = '';

	private var songs:Array<SongMetadata> = [];

	private var curDifficulty:Int = -1;

	private var scoreBG:FlxSprite;
	private var scoreText:FlxText;
	private var diffText:FlxText;
	private var lerpScore:Int = 0;
	private var lerpRating:Float = 0;
	private var intendedScore:Int = 0;
	private var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;

	private var iconArray:Array<HealthIcon> = [];

	private var bg:FlxSprite;
	private var intendedColor:FlxColor;
	private var colorTween:FlxTween;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus');
		#end

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.bpm;
		}

		PlayState.isStoryMode = false;
		Week.reloadWeekData();
		for (i => weekId in Week.weekList)
		{
			if (weekIsLocked(weekId))
				continue;

			var week:Week = Week.weeksLoaded.get(weekId);

			Week.setDirectoryFromWeek(week);
			for (song in week.songs)
			{
				addSong(song, i);
			}
		}
		Week.loadTheFirstEnabledMod();

		bg = new FlxSprite().loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup();
		add(grpSongs);

		for (i => song in songs)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, song.name, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			FlxMouseEventManager.add(songText, onMouseDown, onMouseUp, onMouseOver, onMouseOut);
			grpSongs.add(songText);

			/*
				if (songText.width > 980)
					{
						var textScale:Float = 980 / songText.width;
						songText.scale.x = textScale;
						for (letter in songText.lettersArray)
						{
							letter.x *= textScale;
							letter.offset.x *= textScale;
						}
						songText.updateHitbox();
				}
			 */

			Paths.currentModDirectory = song.folder;
			var icon:HealthIcon = new HealthIcon(song.icon);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			// TODO screw this, let's use an FlxGroup
			// Actually, maybe it'd be smarter to make a separate class
			iconArray.push(icon);
			add(icon);
		}
		Week.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), scoreText.size, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		if (curSelected >= songs.length)
			curSelected = 0;

		// if (songs.length > 0)
		// {
		// 	var curSong:SongMetadata = songs[curSelected];
		// 	var colorIndex:Int = FlxG.random.int(0, curSong.colors.length - 1);
		// 	bg.color = curSong.colors[colorIndex];
		// }
		// else
		// {
		// 	bg.color = DEFAULT_COLOR;
		// }
		if (songs.length <= 0)
		{
			bg.color = DEFAULT_COLOR;
		}

		intendedColor = bg.color;

		if (lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.DEFAULT_DIFFICULTY;
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.DEFAULT_DIFFICULTIES.indexOf(lastDifficultyName)));

		changeSelection();
		changeDiff();

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, FlxColor.BLACK);
		textBG.alpha = 0.6;
		add(textBG);

		#if PRELOAD_ALL
		var textString:String = 'Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
		var size:Int = 16;
		#else
		var textString:String = 'Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
		var size:Int = 18;
		#end
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, textString, size);
		text.setFormat(Paths.font('vcr.ttf'), text.size, FlxColor.WHITE, RIGHT);
		text.scrollFactor.set();
		add(text);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, FlxMath.bound(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(FlxMath.roundDecimal(lerpRating, 2)).split('.');
		if (ratingSplit.length < 2)
		{ // No decimals, add an empty space
			ratingSplit.push('');
		}

		while (ratingSplit[1].length < 2)
		{ // Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		scoreText.text = 'PERSONAL BEST: $lerpScore (${ratingSplit.join('.')}%)';
		positionHighscore();

		var upP:Bool = controls.UI_UP_P;
		var downP:Bool = controls.UI_DOWN_P;
		var accepted:Bool = controls.ACCEPT;
		var space:Bool = FlxG.keys.justPressed.SPACE;
		var ctrl:Bool = FlxG.keys.justPressed.CONTROL;

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftMult = 3;

		if (songs.length > 1 && !selectedSong)
		{
			if (upP)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			if (downP)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}

			if (controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					changeDiff();
				}
			}
		}

		if (!selectedSong)
		{
			if (controls.UI_LEFT_P)
				changeDiff(-1);
			else if (controls.UI_RIGHT_P)
				changeDiff(1);
			else if (upP || downP)
				changeDiff();
		}

		if (controls.BACK && !selectedSong)
		{
			persistentUpdate = false;
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			FlxG.sound.play(Paths.getSound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		}

		if (ctrl && !selectedSong)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubState());
		}
		else if (space && !selectedSong)
		{
			if (instPlaying != curSelected)
			{
				#if PRELOAD_ALL
				var song:SongMetadata = songs[curSelected];

				destroyFreeplayVocals();
				FlxG.sound.music.stop();
				Paths.currentModDirectory = song.folder;
				var songId:String = song.id;
				var difficulty:String = Difficulty.getDifficultyFilePath(curDifficulty);
				var songPath:String = Path.join(['songs', songId, '$songId$difficulty']);
				if (!Paths.exists(Paths.json(songPath)))
				{
					Debug.logWarn('Couldn\'t find song file "$songPath"');
					difficulty = '';
					curDifficulty = 1;
				}
				if (PlayState.song.needsVoices)
					vocals = new FlxSound().loadEmbedded(Paths.getVoices(songId));
				else
					vocals = new FlxSound();

				FlxG.sound.list.add(vocals);
				FlxG.sound.playMusic(Paths.getInst(songId), 0.7);
				FlxG.sound.music.onComplete = () ->
				{
					vocals.stop();
					vocals.play();
				};
				vocals.play();
				vocals.persist = true;
				vocals.volume = 0.7;
				instPlaying = curSelected;
				#end
			}
		}
		else if (accepted)
		{
			selectSong();
		}
		else if (controls.RESET && !selectedSong)
		{
			persistentUpdate = false;

			var song:SongMetadata = songs[curSelected];
			openSubState(new ResetScoreSubState(song.id, curDifficulty, song.icon));
			FlxG.sound.play(Paths.getSound('scrollMenu'));
		}
	}

	override public function closeSubState():Void
	{
		super.closeSubState();

		changeSelection(0, false);
		persistentUpdate = true;
	}

	private function onMouseDown(object:FlxObject):Void
	{
		if (!selectedSong)
		{
			for (i => obj in grpSongs.members)
			{
				var icon:HealthIcon = iconArray[i];
				if (obj == object || icon == object)
				{
					if (i == curSelected)
					{
						selectSong();
					}
					else
					{
						changeSelection(i, false);
					}
				}
			}
		}
	}

	private function onMouseUp(object:FlxObject):Void
	{
	}

	private function onMouseOver(object:FlxObject):Void
	{
	}

	private function onMouseOut(object:FlxObject):Void
	{
	}

	private function scroll(event:MouseEvent):Void
	{
		if (!selectedSong)
		{
			changeSelection(-event.delta);
		}
	}

	public function addSong(songId:String, week:Int):Void
	{
		songs.push(new SongMetadata(songId, week));
	}

	private function weekIsLocked(name:String):Bool
	{
		var week:Week = Week.weeksLoaded.get(name);
		return (!week.startUnlocked
			&& week.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(week.weekBefore) || !StoryMenuState.weekCompleted.get(week.weekBefore)));
	}

	private var instPlaying:Int = -1;

	private static var vocals:FlxSound;

	private var holdTime:Float = 0;

	private var selectedSong:Bool = false;

	private function selectSong():Void
	{
		if (songs.length > 0)
		{
			if (!selectedSong)
			{
				// TODO Implement this (yes, i put this TODO in Debug too, but i don't care)
				// PlayState.setFreeplaySong(songs[curSelected],curDifficulty);
				// LoadingState.loadAndSwitchState(new PlayState());

				selectedSong = true;

				FlxG.sound.play(Paths.getSound('confirmMenu'));

				var song:SongMetadata = songs[curSelected];
				var songId:String = song.id;
				var difficulty:String = Difficulty.getDifficultyFilePath(curDifficulty);
				var songPath:String = Path.join(['songs', songId, '$songId$difficulty']);
				if (!Paths.exists(Paths.json(songPath)))
				{
					Debug.logWarn('Couldn\'t find song file "$songPath"');
					difficulty = '';
					curDifficulty = 1;
				}
				PlayState.song = Song.loadSong(songId, difficulty);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;
				if (colorTween != null)
				{
					colorTween.cancel();
				}

				var nextState:FlxState;
				if (FlxG.keys.pressed.SHIFT)
				{
					nextState = new ChartEditorState();
					PlayState.chartingMode = true;
				}
				else
				{
					nextState = new PlayState();
					PlayState.chartingMode = false;
				}

				final arbitraryDelayValue:Float = 1;
				// final transitionDuration:Float = FlxTransitionableState.skipNextTransOut ? 0 : transOut.duration;
				// final delayPlusTransition:Float = arbitraryDelayValue + transitionDuration;

				FlxFlicker.flicker(grpSongs.members[curSelected], 1, 0.06);
				new FlxTimer().start(arbitraryDelayValue, (tmr:FlxTimer) ->
				{
					LoadingState.loadAndSwitchState(nextState, true);
				});
			}
		}
	}

	// /**
	//  * Load into a song in free play, by name.
	//  * This is a static function, so you can call it anywhere.
	//  * @param songName The name of the song to load. Use the human readable name, with spaces.
	//  * @param isCharting If true, load into the Chart Editor instead.
	//  */

	/*
		public static function loadSongInFreePlay(songName:String, difficulty:Int, isCharting:Bool, reloadSong:Bool = false)
		{
			// Make sure song data is initialized first.
			if (songData == null || Lambda.count(songData) == 0)
				populateSongData();

			var currentSongData;
			try
			{
				if (songData.get(songName) == null)
					return;
				currentSongData = songData.get(songName)[difficulty];
				if (songData.get(songName)[difficulty] == null)
					return;
			}
			catch (ex)
			{
				return;
			}

			PlayState.song = currentSongData;
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = difficulty;
			PlayState.storyWeek = songs[curSelected].week;
			Debug.logInfo('Loading song ${PlayState.song.songName} from week ${PlayState.storyWeek} into Free Play...');
			#if FEATURE_STEPMANIA
			if (songs[curSelected].songCharacter == "sm")
			{
				Debug.logInfo('Song is a StepMania song!');
				PlayState.isSM = true;
				PlayState.sm = songs[curSelected].sm;
				PlayState.pathToSm = songs[curSelected].path;
			}
			else
				PlayState.isSM = false;
			#else
			PlayState.isSM = false;
			#end

			PlayState.songMultiplier = rate;

			if (isCharting)
				LoadingState.loadAndSwitchState(new ChartEditorState(reloadSong));
			else
				LoadingState.loadAndSwitchState(new PlayState());
		}
	 */
	public static function destroyFreeplayVocals(fadeOut:Bool = false):Void
	{
		if (fadeOut)
		{
			if (vocals != null)
			{
				vocals.persist = false;
				if (FlxTransitionableState.skipNextTransOut)
				{
					vocals.stop();
					vocals.destroy();
					vocals = null;
				}
				else
				{
					// TODO Make this work with any transition, even though I only use one right now
					vocals.fadeOut(FlxTransitionableState.defaultTransOut.duration, 0, (?twn:FlxTween) ->
					{
						vocals.stop();
						vocals.destroy();
						vocals = null;
					});
				}
			}
		}
		else
		{
			if (vocals != null)
			{
				vocals.stop();
				vocals.destroy();
				vocals = null;
			}
		}
	}

	private function changeDiff(change:Int = 0):Void
	{
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.difficulties.length - 1);

		lastDifficultyName = Difficulty.difficulties[curDifficulty];

		#if !switch
		if (songs.length > 0)
		{
			var song:SongMetadata = songs[curSelected];

			intendedScore = Highscore.getScore(song.id, curDifficulty);
			intendedRating = Highscore.getRating(song.id, curDifficulty);
		}
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ${Difficulty.difficultyString()} >';
		positionHighscore();
	}

	private function changeSelection(change:Int = 0, playSound:Bool = true):Void
	{
		if (songs.length > 0)
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);

			var song:SongMetadata = songs[curSelected];

			var colorIndex:Int = FlxG.random.int(0, song.colors.length - 1);
			var newColor:FlxColor = song.colors[colorIndex];

			if (newColor != intendedColor)
			{
				if (colorTween != null)
				{
					colorTween.cancel();
				}
				intendedColor = newColor;
				colorTween = FlxTween.color(bg, 0.7, bg.color, intendedColor, {
					onComplete: (twn:FlxTween) ->
					{
						colorTween = null;
					}
				});
			}

			#if !switch
			intendedScore = Highscore.getScore(song.id, curDifficulty);
			intendedRating = Highscore.getRating(song.id, curDifficulty);
			#end

			for (icon in iconArray)
			{
				icon.alpha = 0.6;
			}

			iconArray[curSelected].alpha = 1;

			for (i => item in grpSongs.members)
			{
				item.targetY = i - curSelected;

				item.alpha = 0.6;

				if (item.targetY == 0)
				{
					item.alpha = 1;
				}
			}

			Paths.currentModDirectory = song.folder;
			PlayState.storyWeek = song.week;

			Difficulty.difficulties = Difficulty.DEFAULT_DIFFICULTIES.copy();
			var diffs:Array<String> = Week.getCurrentWeek().difficulties;
			// var diffs:Array<DifficultyDef> = song.difficulties;
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

			if (playSound)
				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
		}
	}

	private function positionHighscore():Void
	{
		scoreText.x = FlxG.width - scoreText.width - 6;

		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);

		diffText.x = scoreBG.x + (scoreBG.width / 2);
		diffText.x -= diffText.width / 2;
	}
}
