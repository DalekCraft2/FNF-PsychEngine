package;

import Song.SongMetaData;
import editors.ChartingState;
import flash.events.MouseEvent;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

using StringTools;

#if FEATURE_DISCORD
import Discord.DiscordClient;
#end

class FreeplayState extends MusicBeatState
{
	private var songs:Array<SongMeta> = [];

	private static var curSelected:Int = 0;

	private var curDifficulty:Int = -1;

	private static var lastDifficultyName:String = '';

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
	private var intendedColor:Int;
	private var colorTween:FlxTween;

	override public function create():Void
	{
		super.create();

		persistentUpdate = true;

		#if FEATURE_DISCORD
		// Updating Discord Rich Presence
		DiscordClient.changePresence('In the Menus', null);
		#end

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.changeBPM(TitleState.titleData.bpm);
		}

		PlayState.isStoryMode = false;
		Week.reloadWeekData();
		for (i in 0...Week.weekList.length)
		{
			if (weekIsLocked(Week.weekList[i]))
				continue;

			var leWeek:Week = Week.weeksLoaded.get(Week.weekList[i]);

			Week.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				addSong(song, i);
			}
		}
		Week.loadTheFirstEnabledMod();

		bg = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var song:SongMeta = songs[i];

			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, song.name, true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			FlxMouseEventManager.add(songText, onMouseDown, onMouseUp, onMouseOver, onMouseOut);
			grpSongs.add(songText);

			/*if (songText.width > 980)
				{
					var textScale:Float = 980 / songText.width;
					songText.scale.x = textScale;
					for (letter in songText.lettersArray)
					{
						letter.x *= textScale;
						letter.offset.x *= textScale;
					}
					songText.updateHitbox();
					// Debug.logTrace('${song.songName} new scale: $textScale');
			}*/

			Paths.currentModDirectory = song.folder;
			var icon:HealthIcon = new HealthIcon(song.icon);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);
		}
		Week.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, 32);
		scoreText.setFormat(Paths.font('vcr.ttf'), scoreText.size, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		if (curSelected >= songs.length)
			curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;

		if (lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.DEFAULT_DIFFICULTY;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.DEFAULT_DIFFICULTIES.indexOf(lastDifficultyName)));

		changeSelection();
		changeDiff();

		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, FlxColor.BLACK);
		textBG.alpha = 0.6;
		add(textBG);

		#if PRELOAD_ALL
		var leText:String = 'Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
		var size:Int = 16;
		#else
		var leText:String = 'Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.';
		var size:Int = 18;
		#end
		var text:FlxText = new FlxText(textBG.x, textBG.y + 4, FlxG.width, leText, size);
		text.setFormat(Paths.font('vcr.ttf'), text.size, RIGHT);
		text.scrollFactor.set();
		add(text);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, FlxMath.bound(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, FlxMath.bound(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating, 2)).split('.');
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

		if (ctrl)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubState());
		}
		else if (space && !selectedSong)
		{
			if (instPlaying != curSelected)
			{
				#if PRELOAD_ALL
				// TODO Resync instrumental and vocals every loop
				var song:SongMeta = songs[curSelected];

				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				Paths.currentModDirectory = song.folder;
				var songId:String = song.id;
				var difficulty:String = CoolUtil.getDifficultyFilePath(curDifficulty);
				var songPath:String = 'songs/$songId/$songId$difficulty';
				if (!Paths.exists(Paths.json(songPath)))
				{
					Debug.logWarn('Couldn\'t find song file "$songPath"');
					difficulty = '';
					curDifficulty = 1;
				}
				Debug.logTrace('$songId/$songId$difficulty');
				PlayState.song = Song.loadFromJson(songId, difficulty);
				if (PlayState.song.needsVoices)
					vocals = new FlxSound().loadEmbedded(Paths.getVoices(PlayState.song.songId));
				else
					vocals = new FlxSound();

				FlxG.sound.list.add(vocals);
				FlxG.sound.playMusic(Paths.getInst(PlayState.song.songId), 0.7);
				vocals.play();
				vocals.persist = true;
				vocals.looped = true;
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

			var song:SongMeta = songs[curSelected];
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
			for (idx in 0...grpSongs.members.length)
			{
				var obj:Alphabet = grpSongs.members[idx];
				var icon:HealthIcon = iconArray[idx];
				if (obj == object || icon == object)
				{
					if (idx != curSelected)
					{
						changeSelection(idx, false);
					}
					else
					{
						selectSong();
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
		songs.push(new SongMeta(songId, week));
	}

	private function weekIsLocked(name:String):Bool
	{
		var leWeek:Week = Week.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	private var instPlaying:Int = -1;

	private static var vocals:FlxSound;

	private var holdTime:Float = 0;

	private var selectedSong:Bool = false;

	private function selectSong():Void
	{
		if (!selectedSong)
		{
			// TODO Implement this (yes, i put this TODO in Debug too, but i don't care)
			// PlayState.setFreeplaySong(songs[curSelected],curDifficulty);
			// LoadingState.loadAndSwitchState(new PlayState());

			selectedSong = true;

			FlxG.sound.play(Paths.getSound('confirmMenu'));

			var song:SongMeta = songs[curSelected];
			var songId:String = song.id;
			var difficulty:String = CoolUtil.getDifficultyFilePath(curDifficulty);
			var songPath:String = 'songs/$songId/$songId$difficulty';
			if (!Paths.exists(Paths.json(songPath)))
			{
				Debug.logWarn('Couldn\'t find song file "$songPath"');
				difficulty = '';
				curDifficulty = 1;
			}
			Debug.logTrace('$songId/$songId$difficulty');
			PlayState.song = Song.loadFromJson(songId, difficulty);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;
			Debug.logTrace('Current Week: ${Week.getWeekDataId()}');
			if (colorTween != null)
			{
				colorTween.cancel();
			}

			var nextState:FlxState;
			if (FlxG.keys.pressed.SHIFT)
			{
				nextState = new ChartingState();
			}
			else
			{
				nextState = new PlayState();
			}

			new FlxTimer().start(1, (tmr:FlxTimer) ->
			{
				LoadingState.loadAndSwitchState(nextState, true);
			});
		}
	}

	// /**
	//  * Load into a song in free play, by name.
	//  * This is a static function, so you can call it anywhere.
	//  * @param songName The name of the song to load. Use the human readable name, with spaces.
	//  * @param isCharting If true, load into the Chart Editor instead.
	//  */

	/*public static function loadSongInFreePlay(songName:String, difficulty:Int, isCharting:Bool, reloadSong:Bool = false)
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
				LoadingState.loadAndSwitchState(new ChartingState(reloadSong));
			else
				LoadingState.loadAndSwitchState(new PlayState());
	}*/
	public static function destroyFreeplayVocals(fadeOut:Bool = false):Void
	{
		// TODO Find a way to ensure that this gets destroyed after fading out so it doesn't persist into PlayState
		// if (fadeOut)
		// {
		// 	vocals.persist = false;
		// 	if (vocals != null)
		// 	{
		// 		vocals.fadeOut(1, 0, (?twn:FlxTween) ->
		// 		{
		// 			vocals.stop();
		// 			vocals.destroy();
		// 			vocals = null;
		// 		});
		// 	}
		// }
		// else
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
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = CoolUtil.difficulties.length - 1;
		if (curDifficulty >= CoolUtil.difficulties.length)
			curDifficulty = 0;

		lastDifficultyName = CoolUtil.difficulties[curDifficulty];

		#if !switch
		var song:SongMeta = songs[curSelected];

		intendedScore = Highscore.getScore(song.id, curDifficulty);
		intendedRating = Highscore.getRating(song.id, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ${CoolUtil.difficultyString()} >';
		positionHighscore();
	}

	private function changeSelection(change:Int = 0, playSound:Bool = true):Void
	{
		curSelected += change;

		if (curSelected < 0)
			curSelected = songs.length - 1;
		if (curSelected >= songs.length)
			curSelected = 0;

		var song:SongMeta = songs[curSelected];

		var newColor:Int = song.color;
		if (newColor != intendedColor)
		{
			if (colorTween != null)
			{
				colorTween.cancel();
			}
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 1, bg.color, intendedColor, {
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

		var bullShit:Int = 0;

		for (icon in iconArray)
		{
			icon.alpha = 0.6;
		}

		iconArray[curSelected].alpha = 1;

		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}

		Paths.currentModDirectory = song.folder;
		PlayState.storyWeek = song.week;

		CoolUtil.difficulties = CoolUtil.DEFAULT_DIFFICULTIES.copy();
		var diffs:Array<String> = Week.getCurrentWeek().difficulties;
		if (diffs != null && diffs.length > 0)
		{
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if (diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1)
						diffs.remove(diffs[i]);
				}
				--i;
			}

			if (diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}

		if (CoolUtil.difficulties.contains(CoolUtil.DEFAULT_DIFFICULTY))
		{
			curDifficulty = Math.round(Math.max(0, CoolUtil.DEFAULT_DIFFICULTIES.indexOf(CoolUtil.DEFAULT_DIFFICULTY)));
		}
		else
		{
			curDifficulty = 0;
		}

		var newPos:Int = CoolUtil.difficulties.indexOf(lastDifficultyName);
		// Debug.logTrace('Position of $lastDifficultyName is $newPos');
		if (newPos > -1)
		{
			curDifficulty = newPos;
		}

		if (playSound)
			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
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

class SongMeta
{
	public var id:String = '';
	public var name:String = '';
	public var week:Int = 0;
	public var icon:String = '';
	public var color:Int = -7179779;
	public var folder:String = '';

	public function new(songId:String, week:Int)
	{
		this.id = songId;
		this.week = week;
		this.folder = Paths.currentModDirectory;
		if (this.folder == null)
			this.folder = '';

		var songMetaData:SongMetaData = Song.getSongMetaData(songId);
		this.name = songMetaData.name;
		this.icon = songMetaData.icon;
		this.color = FlxColor.fromRGB(songMetaData.color[0], songMetaData.color[1], songMetaData.color[2]);
	}
}
