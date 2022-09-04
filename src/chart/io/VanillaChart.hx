package chart.io;

typedef VanillaSongWrapper =
{
	song:VanillaSong
}

typedef VanillaSong =
{
	song:String,
	player1:String,
	player2:String,
	bpm:Float,
	speed:Float,
	?needsVoices:Bool,
	?validScore:Bool,
	notes:Array<VanillaSection>
}

typedef VanillaSection =
{
	sectionNotes:Array<VanillaNote>,
	lengthInSteps:Int,
	typeOfSection:Int,
	mustHitSection:Bool,
	bpm:Float,
	changeBPM:Bool,
	altAnim:Bool
}

abstract VanillaNote(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_DATA:Int = 1;
	public static inline final INDEX_SUSTAIN_LENGTH:Int = 2;
	public static inline final INDEX_IS_ALT:Int = 3;

	public var strumTime(get, set):Float;
	public var data(get, set):Int;
	public var sustainLength(get, set):Null<Float>;
	public var isAlt(get, set):Null<Bool>;

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
		return this[INDEX_IS_ALT];
	}

	private function set_isAlt(value:Null<Bool>):Null<Bool>
	{
		return this[INDEX_IS_ALT] = value;
	}
}
