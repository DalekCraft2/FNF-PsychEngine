package funkin;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSort;
import funkin.states.PlayState;

// TODO What if we had JSON files for these too? yes i like json a lot
// TODO Make this not have references to PlayState.instance (in fact, do that with most other classes, too)
class CutsceneHandler extends FlxBasic
{
	public var timedEvents:Array<Dynamic> = [];
	public var finishCallback:Void->Void;
	public var finishCallback2:Void->Void;
	public var onStart:Void->Void;
	public var endTime:Float;
	public var objects:Array<FlxSprite> = [];
	public var music:String;

	public function new()
	{
		super();

		timer(0, () ->
		{
			if (music != null)
			{
				FlxG.sound.playMusic(Paths.getMusic(music), 0, false);
				FlxG.sound.music.fadeIn();
			}
			if (onStart != null)
				onStart();
		});
	}

	private var cutsceneTime:Float;
	private var firstFrame:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.state != PlayState.instance || !firstFrame)
		{
			firstFrame = true;
			return;
		}

		cutsceneTime += elapsed;
		if (endTime <= cutsceneTime)
		{
			if (finishCallback != null)
				finishCallback();
			if (finishCallback2 != null)
				finishCallback2();

			for (spr in objects)
			{
				spr.kill();
				PlayState.instance.remove(spr);
				spr.destroy();
			}

			kill();
			PlayState.instance.remove(this);
			destroy();
		}

		while (timedEvents.length > 0 && timedEvents[0][0] <= cutsceneTime)
		{
			timedEvents[0][1]();
			timedEvents.splice(0, 1);
		}
	}

	public function push(spr:FlxSprite):Void
	{
		objects.push(spr);
	}

	public function timer(time:Float, func:Void->Void):Void
	{
		timedEvents.push([time, func]);
		timedEvents.sort(sortByTime);
	}

	private function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}
}
