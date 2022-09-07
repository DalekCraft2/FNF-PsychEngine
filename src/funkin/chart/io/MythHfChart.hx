package funkin.chart.io;

typedef MythHfSongWrapper =
{
	song:MythHfSong
}

typedef MythHfSong =
{
	song:String,
	player1:String,
	player2:String,
	gfVersion:String,
	stage:String,
	bpm:Float,
	speed:Float,
	?needsVoices:Bool,
	?validScore:Bool,
	notes:Array<MythHfSection>,
	?startingHealth:Float,
	?opponentHealth:Float
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
