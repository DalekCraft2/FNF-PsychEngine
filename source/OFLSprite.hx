package;

import flixel.util.FlxColor;
import openfl.display.Sprite;
import flixel.FlxSprite;

/**
 * designed to draw a Open FL Sprite as a FlxSprite (to allow layering and auto sizing for haxe flixel cameras)
 * Custom made for Kade Engine
 */
class OFLSprite extends FlxSprite
{
	public var flSprite:Sprite;

	public function new(x, y, width, height, sprite:Sprite)
	{
		super(x, y);

		makeGraphic(width, height, FlxColor.TRANSPARENT);

		flSprite = sprite;

		pixels.draw(flSprite);
	}

	private var _frameCount:Int = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (_frameCount != 2)
		{
			pixels.draw(flSprite);
			_frameCount++;
		}
	}

	public function updateDisplay():Void
	{
		pixels.draw(flSprite);
	}
}
