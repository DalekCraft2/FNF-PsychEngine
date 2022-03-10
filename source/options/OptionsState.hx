package options;

import flixel.FlxSprite;
import options.Options.OptionUtils;

// FIXME Transition to this menu has no fade-in
class OptionsState extends MusicBeatState
{
	override function create()
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		bg.antialiasing = OptionUtils.options.globalAntialiasing;
		add(bg);

		openSubState(new OptionsSubState());
	}
}
