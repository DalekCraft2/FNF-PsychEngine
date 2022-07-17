package chart.io;

import chart.container.BasicNote;
import chart.container.Section;
import chart.container.Song;

using StringTools;

class KadeChartReader implements ChartReader
{
	private final songDef:KadeSong;

	public function new(songDef:KadeSong)
	{
		this.songDef = songDef;
	}

	public function read():Song
	{
		updateFormat();

		var song:Song = new Song();
		if (songDef.player1 != null)
			song.player1 = songDef.player1;
		if (songDef.player2 != null)
			song.player2 = songDef.player2;
		if (songDef.gfVersion != null)
			song.gfVersion = songDef.gfVersion;
		if (songDef.stage != null)
			song.stage = songDef.stage;
		// if (songDef.bpm != null)
		song.bpm = songDef.bpm;
		// if (songDef.speed != null)
		song.speed = songDef.speed;
		// if (songDef.needsVoices != null)
		song.needsVoices = songDef.needsVoices;
		// if (songDef.validScore != null)
		song.validScore = songDef.validScore;

		for (sectionDef in songDef.notes)
		{
			var section:Section = new Section();
			var sectionNotes:Array<BasicNote> = [];
			for (noteDef in sectionDef.sectionNotes)
			{
				var beat:Float = TimingStruct.getBeatFromTime(noteDef.strumTime);
				// var sustainLength:Float = TimingStruct.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				var sustainLength:Float = noteDef.sustainLength;
				sectionNotes.push(new BasicNote(noteDef.strumTime, noteDef.data, sustainLength, noteDef.isAlt ? 'Alt Animation' : null, beat));
			}
			section.sectionNotes = sectionNotes;
			section.lengthInSteps = sectionDef.lengthInSteps;
			section.mustHitSection = sectionDef.mustHitSection;
			section.altAnim = sectionDef.altAnim || sectionDef.CPUAltAnim;

			song.notes.push(section);
		}

		if (songDef.eventObjects != null)
		{
			for (eventObject in songDef.eventObjects)
			{
				if (eventObject.type == 'BPM Change')
				{
					eventObject.type = 'Change BPM';
				}

				song.events.push({beat: eventObject.position, events: [{type: eventObject.type, value1: eventObject.value}]});
			}
		}

		return song;
	}

	/**
	 * Converts old charts to newest format.
	 */
	public function updateFormat():KadeSong
	{
		// if (songDef.noteStyle == null)
		// 	songDef.noteStyle = 'normal';

		// if (songDef.gfVersion == null)
		// 	songDef.gfVersion = 'gf';

		if (songDef.eventObjects == null)
		{
			songDef.eventObjects = [
				{
					name: 'Init BPM',
					position: 0,
					value: songDef.bpm,
					type: 'BPM Change'
				}
			];
		}

		TimingStruct.clearTimings();

		var tempoChangeIndex:Int = 0;
		for (eventObject in songDef.eventObjects)
		{
			if (eventObject.type == 'BPM Change')
			{
				var startBeat:Float = eventObject.position;

				var endBeat:Float = Math.POSITIVE_INFINITY;

				TimingStruct.addTiming(startBeat, eventObject.value, endBeat, 0); // offset in this case = start time since we don't have a offset

				if (tempoChangeIndex != 0)
				{
					var previousSeg:TimingStruct = TimingStruct.allTimings[tempoChangeIndex - 1];
					previousSeg.endBeat = startBeat;
					previousSeg.length = (previousSeg.endBeat - previousSeg.startBeat) / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE);
					var semiquaverLength:Float = Conductor.calculateSemiquaverLength(previousSeg.tempo);
					TimingStruct.allTimings[tempoChangeIndex].startStep = Math.floor(((previousSeg.endBeat / (previousSeg.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / semiquaverLength);
					TimingStruct.allTimings[tempoChangeIndex].startTime = previousSeg.startTime + previousSeg.length;
				}

				tempoChangeIndex++;
			}
		}

		var startStep:Int = 0;
		var tempoChangeIndex:Int = 0;
		var currentTempo:Float = songDef.bpm;
		for (sectionDef in songDef.notes)
		{
			var endStep:Int = startStep + sectionDef.lengthInSteps;

			var startBeat:Float = startStep / Conductor.SEMIQUAVERS_PER_CROTCHET;
			var endBeat:Float = endStep / Conductor.SEMIQUAVERS_PER_CROTCHET;

			if (sectionDef.altAnim)
				sectionDef.CPUAltAnim = sectionDef.altAnim;

			var currentSeg:TimingStruct = TimingStruct.getTimingAtBeat(startBeat);

			if (currentSeg == null)
				continue;

			if (sectionDef.changeBPM && sectionDef.bpm != currentTempo)
			{
				currentTempo = sectionDef.bpm;
				songDef.eventObjects.push({
					name: 'FNF BPM Change $tempoChangeIndex',
					position: startBeat,
					value: sectionDef.bpm,
					type: 'BPM Change'
				});
				tempoChangeIndex++;
			}

			for (noteDef in sectionDef.sectionNotes)
			{
				if (songDef.chartVersion == null)
				{
					noteDef.isAlt = false;
					noteDef.beat = TimingStruct.getBeatFromTime(noteDef.strumTime);
				}

				// if (noteDef.isAlt == 0)
				// 	noteDef.isAlt == false;
			}

			startStep = endStep;
		}

		// songDef.chartVersion = LATEST_CHART;

		return songDef;
	}
}

typedef KadeSongWrapper =
{
	var song:KadeSong;
}

typedef KadeSong =
{
	@:deprecated
	var song:String;

	/**
	 * The readable name of the song, as displayed to the user.
	 		* Can be any string.
	 */
	var songName:String;

	/**
	 * The internal name of the song, as used in the file system.
	 */
	var songId:String;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var noteStyle:String;
	var bpm:Float;
	var speed:Float;
	var needsVoices:Bool;
	var validScore:Bool;
	var notes:Array<KadeSection>;
	var eventObjects:Array<KadeEvent>;
	var offset:Int;
	var chartVersion:String;
}

typedef KadeSection =
{
	var startTime:Float;
	var endTime:Float;
	var sectionNotes:Array<KadeNote>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
	var CPUAltAnim:Bool;
	var playerAltAnim:Bool;
}

abstract KadeNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_ALT:Int = 3;
	public static inline final INDEX_BEAT:Int = 4;

	public var strumTime(get, set):Float;
	public var data(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var isAlt(get, set):Null<Bool>;
	public var beat(get, set):Null<Float>;

	public inline function new(array:Array<Dynamic>)
	{
		this = array;
	}

	private function get_strumTime():Float
	{
		return this[INDEX_STRUM_TIME];
	}

	private function set_strumTime(value:Float):Float
	{
		return this[INDEX_STRUM_TIME] = value;
	}

	private function get_data():Int
	{
		return this[INDEX_DATA];
	}

	private function set_data(value:Int):Int
	{
		return this[INDEX_DATA] = value;
	}

	private function get_sustainLength():Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH];
	}

	private function set_sustainLength(value:Null<Float>):Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH] = value;
	}

	private function get_isAlt():Null<Bool>
	{
		return this[INDEX_ALT];
	}

	private function set_isAlt(value:Null<Bool>):Null<Bool>
	{
		return this[INDEX_ALT] = value;
	}

	private function get_beat():Null<Float>
	{
		return this[INDEX_BEAT];
	}

	private function set_beat(value:Null<Float>):Null<Float>
	{
		return this[INDEX_BEAT] = value;
	}
}

typedef KadeEvent =
{
	var name:String;
	var position:Float;
	var value:Float;
	var type:String;
}
