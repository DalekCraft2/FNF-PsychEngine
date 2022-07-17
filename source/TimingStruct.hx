package;

import chart.container.Song;
import flixel.util.FlxArrayUtil;

// FIXME Sometimes, when a tempo change happens, the music does a sort of "hiccup" and gets off-beat
class TimingStruct
{
	public static var allTimings:Array<TimingStruct> = [];

	public var tempo:Float = 0; // idk what does this do

	public var startStep:Int = 0; // STEPS

	// public var endStep:Int = Math.POSITIVE_INFINITY; // STEPS
	public var startBeat:Float = 0; // BEATS
	public var endBeat:Float = Math.POSITIVE_INFINITY; // BEATS

	public var startTime:Float = 0; // SECONDS

	// public var endTime:Float = 0; // SECONDS
	public var length:Float = Math.POSITIVE_INFINITY; // in beats

	public static function clearTimings():Void
	{
		FlxArrayUtil.clearArray(allTimings);
	}

	public static function generateTimings(song:Song, songMultiplier:Float = 1):Void
	{
		clearTimings();

		var currentIndex:Int = 0;
		for (eventGroup in song.events)
		{
			for (event in eventGroup.events)
			{
				if (event.type == 'Change BPM')
				{
					var startBeat:Float = eventGroup.beat;

					var endBeat:Float = Math.POSITIVE_INFINITY;

					var tempo:Float = Std.parseFloat(event.value1) * songMultiplier;

					addTiming(startBeat, tempo, endBeat, 0); // offset in this case = start time since we don't have a offset

					if (currentIndex != 0)
					{
						var data:TimingStruct = allTimings[currentIndex - 1];
						data.endBeat = startBeat;
						data.length = ((data.endBeat - data.startBeat) / (data.tempo / TimingConstants.SECONDS_PER_MINUTE)) / songMultiplier;
						var step:Float = Conductor.calculateSemiquaverLength(data.tempo);
						allTimings[currentIndex].startStep = Math.floor((((data.endBeat / (data.tempo / TimingConstants.SECONDS_PER_MINUTE)) * TimingConstants.MILLISECONDS_PER_SECOND) / step) / songMultiplier);
						allTimings[currentIndex].startTime = data.startTime + data.length / songMultiplier;
					}

					currentIndex++;
				}
			}
		}
	}

	public static function addTiming(startBeat:Float, tempo:Float, endBeat:Float, offset:Float):Void
	{
		var timing:TimingStruct = new TimingStruct(startBeat, tempo, endBeat, offset);
		allTimings.push(timing);
	}

	public static function getBeatFromTime(time:Float):Float
	{
		var seg:TimingStruct = getTimingAtTimestamp(time);

		if (seg != null)
			return seg.startBeat + (((time / TimingConstants.MILLISECONDS_PER_SECOND) - seg.startTime) * (seg.tempo / TimingConstants.SECONDS_PER_MINUTE));

		return -1;
	}

	public static function getTimeFromBeat(beat:Float):Float
	{
		var seg:TimingStruct = getTimingAtBeat(beat);

		if (seg != null)
			return (seg.startTime + ((beat - seg.startBeat) / (seg.tempo / TimingConstants.SECONDS_PER_MINUTE))) * TimingConstants.MILLISECONDS_PER_SECOND;

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
			if (timing.startBeat <= beat && timing.endBeat > beat)
				return timing;
		}
		return null;
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
