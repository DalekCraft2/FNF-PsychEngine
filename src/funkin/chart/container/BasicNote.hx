package funkin.chart.container;

class BasicNote
{
	public var data:Int;
	public var sustainLength:Float;
	public var type:String;
	public var beat:Float;

	public function new(data:Int, sustainLength:Float = 0, type:String = '', beat:Float)
	{
		this.data = data;
		this.sustainLength = sustainLength;
		this.type = type;
		this.beat = beat;
	}
}
