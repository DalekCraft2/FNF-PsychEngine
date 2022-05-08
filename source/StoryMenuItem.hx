package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import haxe.io.Path;

class StoryMenuItem extends FlxSprite
{
	public var targetY:Float = 0;
	public var flashingInt:Int = 0;

	public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y);

		loadGraphic(Paths.getGraphic(Path.join(['storymenu', weekName])));
		// Debug.logTrace('Test added: ${Week.getWeekNumber(weekNum)} ($weekNum)');
		antialiasing = Options.save.data.globalAntialiasing;
	}

	// if it runs at 60fps, fake frameRate will be 6
	// if it runs at 144 fps, fake frameRate will be like 14, and will update the graphic every 0.016666 * 3 seconds still???
	// so it runs basically every so many seconds, not dependant on frameRate??
	// I'm still learning how math works thanks whoever is reading this lol
	private var fakeFramerate:Int = Math.round((1 / FlxG.elapsed) / 10);

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		y = FlxMath.lerp(y, (targetY * 120) + 480, FlxMath.bound(elapsed * 10.2, 0, 1));

		if (isFlashing)
			flashingInt += 1;

		if (flashingInt % fakeFramerate >= Math.floor(fakeFramerate / 2))
			color = 0xFF33FFFF;
		else
			color = FlxColor.WHITE;
	}

	private var isFlashing:Bool = false;

	public function startFlashing():Void
	{
		isFlashing = true;
	}
}
