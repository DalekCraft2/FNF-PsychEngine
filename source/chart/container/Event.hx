package chart.container;

typedef EventEntry =
{
	var type:String;
	var ?value1:Dynamic;
	var ?value2:Dynamic;
	// public var args:Array<Dynamic>;
}

typedef EventGroup =
{
	// var strumTime:Float;
	var beat:Float;
	var events:Array<EventEntry>;
}

// TODO Event JSON files for some minor configuration?
class Event
{
	// public var strumTime:Float;
	public var beat:Float;
	public var type:String;
	public var value1:Dynamic;
	public var value2:Dynamic;

	// public var args:Array<Dynamic>;

	public function new(strumTime:Float, beat:Float, type:String, ?value1:Dynamic, ?value2:Dynamic)
	{
		// this.strumTime = strumTime;
		this.beat = beat;
		this.type = type;
		this.value1 = value1;
		this.value2 = value2;
	}
}
