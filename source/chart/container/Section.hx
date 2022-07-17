package chart.container;

class Section
{
	public var startBeat:Float = 0;
	public var endBeat:Float = Math.POSITIVE_INFINITY;

	public var startTime:Float = 0;
	public var endTime:Float = Math.POSITIVE_INFINITY;

	public var sectionNotes:Array<BasicNote> = [];
	public var lengthInSteps:Int = Conductor.SEMIQUAVERS_PER_MEASURE;
	public var mustHitSection:Bool = true;
	public var gfSection:Bool = false;
	public var altAnim:Bool = false;

	public function new()
	{
	}
}
