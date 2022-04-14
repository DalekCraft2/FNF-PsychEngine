package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;

// FIXME The transition to this menu has no fade-in
class OptionsState extends MusicBeatState
{
	// public function new()
	// {
	// 	super();
	// 	FlxTransitionableState.skipNextTransOut = true;
	// }
	override public function create():Void
	{
		// One day, I'll figure out how to both call the super method and open a SubState in the create() method
		// super.create();

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.changeBPM(TitleState.titleData.bpm);
		}

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		openSubState(new OptionsSubState());
	}
	/*override public function update(elapsed:Float):Void
		{
			super.update(elapsed);

			if (subState == null)
			{
				openSubState(new OptionsSubState());
				Debug.logTrace('Opened SubState');
			}
	}*/
}
