package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	override function create():Void
	{
		super.create();

		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu'; // for Discord Rich Presence
		// I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality', // Name
			'If checked, disables some background details,\ndecreases loading times and improves performance.', // Description
			'lowQuality', // Save data variable name
			'bool', // Variable type
			false); // Default value
		addOption(option);
		option = new Option('Anti-Aliasing', 'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'globalAntialiasing', 'bool', true);
		option.showBoyfriend = true;
		option.onChange = onChangeAntiAliasing; // Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		#if !html5 // Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		option = new Option('Framerate', "Pretty self explanatory, isn't it?", 'framerate', 'int', 60);
		addOption(option);
		option.minValue = 60;
		option.maxValue = 240;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end
		option = new Option('Persistent Cached Data',
			'If checked, images loaded will stay in memory\nuntil the game is closed, this increases memory usage,\nbut basically makes reloading times instant.',
			'imagesPersist', 'bool', false);
		option.onChange = onChangePersistentData; // Persistent Cached Data changes FlxGraphic.defaultPersist
		addOption(option);
	}

	function onChangeAntiAliasing():Void
	{
		for (basic in members)
		{
			var sprite:FlxSprite = cast(basic, FlxSprite);
			if (sprite != null && (sprite is FlxSprite) && !(sprite is FlxText))
			{
				sprite.antialiasing = Options.save.data.globalAntialiasing;
			}
		}
	}

	function onChangeFramerate():Void
	{
		if (Options.save.data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = Options.save.data.framerate;
			FlxG.drawFramerate = Options.save.data.framerate;
		}
		else
		{
			FlxG.drawFramerate = Options.save.data.framerate;
			FlxG.updateFramerate = Options.save.data.framerate;
		}
	}
}
