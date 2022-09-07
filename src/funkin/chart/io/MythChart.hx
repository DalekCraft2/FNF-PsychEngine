package funkin.chart.io;

typedef MythSongWrapper =
{
	song:MythSong
}

// This has to use class notation because of the deprecated metadata
typedef MythSong =
{
	@:deprecated
	var song:String;

	/**
	 * The readable name of the songDef, as displayed to the user.
	 		* Can be any string.
	 */
	var songName:String;

	/**
	 * The internal name of the songDef, as used in the file system.
	 */
	var songId:String;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var bpm:Float;
	var speed:Float;
	var ?needsVoices:Bool;
	var ?validScore:Bool;
	var notes:Array<MythSection>;
	var events:Array<MythEvent>;
	var ?startingHealth:Float;
	var ?opponentHealth:Float;
	var offset:Int;
	var chartVersion:String;
}

typedef MythSection =
{
	startTime:Float,
	endTime:Float,
	sectionNotes:Array<MythNote>,
	lengthInSteps:Int,
	typeOfSection:Int,
	mustHitSection:Bool,
	midSection:Bool,
	gfSection:Bool,
	bpm:Float,
	changeBPM:Bool,
	altAnim:Bool,
	playerPrimaryAltAnim:Bool,
	playerSecondaryAltAnim:Bool,
	CPUPrimaryAltAnim:Bool,
	CPUSecondaryAltAnim:Bool
}

abstract MythNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_TYPE:Int = 3;

	public var strumTime(get, set):Float;
	public var data(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var type(get, set):String;

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

typedef MythEvent =
{
	step:Int,
	name:String,
	args:Array<Any>
}
