package options;

import flixel.FlxG;
import options.Options;

using StringTools;

class VisualsUISubState extends BaseOptionsMenu
{
	override public function create():Void
	{
		super.create();

		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; // for Discord Rich Presence

		var option:Option = new BooleanOption('noteSplashes', 'Note Splashes', 'If unchecked, hitting "Sick!" notes won\'t show particles.');
		addOption(option);

		option = new BooleanOption('hideHud', 'Hide HUD', 'If checked, hides most HUD elements.');
		addOption(option);

		option = new StringOption('timeBarType', 'Time Bar:', 'What should the Time Bar display?', ['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		option = new BooleanOption('flashing', 'Flashing Lights', 'Uncheck this if you\'re sensitive to flashing lights!');
		addOption(option);

		option = new BooleanOption('camZooms', 'Camera Zooms', 'If unchecked, the camera won\'t zoom in on a beat hit.');
		addOption(option);

		option = new BooleanOption('scoreZoom', 'Score Text Zoom on Hit', 'If unchecked, disables the Score text zooming\neverytime you hit a note.');
		addOption(option);

		option = new FloatOption('healthBarAlpha', 'Health Bar Transparency', 'How much transparent should the health bar and icons be.', 0.1, 0, 1, '%');
		option.scrollSpeed = 1.6;
		option.decimals = 1;
		addOption(option);

		#if !mobile
		option = new BooleanOption('showFPS', 'FPS Counter', 'If unchecked, hides FPS Counter.', (value:Bool) ->
		{
			if (Main.fpsVar != null)
				Main.fpsVar.visible = value;
		});
		addOption(option);
		#end

		option = new StringOption('pauseMusic', 'Pause Screen Song:', 'What song do you prefer for the Pause Screen?', ['None', 'Breakfast', 'Tea Time'],
			(index:Int, value:String, change:Int) ->
			{
				if (Options.save.data.pauseMusic == 'None')
					FlxG.sound.music.stop();
				else
					FlxG.sound.playMusic(Paths.getMusic(Paths.formatToSongPath(Options.save.data.pauseMusic)));

				changedMusic = true;
			});
		addOption(option);
	}

	private var changedMusic:Bool = false;

	override public function destroy():Void
	{
		super.destroy();

		if (changedMusic)
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
	}
}
