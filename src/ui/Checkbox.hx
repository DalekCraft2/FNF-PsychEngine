package ui;

import flixel.FlxSprite;

class Checkbox extends FlxSprite
{
	public var value(default, set):Bool;

	public var sprTracker:FlxSprite;
	public var copyAlpha:Bool = true;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;

	public function new(x:Float = 0, y:Float = 0, value:Bool = false)
	{
		super(x, y);

		frames = Paths.getFrames('checkbox');
		animation.addByPrefix('unchecked', 'unchecked', 24, false);
		animation.addByPrefix('unchecking', 'unchecking', 24, false);
		animation.addByPrefix('checking', 'checking', 24, false);
		animation.addByPrefix('checked', 'checked', 24, false);

		antialiasing = Options.save.data.globalAntialiasing;
		scale.set(0.9, 0.9);
		updateHitbox();

		animationFinished(value ? 'checking' : 'unchecking');
		animation.finishCallback = animationFinished;

		this.value = value;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x - 130 + offsetX, sprTracker.y + 30 + offsetY);
			if (copyAlpha)
			{
				alpha = sprTracker.alpha;
			}
		}
	}

	private function animationFinished(name:String):Void
	{
		switch (name)
		{
			case 'checking':
				animation.play('checked', true);
				offset.set(3, 12);

			case 'unchecking':
				animation.play('unchecked', true);
				offset.set(0, 2);
		}
	}

	private function set_value(value:Bool):Bool
	{
		if (this.value != value)
		{
			this.value = value;
			if (value)
			{
				if (animation.name != 'checked' && animation.name != 'checking')
				{
					animation.play('checking', true);
					offset.set(34, 25);
				}
			}
			else if (animation.name != 'unchecked' && animation.name != 'unchecking')
			{
				animation.play('unchecking', true);
				offset.set(25, 28);
			}
		}
		return value;
	}
}
