package;

class TimingStruct
{
	public static var allTimings:Array<TimingStruct> = [];

	public var bpm:Float = 0; // idk what does  this do

	public var startBeat:Float = 0; // BEATS
	public var startStep:Int = 0; // BAD MEASUREMENTS
	public var endBeat:Float = Math.POSITIVE_INFINITY; // BEATS
	public var startTime:Float = 0; // SECONDS

	public var length:Float = Math.POSITIVE_INFINITY; // in beats

	public static function clearTimings():Void
	{
		allTimings = [];
	}

	public static function addTiming(startBeat, bpm, endBeat:Float, offset:Float):Void
	{
		var pog:TimingStruct = new TimingStruct(startBeat, bpm, endBeat, offset);
		allTimings.push(pog);
	}

	public static function getBeatFromTime(time:Float):Float
	{
		var beat:Float = -1.0;
		var seg:TimingStruct = TimingStruct.getTimingAtTimestamp(time);

		if (seg != null)
			beat = seg.startBeat + (((time / 1000) - seg.startTime) * (seg.bpm / 60));

		return beat;
	}

	public static function getTimeFromBeat(beat:Float):Float
	{
		var time:Float = -1.0;
		var seg:TimingStruct = TimingStruct.getTimingAtBeat(beat);

		if (seg != null)
			time = seg.startTime + ((beat - seg.startBeat) / (seg.bpm / 60));

		return time * 1000;
	}

	public function new(startBeat:Float, bpm:Float, endBeat:Float, offset:Float)
	{
		this.bpm = bpm;
		this.startBeat = startBeat;
		if (endBeat != -1)
			this.endBeat = endBeat;
		startTime = offset;
	}

	public static function getTimingAtTimestamp(msTime:Float):TimingStruct
	{
		for (i in allTimings)
		{
			if (msTime >= i.startTime * 1000 && msTime < (i.startTime + i.length) * 1000)
				return i;
		}
		return null;
	}

	public static function getTimingAtBeat(beat):TimingStruct
	{
		for (i in allTimings)
		{
			if (i.startBeat <= beat && i.endBeat >= beat)
				return i;
		}
		return null;
	}
}
