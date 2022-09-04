package;

import chart.container.Song;

// TODO Time signatures would be pretty cool.
class Conductor
{
	public static inline final BEATS_PER_BAR:Int = 4; // In 4/4 time.
	public static inline final STEPS_PER_BEAT:Int = 4;
	public static inline final STEPS_PER_BAR:Int = BEATS_PER_BAR * STEPS_PER_BEAT; // In 4/4 time.

	/**
	 * The current tempo of the music, in beats per minute (BPM).
	 */
	public static var tempo(default, set):Float = 100;

	/**
	 * The length of a beat at the current tempo, in milliseconds.
	 */
	public static var beatLength(default, set):Float = calculateBeatLength(tempo);

	/**
	 * The length of a step at the current tempo, in milliseconds.
	 */
	public static var stepLength:Float;

	public static var songPosition:Float = 0;
	public static var rawPosition:Float;

	/**
	 * Note latency, in milliseconds.
	 */
	public static var offset:Float = 0;

	/**
	 * safeFrames, in milliseconds.
	 * Must be initialized in a method, otherwise it will try to use `Options.save()` before it is loaded and cause an NPE.
	 */
	public static var safeZoneOffset:Float;

	public static var song:Song;

	public static function prepareFromSong(song:Song):Void
	{
		Conductor.song = song;
		if (song != null)
		{
			tempo = song.tempo;
		}
	}

	public static function initializeSafeZoneOffset():Void
	{
		safeZoneOffset = (Options.save.data.safeFrames / TimingConstants.SECONDS_PER_MINUTE) * TimingConstants.MILLISECONDS_PER_SECOND;
	}

	/**
	 * Calculates the length of a crotchet beat, in milliseconds, at the given tempo.
	 * @param tempo The tempo with which to calculate the crotchet length.
	 * @return the calculated crotchet length, in milliseconds.
	 */
	public static inline function calculateBeatLength(tempo:Float):Float
	{
		return (TimingConstants.SECONDS_PER_MINUTE / tempo) * TimingConstants.MILLISECONDS_PER_SECOND;
	}

	/**
	 * Calculates the length of a semiquaver beat, in milliseconds, at the given tempo.
	 * @param tempo The tempo with which to calculate the semiquaver length.
	 * @return the calculated semiquaver length, in milliseconds.
	 */
	public static inline function calculateStepLength(tempo:Float):Float
	{
		return calculateBeatLength(tempo) / STEPS_PER_BEAT;
	}

	public static function getBeatFromTime(time:Float):Float
	{
		var timings:Array<TimingSegment> = song == null ? [TimingSegment.createFallbackTiming()] : song.timings;
		return TimingSegment.getBeatFromTime(timings, time);
	}

	public static function getTimeFromBeat(beat:Float):Float
	{
		var timings:Array<TimingSegment> = song == null ? [TimingSegment.createFallbackTiming()] : song.timings;
		return TimingSegment.getTimeFromBeat(timings, beat);
	}

	public static function getTimingAtTimestamp(msTime:Float):TimingSegment
	{
		var timings:Array<TimingSegment> = song == null ? [TimingSegment.createFallbackTiming()] : song.timings;
		return TimingSegment.getTimingAtTimestamp(timings, msTime);
	}

	public static function getTimingAtBeat(beat:Float):TimingSegment
	{
		var timings:Array<TimingSegment> = song == null ? [TimingSegment.createFallbackTiming()] : song.timings;
		return TimingSegment.getTimingAtBeat(timings, beat);
	}

	private static function set_tempo(value:Float):Float
	{
		if (tempo != value)
		{
			tempo = value;
			beatLength = calculateBeatLength(tempo);
		}
		return value;
	}

	private static function set_beatLength(value:Float):Float
	{
		if (beatLength != value)
		{
			beatLength = value;
			stepLength = beatLength / STEPS_PER_BEAT;
		}
		return value;
	}
}
