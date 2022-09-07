package funkin.chart.io;

import flixel.util.typeLimit.OneOfTwo;

typedef PsychSongWrapper =
{
	song:PsychSong
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
	var offset:Float;
}

typedef PsychSectionEntry = OneOfTwo<PsychNote, PsychLegacyEvent>;

typedef PsychSectionDef =
{
	sectionNotes:Array<PsychSectionEntry>,
	lengthInSteps:Int,
	typeOfSection:Int,
	mustHitSection:Bool,
	gfSection:Bool,
	bpm:Float,
	changeBPM:Bool,
	altAnim:Bool,
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
