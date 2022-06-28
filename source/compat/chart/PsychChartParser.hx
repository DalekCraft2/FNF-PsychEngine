package compat.chart;

import Event.EventEntry;
import Event.EventGroup;
import flixel.util.typeLimit.OneOfTwo;

using StringTools;

class PsychChartParser
{
	public static function convertToMock(song:PsychSong):Song
	{
		PsychSong.updateFormat(song);

		var mockSong:Song = cast song;

		for (eventSection in song.events)
		{
			if (eventSection is Array)
			{
				var eventArray:Array<EventEntry> = [];
				for (eventNote in eventSection.events)
				{
					var eventEntry:EventEntry = {type: eventNote.type, value1: eventNote.value1, value2: eventNote.value2};
					eventArray.push(eventEntry);
				}
				var eventGroup:EventGroup = {strumTime: eventSection.strumTime, beat: TimingStruct.getBeatFromTime(eventSection.strumTime), events: eventArray};
				mockSong.events.insert(song.events.indexOf(eventSection), eventGroup);
				song.events.remove(eventSection);
				mockSong.events.push(eventGroup);
			}
		}

		return mockSong;
	}
}

typedef PsychSongWrapper =
{
	var song:PsychSong;
}

typedef PsychSongDef =
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

@:forward
@:structInit
abstract PsychSong(PsychSongDef) from PsychSongDef to PsychSongDef
{
	public static function updateFormat(song:PsychSong):PsychSong // Convert old charts to newest format
	{
		if (song != null)
		{
			if (song.events == null)
			{
				song.events = [];
				for (section in song.notes)
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
							song.events.push(eventSection);
							notes.remove(sectionEntry);
							len = notes.length;
						}
						else
							i++;
					}
				}
			}
		}

		if (Reflect.hasField(song, 'player3'))
		{
			if (song.player3 != null)
			{
				song.gfVersion = song.player3;
			}
			Reflect.deleteField(song, 'player3');
		}

		return song;
	}
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
	public static inline final INDEX_NOTE_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_NOTE_TYPE:Int = 3;

	public var strumTime(get, set):Float;
	public var noteData(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var noteType(get, set):OneOfTwo<Null<Int>, String>;

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

	private function get_noteData():Int
	{
		return this[INDEX_NOTE_DATA];
	}

	private function set_noteData(value:Int):Int
	{
		return this[INDEX_NOTE_DATA] = value;
	}

	private function get_sustainLength():Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH];
	}

	private function set_sustainLength(value:Null<Float>):Null<Float>
	{
		return this[INDEX_SUSTAIN_LENGTH] = value;
	}

	private function get_noteType():OneOfTwo<Null<Int>, String>
	{
		return this[INDEX_NOTE_TYPE];
	}

	private function set_noteType(value:OneOfTwo<Null<Int>, String>):OneOfTwo<Null<Int>, String>
	{
		return this[INDEX_NOTE_TYPE] = value;
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
