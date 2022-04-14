package;

import FreeplayState.SongMeta;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Exception;
import lime.app.Application;
import options.OptionsState;

using StringTools;

#if FEATURE_STEPMANIA
import sm.SMFile;
#end
#if sys
import sys.FileSystem;
#end

// TODO Maybe just use a slightly edited copy of FreeplayState for this, or even integrate it into FreeplayState
class LoadReplayState extends MusicBeatState
{
	private var curSelected:Int = 0;

	private var songs:Array<SongMeta> = [];

	private var controlsStrings:Array<String> = [];
	private var actualNames:Array<String> = [];

	private var grpControls:FlxTypedGroup<Alphabet>;
	private var versionShit:FlxText;
	private var poggerDetails:FlxText;

	override public function create():Void
	{
		super.create();

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		// TODO: Refactor this to use OpenFlAssets.
		#if sys
		controlsStrings = FileSystem.readDirectory('assets/replays/');
		#end
		Debug.logTrace(controlsStrings);

		controlsStrings.sort(sortByDate);

		addWeek(['bopeebo', 'fresh', 'dadbattle'], 1);
		addWeek(['spookeez', 'south', 'monster'], 2);
		addWeek(['pico', 'philly', 'blammed'], 3);

		addWeek(['satin-panties', 'high', 'milf'], 4);
		addWeek(['cocoa', 'eggnog', 'winter-horrorland'], 5);

		addWeek(['senpai', 'roses', 'thorns'], 6);

		for (i in 0...controlsStrings.length)
		{
			var string:String = controlsStrings[i];
			actualNames[i] = string;
			var rep:Replay = Replay.loadReplay(string);
			controlsStrings[i] = '${string.split('time')[0]} ${CoolUtil.difficultyString(rep.replay.songDiff).toUpperCase()}';
		}

		if (controlsStrings.length == 0)
			controlsStrings.push('No Replays...');

		menuBG.color = 0xFFEA71FD;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = Options.save.data.globalAntialiasing;
		add(menuBG);

		grpControls = new FlxTypedGroup();
		add(grpControls);

		for (i in 0...controlsStrings.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, controlsStrings[i], true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;
			grpControls.add(controlLabel);
			// TODO Figure out why this comment exists and solve any issues with putting the X value into the Alphabet constructor
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		versionShit = new FlxText(5, FlxG.height - 34, 0,
			'Replay Loader (ESCAPE TO GO BACK)\nNOTICE!!!! Replays are in a beta stage, and they are probably not 100% correct. expect misses and other stuff that isn\'t there!\n',
			16);
		versionShit.scrollFactor.set();
		versionShit.setFormat(Paths.font('vcr.ttf'), versionShit.size, LEFT, OUTLINE, FlxColor.BLACK);
		add(versionShit);

		poggerDetails = new FlxText(5, 34, 0, 'Replay Details - \nnone', 16);
		poggerDetails.scrollFactor.set();
		poggerDetails.setFormat(Paths.font('vcr.ttf'), poggerDetails.size, LEFT, OUTLINE, FlxColor.BLACK);
		add(poggerDetails);

		changeSelection(0);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (controls.BACK)
			FlxG.switchState(new OptionsState());
		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.ACCEPT && grpControls.members[curSelected].text != 'No Replays...')
		{
			Debug.logTrace('Loading ${actualNames[curSelected]}');
			PlayState.rep = Replay.loadReplay(actualNames[curSelected]);

			PlayState.loadRep = true;

			if (PlayState.rep.replay.replayGameVer == Replay.REPLAY_VERSION)
			{
				// adjusting the song name to be compatible
				var songFormat:String = Paths.formatToSongPath(PlayState.rep.replay.songName);

				var songPath:String = '';

				#if FEATURE_STEPMANIA
				if (PlayState.rep.replay.sm)
					if (!Paths.exists(PlayState.rep.replay.chartPath.replace('converted.json', '')))
					{
						Application.current.window.alert('The SM file in this replay does not exist!', 'SM Replays');
						return;
					}
				#end

				PlayState.isSM = PlayState.rep.replay.sm;
				#if FEATURE_STEPMANIA
				if (PlayState.isSM)
					PlayState.pathToSm = PlayState.rep.replay.chartPath.replace('converted.json', '');
				#end

				#if FEATURE_STEPMANIA
				if (PlayState.isSM)
				{
					songPath = Paths.getTextDirect(PlayState.rep.replay.chartPath);
					try
					{
						PlayState.sm = SMFile.loadFile('${PlayState.pathToSm}/${PlayState.rep.replay.songName.replace(' ', '_')}.sm');
					}
					catch (e:Exception)
					{
						Application.current.window.alert('Make sure that the SM file is called ${PlayState.pathToSm}/${PlayState.rep.replay.songName.replace(' ', '_')}.sm!\nAs I couldn\'t read it.',
							'SM Replays');
						return;
					}
				}
				#end

				try
				{
					if (PlayState.isSM)
					{
						PlayState.song = Song.loadFromJsonDirect(songPath);
					}
					else
					{
						var diff:String = CoolUtil.difficultyString(PlayState.rep.replay.songDiff);
						if (PlayState.rep.replay.songId == null)
						{
							PlayState.rep.replay.songId = Paths.formatToSongPath(PlayState.rep.replay.songName);
						}
						PlayState.song = Song.loadFromJson(PlayState.rep.replay.songId, diff);
					}
				}
				catch (e:Exception)
				{
					Application.current.window.alert('Failed to load the song! Does the JSON exist?', 'Replays');
					return;
				}
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = PlayState.rep.replay.songDiff;
				PlayState.storyWeek = getWeekNumbFromSong(PlayState.rep.replay.songId);
				LoadingState.loadAndSwitchState(new PlayState());
			}
			else
			{
				PlayState.rep = null;
				PlayState.loadRep = false;
			}
		}
	}

	private function sortByDate(a:String, b:String):Int
	{
		var aTime:Float = Std.parseFloat(a.split('time')[1]) / 1000;
		var bTime:Float = Std.parseFloat(b.split('time')[1]) / 1000;

		return Std.int(bTime - aTime); // Newest first
	}

	public function getWeekNumbFromSong(songName:String):Int
	{
		var week:Int = 0;
		for (song in songs)
		{
			if (song.name == songName)
				week = song.week;
		}
		return week;
	}

	public function addSong(songName:String, weekNum:Int):Void
	{
		songs.push(new SongMeta(songName, weekNum));
	}

	public function addWeek(songs:Array<String>, weekNum:Int):Void
	{
		for (song in songs)
		{
			addSong(song, weekNum);
		}
	}

	private function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		var rep:Replay = Replay.loadReplay(actualNames[curSelected]);

		poggerDetails.text = 'Replay Details - \nDate Created: ${rep.replay.timestamp}\nSong: ${rep.replay.songName}\nReplay Version: ${rep.replay.replayGameVer} (${(rep.replay.replayGameVer != Replay.REPLAY_VERSION ? 'OUTDATED not useable!' : 'Latest')})\n';

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}
