package funkin.chart.container;

import flixel.FlxG;
import flixel.system.FlxSound;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxSort;
import funkin.chart.container.Event.EventGroup;
import funkin.chart.container.SongMetadata.SongMetadataDef;
import funkin.chart.io.ChartUtils;
import haxe.Json;
import haxe.Serializer;
import haxe.io.Path;

using StringTools;

class Song
{
	/**
	 * The song ID used in case the requested song is missing.
	 */
	public static inline final DEFAULT_SONG:String = 'tutorial';

	/**
	 * The internal name of the song, as used in the file system.
	 */
	public var id:String;

	/**
	 * The readable name of the song, as displayed to the user.
	 * Can be any string.
	 */
	public var name:String;

	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var stage:String = 'stage';
	public var noteSkin:String = 'NOTE_assets';
	public var splashSkin:String = 'noteSplashes';

	public var tempo:Float = 120;
	// TODO Figure out the unit of measurement for the scroll speed because it would probably help a lot
	public var scrollSpeed:Float = 1;
	public var needsVoices:Bool = true;
	public var validScore:Bool = true;

	public var bars:Array<Bar> = [];

	public var events:Array<EventGroup> = [];

	public var offset:Float = 0;

	public var timings:Array<TimingSegment> = [];

	// TODO Use FlxSoundGroup, maybe
	public var vocals:FlxSound;
	public var inst(get, never):FlxSound;

	public static function createTemplateSong():Song
	{
		var song:Song = new Song();
		song.id = 'test';
		song.name = 'Test';
		song.tempo = 150; // This is the tempo of the "Test" song
		return song;
	}

	public static function fromJsonString(rawJson:String):Song
	{
		var songWrapper:Dynamic = Json.parse(rawJson);
		if (songWrapper == null)
			return null;
		var songDef:Dynamic = songWrapper.song;
		if (songDef == null)
			return null;
		var song:Song = createFromSongDef(songDef);
		song.id = 'rawsong';
		song.name = 'Raw Song';
		return song;
	}

	public static function getSongDef(id:String, difficulty:String, ?folder:String):Dynamic
	{
		if (folder == null)
		{
			folder = id;
		}

		var songWrapper:Dynamic = getSongWrapper(id, difficulty, folder);
		if (songWrapper == null)
		{
			Debug.logError('Could not find song data for song "$id"; using default');
			songWrapper = getSongWrapper(DEFAULT_SONG, '');
		}
		var songDef:Dynamic = songWrapper.song;
		return songDef;
	}

	public static function loadSong(id:String, difficulty:String, ?folder:String):Song
	{
		var songDef:Dynamic = getSongDef(id, difficulty, folder);
		var songMetadataDef:SongMetadataDef = SongMetadata.getSongMetadataDef(id, folder);
		var song:Song = createFromSongDef(songDef);
		song.id = id;
		song.name = songMetadataDef == null ? Paths.formatFromSongPath(id) : songMetadataDef.name;
		return song;
	}

	public static function getSongWrapper(id:String, difficulty:String, ?folder:String):Dynamic
	{
		if (folder == null)
		{
			folder = id;
		}
		var songWrapper:Dynamic = Paths.getJson(Path.join(['songs', folder, '$id$difficulty']));
		return songWrapper;
	}

	public static function createFromSongDef(songDef:Dynamic):Song
	{
		var song:Song = ChartUtils.read(songDef);
		song.generateTimings();
		song.recalculateAllBarTimes();
		song.events.sort((obj1:EventGroup, obj2:EventGroup) -> FlxSort.byValues(FlxSort.ASCENDING, obj1.beat, obj2.beat));
		return song;
	}

	public static function toSongDef(song:Song, chartFormat:ChartFormat = MOCK):Dynamic
	{
		return ChartUtils.write(song, chartFormat);
	}

	public function new()
	{
	}

	public function recalculateAllBarTimes():Void
	{
		var startBeat:Float = 0;
		for (bar in bars)
		{
			var endBeat:Float = startBeat + Math.floor(bar.lengthInSteps / Conductor.STEPS_PER_BEAT);

			var startTime:Float = getTimeFromBeat(startBeat);
			var endTime:Float = getTimeFromBeat(endBeat);

			bar.startBeat = startBeat;
			bar.endBeat = endBeat;
			bar.startTime = startTime;
			bar.endTime = endTime;

			startBeat = endBeat;
		}
	}

	public function clearTimings():Void
	{
		FlxArrayUtil.clearArray(timings);
	}

	public function generateTimings(songMultiplier:Float = 1):Void
	{
		clearTimings();
		addTiming(0, tempo, Math.POSITIVE_INFINITY, 0); // Starting tempo

		for (eventGroup in events)
		{
			for (event in eventGroup.events)
			{
				if (event.type == 'Change Tempo')
				{
					var startBeat:Float = eventGroup.beat;

					var endBeat:Float = Math.POSITIVE_INFINITY;

					var tempo:Float = Std.parseFloat(event.args[0]) * songMultiplier;

					var previousSeg:TimingSegment = timings[timings.length - 1];
					var currentSeg:TimingSegment = addTiming(startBeat, tempo, endBeat, 0); // offset in this case = start time since we don't have a offset

					previousSeg.endBeat = startBeat;
					previousSeg.length = ((previousSeg.endBeat - previousSeg.startBeat) / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE)) / songMultiplier;
					var stepLength:Float = Conductor.calculateStepLength(previousSeg.tempo);
					currentSeg.startStep = Math.floor((((previousSeg.endBeat / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / stepLength) / songMultiplier);
					currentSeg.startTime = previousSeg.startTime + previousSeg.length / songMultiplier;
				}
			}
		}
	}

	public function addTiming(startBeat:Float, tempo:Float, endBeat:Float, startTime:Float):TimingSegment
	{
		var timing:TimingSegment = new TimingSegment(startBeat, tempo, endBeat, startTime);
		timings.push(timing);
		return timing;
	}

	public function getBeatFromTime(time:Float):Float
	{
		return TimingSegment.getBeatFromTime(timings, time);
	}

	public function getTimeFromBeat(beat:Float):Float
	{
		return TimingSegment.getTimeFromBeat(timings, beat);
	}

	public function getTimingAtTimestamp(msTime:Float):TimingSegment
	{
		return TimingSegment.getTimingAtTimestamp(timings, msTime);
	}

	public function getTimingAtBeat(beat:Float):TimingSegment
	{
		return TimingSegment.getTimingAtBeat(timings, beat);
	}

	@:keep
	private function hxSerialize(s:Serializer):Void
	{
		s.serialize(id);
		s.serialize(name);
		s.serialize(player1);
		s.serialize(player2);
		s.serialize(gfVersion);
		s.serialize(stage);
		s.serialize(noteSkin);
		s.serialize(splashSkin);
		s.serialize(tempo);
		s.serialize(scrollSpeed);
		s.serialize(needsVoices);
		s.serialize(validScore);
		s.serialize(bars);
		s.serialize(events);
		s.serialize(offset);
		s.serialize(timings);
	}

	// @:keep
	// private function hxUnserialize(u:Unserializer):Void
	// {
	// }

	private function get_inst():FlxSound
	{
		return FlxG.sound.music;
	}
}
