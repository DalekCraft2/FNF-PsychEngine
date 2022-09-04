package chart.container;

typedef EventEntry =
{
	type:String,
	args:Array<Any>
}

typedef EventGroup =
{
	beat:Float,
	events:Array<EventEntry>
}

// TODO Event JSON files for some minor configuration?
class Event
{
	public var beat:Float;
	public var type:String;
	public var args:Array<Any>;

	public function new(beat:Float, type:String, ?args:Array<Any>)
	{
		this.beat = beat;
		this.type = type;
		this.args = args;
	}
}
