package options;

import flixel.FlxG;
import flixel.FlxSprite;

// FIXME The transition to this menu has no fade-in (Because of the transition overriding the OptionsSubState if super.create() is called)
class OptionsState extends MusicBeatState
{
	override public function create():Void
	{
		// One day, I'll figure out how to both call the super method and open a SubState in the create() method
		// super.create();

		if (!FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
			Conductor.tempo = TitleState.titleDef.bpm;
		}

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic('ui/main/backgrounds/menuDesat'));
		bg.color = 0xFFEA71FD;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Options.save.data.globalAntialiasing;
		add(bg);

		openSubState(new OptionsSubState());
	}
}
