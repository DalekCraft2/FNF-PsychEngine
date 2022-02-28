package options;

import flixel.FlxSprite;
import options.Options.OptionUtils;

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
