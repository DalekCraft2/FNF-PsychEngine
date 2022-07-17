package chart.io;

import chart.container.BasicNote;
import chart.container.Section;
import chart.container.Song;

using StringTools;

class MythHfChartReader implements ChartReader
{
	private final songDef:MythHfSong;

	public function new(songDef:MythHfSong)
	{
		this.songDef = songDef;
	}

	public function read():Song
	{
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
		if (songDef.needsVoices != null)
			song.needsVoices = songDef.needsVoices;
		if (songDef.validScore != null)
			song.validScore = songDef.validScore;

		song.events.push({
			beat: 0,
			events: [
				{
					type: 'Change BPM',
					value1: song.bpm
				}
			]
		});

		TimingStruct.clearTimings();
		TimingStruct.addTiming(0, song.bpm, Math.POSITIVE_INFINITY, 0);

		var startStep:Int = 0;
		var tempoChangeIndex:Int = 0;
		var currentTempo:Float = song.bpm;
		for (sectionDef in songDef.notes)
		{
			var endStep:Int = startStep + sectionDef.lengthInSteps;

			var startBeat:Float = startStep / Conductor.SEMIQUAVERS_PER_CROTCHET;
			var endBeat:Float = endStep / Conductor.SEMIQUAVERS_PER_CROTCHET;

			var currentSeg:TimingStruct = TimingStruct.getTimingAtBeat(startBeat);

			if (currentSeg == null)
				continue;

			if (sectionDef.changeBPM && sectionDef.bpm != currentTempo)
			{
				currentTempo = sectionDef.bpm;
				song.events.push({
					beat: startBeat,
					events: [
						{
							value1: currentTempo,
							type: 'Change BPM'
						}
					]
				});

				var endBeat:Float = Math.POSITIVE_INFINITY;

				TimingStruct.addTiming(startBeat, currentTempo, endBeat, 0);

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

			var section:Section = new Section();
			var sectionNotes:Array<BasicNote> = [];
			for (noteDef in sectionDef.sectionNotes)
			{
				var beat:Float = TimingStruct.getBeatFromTime(noteDef.strumTime);
				// var sustainLength:Float = TimingStruct.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				var sustainLength:Float = noteDef.sustainLength;
				sectionNotes.push(new BasicNote(noteDef.strumTime, noteDef.data, sustainLength, noteDef.type, beat));
			}
			section.sectionNotes = sectionNotes;
			section.lengthInSteps = sectionDef.lengthInSteps;
			section.mustHitSection = sectionDef.mustHitSection;
			section.altAnim = sectionDef.altAnim || sectionDef.CPUAltAnim || sectionDef.CPUPrimaryAltAnim || sectionDef.CPUSecondaryAltAnim;
			section.startBeat = startBeat;
			section.endBeat = endBeat;

			song.notes.push(section);

			startStep = endStep;
		}

		return song;
	}
}

typedef MythHfSongWrapper =
{
	var song:MythHfSong;
}

typedef MythHfSong =
{
	var song:String;
	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var bpm:Float;
	var speed:Float;
	var ?needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<MythHfSection>;
	var ?startingHealth:Float;
	var ?opponentHealth:Float;
}

typedef MythHfSection =
{
	var sectionNotes:Array<MythHfNote>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	@:deprecated
	var altAnim:Bool;
	@:deprecated
	var playerAltAnim:Bool;
	var playerPrimaryAltAnim:Bool;
	var playerSecondaryAltAnim:Bool;
	@:deprecated
	var CPUAltAnim:Bool;
	var CPUPrimaryAltAnim:Bool;
	var CPUSecondaryAltAnim:Bool;
}

abstract MythHfNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_TYPE:Int = 3;

	public var strumTime(get, set):Float;
	public var data(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var type(get, set):String;

	// And then there are three more boolean arguments in the HoloFunk Myth note format and I don't know what they do.

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

	private function get_type():String
	{
		return this[INDEX_TYPE];
	}

	private function set_type(value:String):String
	{
		return this[INDEX_TYPE] = value;
	}
}
