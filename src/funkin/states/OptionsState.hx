package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import funkin.states.substates.OptionsSubState;
import haxe.io.Path;

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
			Conductor.tempo = TitleState.titleDef.tempo;
		}

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'main', 'backgrounds', 'menuDesat'])));
		bg.color = 0xFFEA71FD;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = Options.profile.globalAntialiasing;
		add(bg);

		openSubState(new OptionsSubState());
	}
}
