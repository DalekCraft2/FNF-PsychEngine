package;

import Conductor.TempoChangeEvent;
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

		curBeat = Math.floor(curStep / Conductor.SEMIQUAVERS_PER_CROTCHET);

		if (oldStep != curStep && curStep > 0)
			stepHit(curStep);
	}

	public function stepHit(step:Int):Void
	{
		if (step % Conductor.SEMIQUAVERS_PER_CROTCHET == 0)
			beatHit(curBeat);
	}

	public function beatHit(beat:Int):Void
	{
		// Do nothing
	}

	private function updateStep():Void
	{
		var lastChange:TempoChangeEvent = {
			stepTime: 0,
			songTime: 0,
			tempo: 0
		}
		for (tempoChange in Conductor.tempoChangeList)
		{
			if (Conductor.songPosition >= tempoChange.songTime)
				lastChange = tempoChange;
		}

		curStep = lastChange.stepTime
			+ Math.floor(((Conductor.songPosition - Options.save.data.noteOffset) - lastChange.songTime) / Conductor.semiquaverLength);
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / Conductor.SEMIQUAVERS_PER_CROTCHET);
	}

	private inline function get_controls():Controls
		return PlayerSettings.player1.controls;
}
