package states.substates;

import flixel.FlxSubState;

abstract class MusicBeatSubState extends FlxSubState implements MusicBeatable
{
	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var controls(get, never):Controls;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var oldStep:Int = curStep;

		updateStep();
		updateBeat();

		curBeat = Math.floor(curStep / Conductor.STEPS_PER_BEAT);

		if (oldStep != curStep && curStep > 0)
			stepHit(curStep);
	}

	public function stepHit(step:Int):Void
	{
		if (step % Conductor.STEPS_PER_BEAT == 0)
			beatHit(curBeat);
	}

	public function beatHit(beat:Int):Void
	{
	}

	private function updateStep():Void
	{
		var lastTiming:TimingSegment = TimingSegment.createFallbackTiming();
		if (Conductor.song != null)
		{
			for (timing in Conductor.song.timings)
			{
				if (Conductor.songPosition >= timing.startTime)
					lastTiming = timing;
			}
		}
		curStep = lastTiming.startStep + Math.floor(((Conductor.songPosition - Options.save.data.noteOffset) - lastTiming.startTime) / Conductor.stepLength);
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / Conductor.STEPS_PER_BEAT);
	}

	private inline function get_controls():Controls
		return PlayerSettings.player1.controls;
}
