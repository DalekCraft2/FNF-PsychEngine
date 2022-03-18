package options;

import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;

// FIXME The transition to this menu has no fade-in
class OptionsState extends MusicBeatState
{
	override function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		// One day, I'll figure out how to both call the super method and open a SubState in the create() method
		// super.create();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		openSubState(new OptionsSubState());
	}
	/*override function update(elapsed:Float):Void
		{
			super.update(elapsed);

			if (subState == null)
			{
				openSubState(new OptionsSubState());
				Debug.logTrace('Opened SubState');
			}
	}*/
}
