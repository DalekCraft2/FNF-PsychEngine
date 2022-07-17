package;

import chart.container.Song;
import flixel.util.FlxArrayUtil;

// TODO Time signatures would be pretty cool.
class Conductor
{
	// For Reference:
	// Breve: A double note. Lasts for eight crotchet beats.
	// Semibreve: A whole note. Lasts for four crotchet beats.
	// Minim: A half note. Lasts for two crotchet beats.
	// Crotchet: A quarter note. It is one beat long in 4/4 time (We would call this a "beat" in FNF).
	// Quaver: An eighth note. Lasts for half of a crotchet beat.
	// Semiquaver: A sixteenth note. Lasts for a quarter of a crotchet beat (We would call this a "step" in FNF).
	public static inline final CROTCHETS_PER_MEASURE:Int = 4; // In 4/4 time.
	public static inline final SEMIQUAVERS_PER_CROTCHET:Int = 4;
	public static inline final SEMIQUAVERS_PER_MEASURE:Int = CROTCHETS_PER_MEASURE * SEMIQUAVERS_PER_CROTCHET; // In 4/4 time.

	/**
	 * The current tempo of the music, in beats per minute (BPM).
	 */
	public static var tempo(default, set):Float = 100;

	/**
	 * The length of a crotchet beat at the current tempo, in milliseconds.
	 */
	public static var crotchetLength(default, set):Float = calculateCrotchetLength(tempo);

	/**
	 * Length of a semiquaver beat at the current tempo, in milliseconds.
	 */
	public static var semiquaverLength:Float;

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

	public static var tempoChangeList:Array<TempoChangeEvent> = [];

	public static function initializeSafeZoneOffset():Void
	{
		safeZoneOffset = (Options.save.data.safeFrames / TimingConstants.SECONDS_PER_MINUTE) * TimingConstants.MILLISECONDS_PER_SECOND;
	}

	public static function mapTempoChanges(song:Song):Void
	{
		/*
			FlxArrayUtil.clearArray(tempoChangeList);

			var curTempo:Float = song.bpm;
			var totalSteps:Int = 0;
			var totalPos:Float = 0;
			for (section in song.notes)
			{
				if (section.changeBPM && section.bpm != curTempo)
				{
					curTempo = section.bpm;
					var event:TempoChangeEvent = {
						stepTime: totalSteps,
						songTime: totalPos,
						tempo: curTempo
					};
					tempoChangeList.push(event);
				}

				var deltaSteps:Int = section.lengthInSteps;
				totalSteps += deltaSteps;
				totalPos += calculateSemiquaverLength(curTempo) * deltaSteps;
			}
		 */
	}

	/**
	 * Calculates the length of a crotchet beat, in milliseconds, at the given tempo.
	 * @param tempo The tempo with which to calculate the crotchet length.
	 * @return the calculated crotchet length, in milliseconds.
	 */
	public static inline function calculateCrotchetLength(tempo:Float):Float
	{
		return (TimingConstants.SECONDS_PER_MINUTE / tempo) * TimingConstants.MILLISECONDS_PER_SECOND;
	}

	/**
	 * Calculates the length of a semiquaver beat, in milliseconds, at the given tempo.
	 * @param tempo The tempo with which to calculate the semiquaver length.
	 * @return the calculated semiquaver length, in milliseconds.
	 */
	public static inline function calculateSemiquaverLength(tempo:Float):Float
	{
		return calculateCrotchetLength(tempo) / (SEMIQUAVERS_PER_MEASURE / CROTCHETS_PER_MEASURE);
	}

	private static function set_tempo(value:Float):Float
	{
		if (tempo != value)
		{
			tempo = value;
			crotchetLength = calculateCrotchetLength(tempo);
		}
		return value;
	}

	private static function set_crotchetLength(value:Float):Float
	{
		if (crotchetLength != value)
		{
			crotchetLength = value;
			semiquaverLength = crotchetLength / SEMIQUAVERS_PER_CROTCHET;
		}
		return value;
	}
}

@:structInit
class TempoChangeEvent // Fun Fact: Classes are more efficient than structs.
{
	public var stepTime:Int;
	public var songTime:Float;
	public var tempo:Float;

	public function new(stepTime:Int, songTime:Float, tempo:Float)
	{
		this.stepTime = stepTime;
		this.songTime = songTime;
		this.tempo = tempo;
	}
}
