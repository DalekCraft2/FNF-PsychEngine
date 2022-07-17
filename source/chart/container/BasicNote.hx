package chart.container;

class BasicNote
{
	// TODO Convert everything from using strumTime to using beats
	public var strumTime:Float;
	public var data:Int;
	// TODO Have this variable be measured in beats rather than in milliseconds
	public var sustainLength:Null<Float>;
	public var type:String;
	public var beat:Float;

	public function new(strumTime:Float, data:Int, sustainLength:Float = 0, type:String = '', beat:Float)
	{
		this.strumTime = strumTime;
		this.data = data;
		this.sustainLength = sustainLength;
		this.type = type;
		this.beat = beat;
	}
}
