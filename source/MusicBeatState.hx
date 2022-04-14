package;

import Conductor.BPMChangeEvent;
import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.ui.FlxUIState;

class MusicBeatState extends FlxUIState
{
	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var controls(get, never):Controls;

	override public function create():Void
	{
		super.create();

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var oldStep:Int = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit(curStep);

		if (EngineData.save.data != null)
			EngineData.save.data.fullscreen = FlxG.fullscreen;
	}

	#if (FEATURE_VIDEOS && desktop)
	override public function onFocusLost():Void
	{
		super.onFocusLost();

		FlxVideo.onFocusLost();
	}

	override public function onFocus():Void
	{
		super.onFocus();

		FlxVideo.onFocus();
	}
	#end

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
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

		curStep = lastChange.stepTime + Math.floor(((Conductor.songPosition - Options.save.data.noteOffset) - lastChange.songTime) / Conductor.stepCrochet);
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
