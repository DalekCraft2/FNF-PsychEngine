package chart.container;

class Bar
{
	public var startBeat:Float = 0;
	public var endBeat:Float = Math.POSITIVE_INFINITY;

	public var startTime:Float = 0;
	public var endTime:Float = Math.POSITIVE_INFINITY;

	public var notes:Array<BasicNote> = [];
	// TODO Replace this field with a time signature system
	public var lengthInSteps:Int = Conductor.STEPS_PER_BAR;
	public var mustHit:Bool = true;
	public var gfSings:Bool = false;
	public var altAnim:Bool = false;

	public function new()
	{
	}
}
