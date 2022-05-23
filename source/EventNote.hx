package;

typedef EventNote =
{
	var strumTime:Float;
	var event:String;
	var value1:String;
	var value2:String;
}

abstract EventSectionDef(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	public static inline final INDEX_ARRAY:Int = 1;

	public var strumTime(get, set):Float;
	public var events(get, set):Array<EventNoteDef>;

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

	private function get_events():Array<EventNoteDef>
	{
		return this[INDEX_ARRAY];
	}

	private function set_events(value:Array<EventNoteDef>):Array<EventNoteDef>
	{
		return this[INDEX_ARRAY] = value;
	}
}

abstract EventNoteDef(Array<String>) /*from Array<String> to Array<String>*/
{
	public static inline final INDEX_EVENT:Int = 0;
	public static inline final INDEX_VALUE_1:Int = 1;
	public static inline final INDEX_VALUE_2:Int = 2;

	public var event(get, set):String;
	public var value1(get, set):String;
	public var value2(get, set):String;

	public inline function new(array:Array<String>)
	{
		this = array;
	}

	private function get_event():String
	{
		return this[INDEX_EVENT];
	}

	private function set_event(value:String):String
	{
		return this[INDEX_EVENT] = value;
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

abstract LegacyEventNoteDef(Array<Dynamic>) /*from Array<Dynamic> to Array<Dynamic>*/
{
	public static inline final INDEX_STRUM_TIME:Int = 0;
	// Index 1 is used for notedata, so it's set to -1 for these so thry can be recognized as events
	public static inline final INDEX_EVENT:Int = 2;
	public static inline final INDEX_VALUE_1:Int = 3;
	public static inline final INDEX_VALUE_2:Int = 4;

	public var strumTime(get, set):Float;
	public var event(get, set):String;
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

	private function get_event():String
	{
		return this[INDEX_EVENT];
	}

	private function set_event(value:String):String
	{
		return this[INDEX_EVENT] = value;
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
