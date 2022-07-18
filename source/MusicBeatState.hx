package;

import flixel.FlxG;
import flixel.addons.ui.FlxUIState;

// TODO Combine Psych's new curSection and curDecStep stuff with Mock's TimingStruct stuff
abstract class MusicBeatState extends FlxUIState implements MusicBeatable
{
	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecimalBeat:Float = 0;

	private var controls(get, never):Controls;

	override public function create():Void
	{
		Paths.clearUnusedMemory();

		super.create();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (Conductor.songPosition < 0)
		{
			curDecimalBeat = 0;
		}
		else
		{
			if (TimingStruct.allTimings.length > 1)
			{
				var data:TimingStruct = TimingStruct.getTimingAtTimestamp(Conductor.songPosition);

				Conductor.crotchetLength = Conductor.calculateCrotchetLength(data.tempo);

				var startInMS:Float = data.startTime * TimingConstants.MILLISECONDS_PER_SECOND;

				curDecimalBeat = data.startBeat
					+ (((Conductor.songPosition / TimingConstants.MILLISECONDS_PER_SECOND)
						- data.startTime) * (data.tempo / TimingConstants.SECONDS_PER_MINUTE));
				var nextStep:Int = Math.floor(data.startStep + (Conductor.songPosition - startInMS) / Conductor.semiquaverLength);
				if (nextStep >= 0)
				{
					if (nextStep > curStep)
					{
						for (i in curStep...nextStep)
						{
							curStep++;
							updateBeat();
							stepHit(curStep);
						}
					}
					else if (nextStep < curStep)
					{
						// Song reset?
						Debug.logTrace('reset steps for some reason?? at ${Conductor.songPosition}');
						curStep = nextStep;
						updateBeat();
						stepHit(curStep);
					}
				}
			}
			else
			{
				curDecimalBeat = (Conductor.songPosition / TimingConstants.MILLISECONDS_PER_SECOND) * (Conductor.tempo / TimingConstants.SECONDS_PER_MINUTE);
				var nextStep:Int = Math.floor(Conductor.songPosition / Conductor.semiquaverLength);
				if (nextStep >= 0)
				{
					if (nextStep > curStep)
					{
						for (i in curStep...nextStep)
						{
							curStep++;
							updateBeat();
							stepHit(curStep);
						}
					}
					else if (nextStep < curStep)
					{
						// Song reset?
						Debug.logTrace('(no bpm change) reset steps for some reason?? at ${Conductor.songPosition}');
						curStep = nextStep;
						updateBeat();
						stepHit(curStep);
					}
				}
			}
		}

		if (EngineData.save.data != null)
			EngineData.save.data.fullscreen = FlxG.fullscreen;
	}

	#if FEATURE_VIDEOS
	override public function onFocusLost():Void
	{
		super.onFocusLost();

		if (VideoHandler.instance != null)
		{
			VideoHandler.instance.onFocusLost();
		}
	}

	override public function onFocus():Void
	{
		super.onFocus();

		if (VideoHandler.instance != null)
		{
			VideoHandler.instance.onFocus();
		}
	}
	#end

	public function stepHit(step:Int):Void
	{
		if (step % Conductor.SEMIQUAVERS_PER_CROTCHET == 0)
			beatHit(curBeat);
	}

	public function beatHit(beat:Int):Void
	{
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / Conductor.SEMIQUAVERS_PER_CROTCHET);
	}

	private inline function get_controls():Controls
		return PlayerSettings.player1.controls;
}
