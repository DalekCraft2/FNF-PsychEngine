package funkin.ui;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import haxe.io.Path;

class TimeBar extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var bar:FlxBar;
	public var text:FlxText;

	public function new(x:Float, y:Float, songName:String, ?instance:Dynamic, ?property:String)
	{
		super(x, y);

		bg = new FlxSprite().loadGraphic(Paths.getGraphic(Path.join(['ui', 'hud', 'timeBar'])));

		bar = new FlxBar(bg.x + 4, bg.y + 4, LEFT_TO_RIGHT, Std.int(bg.width - 8), Std.int(bg.height - 8), instance, property, 0, 1);
		bar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE);
		bar.numDivisions = 800; // How much lag this causes?? Should I tone it down to idk, 400 or 200?
		bar.updateBar();

		if (Options.profile.timeBarType == 'Song Name')
		{
			text = new FlxText(0, 0, 400, songName, 24);
		}
		else
		{
			text = new FlxText(0, 0, 400, 32);
		}
		text.setFormat(Paths.font('vcr.ttf'), text.size, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.x = bg.width / 2 - text.width / 2;
		text.y = bg.height / 2 - text.height / 2;

		add(bg);
		add(bar);
		add(text);
	}
}
