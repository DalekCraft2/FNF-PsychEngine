package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.text.FlxText;
import options.Options;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	override public function create():Void
	{
		super.create();

		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu'; // for Discord Rich Presence

		var option:Option = new BooleanOption('lowQuality', 'Low Quality', 'If checked, disables some background details,
			decreases loading times and improves performance.');
		addOption(option);

		option = new BooleanOption('globalAntialiasing', 'Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.', (value:Bool) ->
			{
				for (basic in members)
				{
					var sprite:FlxSprite = cast basic;
					if (sprite != null && (sprite is FlxSprite) && !(sprite is FlxText))
					{
						sprite.antialiasing = value;
					}
				}
			});
		option.showBoyfriend = true;
		addOption(option);

		#if !web // Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		option = new IntegerOption('frameRate', 'Framerate', 'Pretty self explanatory, isn\'t it?', 1, 60, 240, ' FPS', '', (value:Int, change:Int) ->
		{
			if (Options.save.data.frameRate > FlxG.drawFramerate)
			{
				FlxG.updateFramerate = Options.save.data.frameRate;
				FlxG.drawFramerate = Options.save.data.frameRate;
			}
			else
			{
				FlxG.drawFramerate = Options.save.data.frameRate;
				FlxG.updateFramerate = Options.save.data.frameRate;
			}
		});
		addOption(option);
		#end

		option = new BooleanOption('imagesPersist', 'Persistent Cached Data',
			'If checked, images loaded will stay in memory\nuntil the game is closed, this increases memory usage,\nbut basically makes reloading times instant.',
			(value:Bool) ->
			{
				FlxGraphic.defaultPersist = value;
			});
		addOption(option);
	}
}
