package;

import flixel.util.FlxArrayUtil;

// FIXME Sometimes, when a tempo change happens, the music does a sort of "hiccup" and gets off-beat
class TimingStruct
{
	public static var allTimings:Array<TimingStruct> = [];

	public var bpm:Float = 0; // idk what does this do

	public var startBeat:Float = 0; // BEATS
	public var startStep:Int = 0; // BAD MEASUREMENTS
	public var endBeat:Float = Math.POSITIVE_INFINITY; // BEATS
	public var startTime:Float = 0; // SECONDS

	public var length:Float = Math.POSITIVE_INFINITY; // in beats

	public static function clearTimings():Void
	{
		FlxArrayUtil.clearArray(allTimings);
	}

	public static function addTiming(startBeat:Float, bpm:Float, endBeat:Float, offset:Float):Void
	{
		var timing:TimingStruct = new TimingStruct(startBeat, bpm, endBeat, offset);
		allTimings.push(timing);
	}

	public static function getBeatFromTime(time:Float):Float
	{
		var seg:TimingStruct = TimingStruct.getTimingAtTimestamp(time);

		if (seg != null)
			return seg.startBeat + (((time / TimingConstants.MILLISECONDS_PER_SECOND) - seg.startTime) * (seg.bpm / TimingConstants.SECONDS_PER_MINUTE));

		return -1;
	}

	public static function getTimeFromBeat(beat:Float):Float
	{
		var seg:TimingStruct = TimingStruct.getTimingAtBeat(beat);

		if (seg != null)
			return (seg.startTime + ((beat - seg.startBeat) / (seg.bpm / TimingConstants.SECONDS_PER_MINUTE))) * TimingConstants.MILLISECONDS_PER_SECOND;

		return -1;
	}

	public static function getTimingAtTimestamp(msTime:Float):TimingStruct
	{
		for (timing in allTimings)
		{
			if (msTime >= timing.startTime * TimingConstants.MILLISECONDS_PER_SECOND
				&& msTime < (timing.startTime + timing.length) * TimingConstants.MILLISECONDS_PER_SECOND)
				return timing;
		}
		return null;
	}

	public static function getTimingAtBeat(beat:Float):TimingStruct
	{
		for (timing in allTimings)
		{
			if (timing.startBeat <= beat && timing.endBeat >= beat)
				return timing;
		}
		return null;
	}

	public function new(startBeat:Float, bpm:Float, endBeat:Float, offset:Float)
	{
		this.bpm = bpm;
		this.startBeat = startBeat;
		if (endBeat != -1)
			this.endBeat = endBeat;
		startTime = offset;
	}
}
