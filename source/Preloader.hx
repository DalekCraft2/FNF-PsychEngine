package;

import flixel.system.FlxBasePreloader;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;

@:bitmap('art/preloaderArt.png') class LogoImage extends BitmapData
{
}

class Preloader extends FlxBasePreloader
{
	public function new(minDisplayTime:Float = 3, ?allowedUrls:Array<String>)
	{
		super(minDisplayTime, allowedUrls);
	}

	private var logo:Sprite;

	override public function create():Void
	{
		super.create();

		this._width = Lib.current.stage.stageWidth;
		this._height = Lib.current.stage.stageHeight;

		var ratio:Float = this._width / 2560; // This allows us to scale assets depending on the size of the screen.

		logo = new Sprite();
		logo.addChild(new Bitmap(new LogoImage(0, 0))); // Sets the graphic of the sprite to a Bitmap object, which uses our embedded BitmapData class.
		logo.scaleX = logo.scaleY = ratio;
		logo.x = ((this._width) / 2) - ((logo.width) / 2);
		logo.y = (this._height / 2) - ((logo.height) / 2);
		addChild(logo); // Adds the graphic to the NMEPreloader's buffer.
	}

	override public function update(percent:Float):Void
	{
		super.update(percent);

		if (percent < 69)
		{
			logo.scaleX += percent / 1920;
			logo.scaleY += percent / 1920;
			logo.x -= percent * 0.6;
			logo.y -= percent / 2;
		}
		else
		{
			logo.scaleX = this._width / 1280;
			logo.scaleY = this._width / 1280;
			logo.x = ((this._width) / 2) - ((logo.width) / 2);
			logo.y = (this._height / 2) - ((logo.height) / 2);
		}
	}
}
