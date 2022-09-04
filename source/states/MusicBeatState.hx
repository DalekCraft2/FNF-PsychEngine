package states;

import flixel.FlxG;
import flixel.addons.ui.FlxUIState;

abstract class MusicBeatState extends FlxUIState implements MusicBeatable
{
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	// TODO Find a way to make barHit(0) always called
	private var curBar:Int = 0;

	private var curDecimalStep:Float = 0;
	private var curDecimalBeat:Float = 0;

	private var controls(get, never):Controls;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var oldStep:Int = curStep;

		updateStep();
		updateBeat();

		if (oldStep != curStep)
		{
			// for (i in oldStep + 1...curStep)
			// {
			// 	stepHit(i);
			// }
			stepHit(curStep);

			if (PlayState.song != null)
			{
				if (oldStep < curStep)
					updateBar();
				else
					rollbackBar();
			}
		}

		if (EngineData.save.data != null)
			EngineData.save.data.fullscreen = FlxG.fullscreen;

		Debug.quickWatch('Step', curDecimalStep);
		Debug.quickWatch('Beat', curDecimalBeat);
		Debug.quickWatch('Bar', curBar);
		Debug.quickWatch('Tempo', Conductor.tempo);
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
		if (step % Conductor.STEPS_PER_BEAT == 0)
			beatHit(curBeat);
	}

	public function beatHit(beat:Int):Void
	{
	}

	public function barHit(bar:Int):Void
	{
	}

	private function updateStep():Void
	{
		var currentSeg:TimingSegment = Conductor.getTimingAtTimestamp(Conductor.songPosition);
		var startInMS:Float = currentSeg.startTime * TimingConstants.MILLISECONDS_PER_SECOND;
		var stepDiff:Float = ((Conductor.songPosition - Options.save.data.noteOffset) - startInMS) / Conductor.calculateStepLength(currentSeg.tempo);
		var nextDecStep:Float = currentSeg.startStep + stepDiff; // Just so you know what this value is
		curDecimalStep = nextDecStep;
		curStep = Math.floor(curDecimalStep);
	}

	private function updateBeat():Void
	{
		curDecimalBeat = curDecimalStep / Conductor.STEPS_PER_BEAT;
		curBeat = Math.floor(curDecimalBeat);
	}

	private function updateBar():Void
	{
		if (stepsToDo < 1)
			stepsToDo = getStepsOnBar();
		while (curStep >= stepsToDo)
		{
			curBar++;
			stepsToDo += getStepsOnBar();
			barHit(curBar);
		}
	}

	private function rollbackBar():Void
	{
		var lastBar:Int = curBar;
		curBar = 0;
		stepsToDo = 0;
		if (PlayState.song != null)
		{
			for (bar in PlayState.song.bars)
			{
				if (bar != null)
				{
					stepsToDo += getStepsOnBar();
					if (stepsToDo > curStep)
						break;

					curBar++;
				}
			}
		}

		if (curBar > lastBar)
			barHit(curBar);
	}

	private function getStepsOnBar():Int
	{
		if (PlayState.song != null && PlayState.song.bars[curBar] != null)
			return PlayState.song.bars[curBar].lengthInSteps;
		return Conductor.STEPS_PER_BAR;
	}

	private inline function get_controls():Controls
		return PlayerSettings.player1.controls;
}
