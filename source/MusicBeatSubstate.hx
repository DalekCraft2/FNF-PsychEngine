package;

import Conductor.BPMChangeEvent;
import flixel.FlxSubState;

class MusicBeatSubState extends FlxSubState
{
	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var controls(get, never):Controls;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var oldStep:Int = curStep;

		updateCurStep();
		curBeat = Math.floor(curStep / 4);

		if (oldStep != curStep && curStep > 0)
			stepHit(curStep);
	}

	private function updateCurStep():Void
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (bpmChange in Conductor.bpmChangeMap)
		{
			if (Conductor.songPosition >= bpmChange.songTime)
				lastChange = bpmChange;
		}

		curStep = lastChange.stepTime + Math.floor((Conductor.songPosition - lastChange.songTime) / Conductor.stepCrochet);
	}

	public function stepHit(step:Int):Void
	{
		if (step % 4 == 0)
			beatHit(curBeat);
	}

	public function beatHit(beat:Int):Void
	{
		// Do nothing
	}

	private inline function get_controls():Controls
		return PlayerSettings.player1.controls;
}
