package funkin;

class TimingSegment
{
	/**
	 * The tempo of the segment, in beats per minute (BPM).
	 */
	public var tempo:Float = 0;

	/**
	 * The start position of the segment, in steps.
	 */
	public var startStep:Int = 0;

	// /**
	//  * The end position of the segment, in steps.
	//  */
	// public var endStep:Int = Math.POSITIVE_INFINITY;

	/**
	 * The start position of the segment, in beats.
	 */
	public var startBeat:Float = 0;

	/**
	 * The end position of the segment, in beats.
	 */
	public var endBeat:Float = Math.POSITIVE_INFINITY;

	/**
	 * The start position of the segment, in seconds.
	 */
	public var startTime:Float = 0;

	// /**
	//  * The end position of the segment, in seconds.
	//  */
	// public var endTime:Float = 0;

	/**
	 * The length of the segment, in beats.
	 */
	public var length:Float = Math.POSITIVE_INFINITY;

	public static function getBeatFromTime(timings:Array<TimingSegment>, time:Float):Float
	{
		var seg:TimingSegment = getTimingAtTimestamp(timings, time);

		if (seg != null)
			return seg.startBeat + (((time / TimingConstants.MILLISECONDS_PER_SECOND) - seg.startTime) * (seg.tempo / TimingConstants.SECONDS_PER_MINUTE));

		return -1;
	}

	public static function getTimeFromBeat(timings:Array<TimingSegment>, beat:Float):Float
	{
		var seg:TimingSegment = getTimingAtBeat(timings, beat);

		if (seg != null)
			return (seg.startTime + ((beat - seg.startBeat) / (seg.tempo / TimingConstants.SECONDS_PER_MINUTE))) * TimingConstants.MILLISECONDS_PER_SECOND;

		return -1;
	}

	public static function getTimingAtTimestamp(timings:Array<TimingSegment>, msTime:Float):TimingSegment
	{
		for (timing in timings)
		{
			if (msTime >= timing.startTime * TimingConstants.MILLISECONDS_PER_SECOND
				&& msTime < (timing.startTime + timing.length) * TimingConstants.MILLISECONDS_PER_SECOND)
				return timing;
		}
		return TimingSegment.createFallbackTiming();
	}

	public static function getTimingAtBeat(timings:Array<TimingSegment>, beat:Float):TimingSegment
	{
		for (timing in timings)
		{
			if (timing.startBeat <= beat && timing.endBeat > beat)
				return timing;
		}
		return TimingSegment.createFallbackTiming();
	}

	public static function createFallbackTiming():TimingSegment
	{
		return new TimingSegment(0, Conductor.tempo, -1, 0);
	}

	public function new(startBeat:Float, tempo:Float, endBeat:Float, startTime:Float)
	{
		this.tempo = tempo;
		this.startBeat = startBeat;
		if (endBeat != -1)
			this.endBeat = endBeat;
		this.startTime = startTime;
	}
}
