package chart.io;

import chart.container.BasicNote;
import chart.container.Event.EventEntry;
import chart.container.Event.EventGroup;
import chart.container.Section;
import chart.container.Song;
import editors.ChartEditorState;
import flixel.util.typeLimit.OneOfTwo;

using StringTools;

class PsychChartReader implements ChartReader
{
	private final songDef:PsychSong;

	public function new(songDef:PsychSong)
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
		if (songDef.arrowSkin != null)
			song.noteSkin = songDef.arrowSkin;
		if (songDef.splashSkin != null)
			song.splashSkin = songDef.splashSkin;
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
				var noteDef:PsychNote = noteDef;
				var beat:Float = TimingStruct.getBeatFromTime(noteDef.strumTime);
				// var sustainLength:Float = TimingStruct.getBeatFromTime(noteDef.strumTime + noteDef.sustainLength) - beat;
				var sustainLength:Float = noteDef.sustainLength;
				var type:String;
				if (!Std.isOfType(noteDef.type, String)) // Convert old note type to new note type format
				{
					type = ChartEditorState.NOTE_TYPES[noteDef.type];
				}
				else
				{
					type = noteDef.type;
				}

				sectionNotes.push(new BasicNote(noteDef.strumTime, noteDef.data, sustainLength, type, beat));
			}
			section.sectionNotes = sectionNotes;
			section.lengthInSteps = sectionDef.lengthInSteps;
			section.mustHitSection = sectionDef.mustHitSection;
			section.altAnim = sectionDef.altAnim;
			section.startBeat = startBeat;
			section.endBeat = endBeat;

			song.notes.push(section);

			startStep = endStep;
		}

		for (eventSection in songDef.events)
		{
			if (eventSection is Array)
			{
				var eventArray:Array<EventEntry> = [];
				for (eventNote in eventSection.events)
				{
					var eventEntry:EventEntry = {type: eventNote.type, value1: eventNote.value1, value2: eventNote.value2};
					eventArray.push(eventEntry);
				}
				var eventGroup:EventGroup = {
					beat: TimingStruct.getBeatFromTime(eventSection.strumTime),
					events: eventArray
				};
				song.events.push(eventGroup);
			}
		}

		return song;
	}

	/**
	 * Converts old charts to newest format.
	 */
	public function updateFormat():PsychSong
	{
		if (songDef.events == null)
		{
			songDef.events = [];
			for (section in songDef.notes)
			{
				var i:Int = 0;
				var notes:Array<PsychSectionEntry> = section.sectionNotes;
				var len:Int = notes.length;
				while (i < len)
				{
					var sectionEntry:PsychSectionEntry = notes[i];
					if (PsychSection.isEvent(sectionEntry))
					{
						var sectionEntry:PsychLegacyEvent = sectionEntry;

						var eventDef:PsychEvent = new PsychEvent([sectionEntry.type, sectionEntry.value1, sectionEntry.value2]);
						var eventSection:PsychEventSection = new PsychEventSection([sectionEntry.strumTime, [eventDef]]);
						songDef.events.push(eventSection);
						notes.remove(sectionEntry);
						len = notes.length;
					}
					else
						i++;
				}
			}
		}

		if (songDef.player3 != null)
		{
			songDef.gfVersion = songDef.player3;
		}

		return songDef;
	}
}

typedef PsychSongWrapper =
{
	var song:PsychSong;
}

typedef PsychSong =
{
	var song:String;
	var player1:String;
	var player2:String;
	@:deprecated
	var ?player3:String;
	var gfVersion:String;
	var stage:String;
	var ?arrowSkin:String;
	var ?splashSkin:String;
	var bpm:Float;
	var speed:Float;
	var ?needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<PsychSection>;
	var events:Array<PsychEventSection>;
}

typedef PsychSectionEntry = OneOfTwo<PsychNote, PsychLegacyEvent>;

typedef PsychSectionDef =
{
	var sectionNotes:Array<PsychSectionEntry>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
}

@:forward
@:structInit
abstract PsychSection(PsychSectionDef) from PsychSectionDef to PsychSectionDef
{
	public static inline function isEvent(entry:PsychSectionEntry):Bool
	{
		return cast(entry, Array<Dynamic>)[1] < 0;
	}
}

abstract PsychNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_TYPE:Int = 3;

	public var strumTime(get, set):Float;
	public var data(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var type(get, set):OneOfTwo<Null<Int>, String>;

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

	private function get_type():OneOfTwo<Null<Int>, String>
	{
		return this[INDEX_TYPE];
	}

	private function set_type(value:OneOfTwo<Null<Int>, String>):OneOfTwo<Null<Int>, String>
	{
		return this[INDEX_TYPE] = value;
	}
}

abstract PsychEventSection(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_ARRAY:Int = 1;

	public var strumTime(get, set):Float;
	public var events(get, set):Array<PsychEvent>;

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

	private function get_events():Array<PsychEvent>
	{
		return this[INDEX_ARRAY];
	}

	private function set_events(value:Array<PsychEvent>):Array<PsychEvent>
	{
		return this[INDEX_ARRAY] = value;
	}
}

abstract PsychEvent(Array<String>) /*from Array<String> to Array<String>*/
{
	public static inline final INDEX_TYPE:Int = 0;
	public static inline final INDEX_VALUE_1:Int = 1;
	public static inline final INDEX_VALUE_2:Int = 2;

	public var type(get, set):String;
	public var value1(get, set):String;
	public var value2(get, set):String;

	public inline function new(array:Array<String>)
	{
		this = array;
	}

	private function get_type():String
	{
		return this[INDEX_TYPE];
	}

	private function set_type(value:String):String
	{
		return this[INDEX_TYPE] = value;
	}

	private function get_value1():String
	{
		return this[INDEX_VALUE_1];
	}

	private function set_value1(value:String):String
	{
		return this[INDEX_VALUE_1] = value;
	}

	private function get_value2():String
	{
		return this[INDEX_VALUE_2];
	}

	private function set_value2(value:String):String
	{
		return this[INDEX_VALUE_2] = value;
	}
}

abstract PsychLegacyEvent(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	// Index 1 is used for notedata, so it's set to -1 for these so thry can be recognized as events
	public static inline final INDEX_TYPE:Int = 2;
	public static inline final INDEX_VALUE_1:Int = 3;
	public static inline final INDEX_VALUE_2:Int = 4;

	public var strumTime(get, set):Float;
	public var type(get, set):String;
	public var value1(get, set):String;
	public var value2(get, set):String;

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

	private function get_type():String
	{
		return this[INDEX_TYPE];
	}

	private function set_type(value:String):String
	{
		return this[INDEX_TYPE] = value;
	}

	private function get_value1():String
	{
		return this[INDEX_VALUE_1];
	}

	private function set_value1(value:String):String
	{
		return this[INDEX_VALUE_1] = value;
	}

	private function get_value2():String
	{
		return this[INDEX_VALUE_2];
	}

	private function set_value2(value:String):String
	{
		return this[INDEX_VALUE_2] = value;
	}
}
