package funkin.chart.io;

class KadeChart
{
	public static final LATEST_CHART:String = 'KE1';
	public static final TEMPO_CHANGE_EVENT:String = 'BPM Change';
}

typedef KadeSongWrapper =
{
	song:KadeSong
}

// This has to use class notation because of the deprecated metadata
typedef KadeSong =
{
	@:deprecated
	var ?song:String;

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
	var ?validScore:Bool;
	var notes:Array<KadeSection>;
	var eventObjects:Array<KadeEvent>;
	var ?offset:Int;
	var chartVersion:String;
}

typedef KadeSection =
{
	startTime:Float,
	endTime:Float,
	sectionNotes:Array<KadeNote>,
	lengthInSteps:Int,
	typeOfSection:Int,
	mustHitSection:Bool,
	bpm:Float,
	changeBPM:Bool,
	altAnim:Bool,
	CPUAltAnim:Bool,
	playerAltAnim:Bool
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
	name:String,
	position:Float,
	value:Float,
	type:String,
}
