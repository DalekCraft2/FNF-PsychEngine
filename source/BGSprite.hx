package;

import flixel.FlxSprite;

class BGSprite extends FlxSprite implements Danceable
{
	private var idleAnim:String;

	public function new(image:String, ?library:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String>,
			?loop:Bool = false)
	{
		super(x, y);

		if (animArray != null)
		{
			frames = Paths.getSparrowAtlas(image, library);
			for (anim in animArray)
			{
				animation.addByPrefix(anim, anim, 24, loop);
				if (idleAnim == null)
				{
					idleAnim = anim;
					animation.play(anim);
				}
			}
		}
		else
		{
			if (image != null)
			{
				loadGraphic(Paths.getGraphic(image, library));
			}
			active = false;
		}
		scrollFactor.set(scrollX, scrollY);
		antialiasing = Options.save.data.globalAntialiasing;
	}

	public function dance(force:Bool = false):Void
	{
		if (idleAnim != null)
		{
			animation.play(idleAnim, force);
		}
	}
}
